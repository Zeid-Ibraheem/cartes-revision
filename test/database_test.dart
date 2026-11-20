// Base SQLite réelle, en mémoire, sur le PC (sqflite_common_ffi).
import 'package:cartes_revision/data/database.dart';
import 'package:cartes_revision/data/fsrs_scheduler.dart';
import 'package:cartes_revision/data/store.dart';
import 'package:cartes_revision/domain/card_file.dart';
import 'package:cartes_revision/domain/models.dart';
import 'package:cartes_revision/domain/reminder_plan.dart';
import 'package:cartes_revision/domain/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Remplace les notifications du téléphone dans les tests.
class FakeReminders implements ReminderService {
  final List<List<PlannedReminder>> calls = [];
  int permissionRequests = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async =>
      calls.add(reminders);

  @override
  Future<bool> start({required void Function() onOpen}) async => false;
}

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 11, 16, 10);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await AppDatabase.open(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
  });

  tearDown(() => db.close());

  ParsedFile file(String text) => parseCardFile(text, fallbackDeck: 'fichier');

  test('réimporter un fichier corrigé garde l’historique des cartes', () async {
    var report = await db.importFile(
        file('# dossier: R3.07\n# paquet: C1\nQ1\tR1\nQ2\tR2\n'), now);
    expect(report.newDecks, 1);
    expect(report.added, 2);

    // Une révision de Q1.
    final q1 = (await db.cards()).firstWhere((card) => card.front == 'Q1');
    final after = FsrsScheduler(fuzz: false).outcomes(q1.memory, now)[Grade.good]!;
    await db.recordReview(before: q1, after: after, grade: Grade.good, at: now);

    // Le fichier corrigé : réponse de Q1 changée, Q3 en plus.
    report = await db.importFile(
      file('# dossier: R3.07\n# paquet: C1\nQ1\tR1 corrigée\nQ2\tR2\nQ3\tR3\n'),
      now.add(const Duration(hours: 1)),
    );
    expect(report.newDecks, 0);
    expect(report.added, 1);
    expect(report.updated, 1);
    expect(report.unchanged, 1);

    final cards = await db.cards();
    expect(cards, hasLength(3));
    final again = cards.firstWhere((card) => card.front == 'Q1');
    expect(again.back, 'R1 corrigée');
    expect(again.memory.isNew, isFalse);
    expect(again.memory.state, after.state);
    expect(again.memory.step, after.step);
    expect(again.memory.due, after.due);
    expect(again.memory.stability, after.stability);
    expect(await db.newCardsSeenSince(now), 1);
  });

  test('compteurs par paquet', () async {
    await db.importFile(
        file('# dossier: A\n# paquet: P\nQ1\tR1\nQ2\tR2\nQ3\tR3\n'), now);
    final cards = await db.cards();
    // Q1 révisée, attendue dans 10 min ; Q2 révisée, attendue dans 5 jours.
    await db.recordReview(
      before: cards[0],
      after: Memory(
          state: LearningState.learning,
          step: 1,
          due: now.add(const Duration(minutes: 10)),
          lastReview: now,
          stability: 2,
          difficulty: 5),
      grade: Grade.good,
      at: now,
    );
    await db.recordReview(
      before: cards[1],
      after: Memory(
          state: LearningState.review,
          due: now.add(const Duration(days: 5)),
          lastReview: now,
          stability: 5,
          difficulty: 5),
      grade: Grade.easy,
      at: now,
    );
    final stats = (await db.deckStats(now.add(const Duration(hours: 12)))).single;
    expect(stats.deck.folder, 'A');
    expect(stats.total, 3);
    expect(stats.fresh, 1);
    expect(stats.due, 1);
    expect(stats.counts.learning, 1);
    expect(stats.counts.review, 0);

    // Cinq jours plus tard, Q2 est à réviser elle aussi.
    final later = (await db.deckStats(now.add(const Duration(days: 6)))).single;
    expect(later.counts.learning, 1);
    expect(later.counts.review, 1);
  });

  test('renommer et supprimer un dossier', () async {
    await db.importFile(
        file('# dossier: A\n# paquet: P1\na\t1\n# paquet: P2\nb\t2\n# dossier: B\n# paquet: P1\nc\t3\n'),
        now);
    // B contient déjà un paquet P1 : fusion refusée, rien ne change.
    await expectLater(db.renameFolder('A', 'B'), throwsA(isA<FolderNameTaken>()));
    expect(await db.cards(folder: 'A'), hasLength(2));

    await db.renameFolder('A', 'C');
    expect(await db.cards(folder: 'A'), isEmpty);
    expect((await db.cards(folder: 'C')).map((c) => c.front), ['a', 'b']);

    await db.deleteFolder('C');
    expect((await db.cards()).single.front, 'c');
  });

  test('deux paquets du même nom dans le même dossier : refusé', () async {
    final deck = await db.createDeck('R3.07', 'Contrôle 1', now);
    await expectLater(db.createDeck('R3.07', 'Contrôle 1', now),
        throwsA(isA<DeckNameTaken>()));
    await db.createDeck('R3.08', 'Contrôle 1', now); // autre dossier : permis
    await expectLater(db.updateDeck(deck.id, 'R3.08', 'Contrôle 1'),
        throwsA(isA<DeckNameTaken>()));
    await db.updateDeck(deck.id, 'R3.09', 'Partiel');
    final names = (await db.deckStats(now)).map((s) => '${s.deck.folder}/${s.deck.name}');
    expect(names, ['R3.08/Contrôle 1', 'R3.09/Partiel']);
  });

  test('question en double à la main : refusée', () async {
    final deck = await db.createDeck('A', 'P', now);
    await db.addCard(deck.id, 'Q', 'R', now);
    await expectLater(db.addCard(deck.id, 'Q', 'autre', now),
        throwsA(isA<CardFrontTaken>()));
  });

  test('supprimer un paquet efface ses cartes et leur historique', () async {
    await db.importFile(file('# paquet: P\nQ\tR\n'), now);
    final card = (await db.cards()).single;
    await db.recordReview(
        before: card, after: card.memory, grade: Grade.again, at: now);
    await db.deleteDeck(card.deckId);
    expect(await db.cards(), isEmpty);
    expect(await db.newCardsSeenSince(now), 0);
  });

  test('cartes d’un dossier, d’un paquet, de tout', () async {
    await db.importFile(
        file('# dossier: A\n# paquet: P1\na\t1\n# paquet: P2\nb\t2\n# dossier: B\nc\t3\n'),
        now);
    final all = await db.cards();
    expect(all, hasLength(3));
    expect((await db.cards(folder: 'A')).map((c) => c.front), ['a', 'b']);
    expect((await db.cards(deckId: all.last.deckId)).single.front, 'c');
  });

  test('échéances et nombre de nouvelles (pour les rappels)', () async {
    await db.importFile(file('# paquet: P\na\t1\nb\t2\nc\t3\n'), now);
    expect(await db.dueTimes(), isEmpty);
    expect(await db.freshCount(), 3);
    final card = (await db.cards()).first;
    final due = now.add(const Duration(days: 2));
    await db.recordReview(
      before: card,
      after: Memory(
          state: LearningState.review,
          due: due,
          lastReview: now,
          stability: 2,
          difficulty: 5),
      grade: Grade.good,
      at: now,
    );
    expect(await db.dueTimes(), [due]);
    expect(await db.freshCount(), 2);
  });

  test('les rappels suivent les cartes et les réglages', () async {
    final reminders = FakeReminders();
    // 10 h UTC = matinée en France : le rappel de 19 h est encore à venir.
    final store =
        await AppStore.open(database: db, clock: () => now, reminders: reminders);
    expect(reminders.calls.last, isEmpty, reason: 'aucune carte');

    await store.importText('# paquet: P\na\t1\nb\t2\n', fallbackDeck: 'f');
    expect(reminders.calls.last.first.title, '2 cartes à réviser');

    await store.updateSettings(
        store.settings.copyWith(reminderEnabled: false));
    expect(reminders.calls.last, isEmpty);

    // Autorisation demandée une seule fois, et seulement si le rappel est actif.
    await store.askReminderPermissionOnce();
    expect(reminders.permissionRequests, 0);
    await store.updateSettings(store.settings.copyWith(reminderEnabled: true));
    await store.askReminderPermissionOnce();
    await store.askReminderPermissionOnce();
    expect(reminders.permissionRequests, 1);
  });

  test('dossiers imbriqués : cartes, déplacement, suppression', () async {
    await db.importFile(
        file('# dossier: Cours/R3.07\n# paquet: C1\na\t1\n'
            '# dossier: Cours/R3.06\n# paquet: C1\nb\t2\n'
            '# dossier: Coursier\n# paquet: P\nc\t3\n'
            '# dossier: Connaissances/Électricité\n# paquet: P\nd\t4\n'),
        now);
    // Un dossier comprend ses sous-dossiers, pas un dossier au nom voisin.
    expect((await db.cards(folder: 'Cours')).map((c) => c.front), ['a', 'b']);
    expect((await db.cards(folder: 'Cours/R3.07')).single.front, 'a');

    // Ranger un dossier dans un autre : tout son contenu suit.
    await db.renameFolder('Cours', 'Études/Cours');
    expect(await db.cards(folder: 'Cours'), isEmpty);
    expect((await db.cards(folder: 'Études/Cours/R3.06')).single.front, 'b');
    expect((await db.cards(folder: 'Coursier')).single.front, 'c');

    // Accents dans les noms : les longueurs restent justes.
    await db.renameFolder('Connaissances/Électricité', 'Connaissances/Physique');
    expect((await db.cards(folder: 'Connaissances/Physique')).single.front, 'd');

    // Pas dans lui-même.
    await expectLater(db.renameFolder('Études', 'Études/Cours/x'),
        throwsA(isA<FolderIntoItself>()));

    // Rejoindre un dossier existant : les contenus se rejoignent.
    await db.renameFolder('Coursier', 'Connaissances');
    expect((await db.cards(folder: 'Connaissances')).map((c) => c.front),
        ['c', 'd']);

    // Supprimer un dossier supprime tout ce qu'il contient.
    await db.deleteFolder('Études');
    expect((await db.cards()).map((c) => c.front), ['c', 'd']);
  });

  test('arbre des dossiers et compteurs additionnés', () async {
    final store = await AppStore.open(database: db, clock: () => now);
    await store.importText(
        '# dossier: Cours/R3.07\n# paquet: C2\na\t1\n# paquet: C1\nb\t2\n'
        '# dossier: Cours\n# paquet: Général\nc\t3\n'
        '# dossier: Connaissances/Physique\n# paquet: La Terre\nd\t4\n',
        fallbackDeck: 'f');
    final roots = store.folders;
    expect(roots.map((f) => f.name), ['Connaissances', 'Cours']);
    final cours = roots[1];
    expect(cours.folders.single.path, 'Cours/R3.07');
    expect(cours.decks.single.deck.name, 'Général');
    expect(cours.folders.single.decks.map((d) => d.deck.name), ['C1', 'C2']);
    expect(cours.total, 3);
    expect(cours.counts.fresh, 3);
    expect(cours.deckCount, 3);
    expect(roots[0].decks, isEmpty, reason: 'dossier intermédiaire');
    expect(store.folderNames,
        ['Connaissances', 'Connaissances/Physique', 'Cours', 'Cours/R3.07']);

    // Replié par défaut ; l'état est retenu, et suit un déplacement.
    expect(store.isExpanded('Cours/R3.07'), isFalse);
    await store.toggleExpanded('Cours/R3.07');
    await store.moveFolder('Cours', 'Études/Cours');
    expect(store.isExpanded('Études/Cours/R3.07'), isTrue);
    expect(store.isExpanded('Études'), isTrue, reason: 'montré après déplacement');
    final reopened = await AppStore.open(database: db, clock: () => now);
    expect(reopened.isExpanded('Études/Cours/R3.07'), isTrue);
  });

  test('historique des réponses par dossier et totaux du jour', () async {
    await db.importFile(
        file('# dossier: Cours/R3.07\n# paquet: P\na\t1\n'
            '# dossier: Connaissances\n# paquet: P\nb\t2\n'),
        now);
    final cards = await db.cards();
    for (final (card, grade, ms) in [
      (cards[0], Grade.good, 12000),
      (cards[1], Grade.again, 3000),
    ]) {
      await db.recordReview(
          before: card,
          after: card.memory,
          grade: grade,
          at: now,
          durationMs: ms);
    }
    final all = await db.reviews(since: now.subtract(const Duration(days: 1)));
    expect(all.map((e) => e.grade), [Grade.good, Grade.again]);
    expect(all.first.wasNew, isTrue);
    expect(all.first.durationMs, 12000);
    final cours = await db.reviews(
        since: now.subtract(const Duration(days: 1)), folder: 'Cours');
    expect(cours.single.grade, Grade.good);
    final deck = await db.reviews(
        since: now.subtract(const Duration(days: 1)), deckId: cards[1].deckId);
    expect(deck.single.grade, Grade.again);
    expect(await db.reviews(since: now.add(const Duration(hours: 1))), isEmpty);

    final totals = await db.totalsSince(now.subtract(const Duration(hours: 1)));
    expect(totals.answers, 2);
    expect(totals.durationMs, 15000);

    final store = await AppStore.open(database: db, clock: () => now);
    expect(store.todayTotals.answers, 2);
    final report = await store.stats(const FolderCards('Cours'), periodDays: 7);
    expect(report.period.answers, 1);
    expect(report.collection.total, 1);
  });

  test('annuler une réponse : carte et historique comme avant', () async {
    final store = await AppStore.open(database: db, clock: () => now);
    await store.updateSettings(const AppSettings(newPerDay: 1, shuffle: false));
    await store.importText('# paquet: P\na\t1\nb\t2\n', fallbackDeck: 'f');
    expect(store.newLeftToday, 1);

    final session = await store.startSession(const AllCards());
    final before = session.current!;
    final after = session.answer(Grade.easy);
    final reviewId =
        await store.recordAnswer(before: before, after: after, grade: Grade.easy);
    expect(store.newLeftToday, 0);
    expect(store.todayTotals.answers, 1);

    await store.undoAnswer(before: before, reviewId: reviewId);
    final card = (await db.cards()).firstWhere((c) => c.id == before.id);
    expect(card.memory.isNew, isTrue);
    expect(card.memory.due, before.memory.due);
    expect(store.newLeftToday, 1, reason: 'la nouvelle du jour est rendue');
    expect(store.todayTotals.answers, 0);
    expect(await db.reviews(since: now.subtract(const Duration(days: 1))),
        isEmpty);
  });

  test('toutes les cartes d’un dossier, dues ou non (entraînement)', () async {
    final store = await AppStore.open(database: db, clock: () => now);
    await store.importText(
        '# dossier: Cours/R3.07\n# paquet: P\na\t1\nb\t2\n'
        '# dossier: Connaissances\n# paquet: P\nc\t3\n',
        fallbackDeck: 'f');
    // Une carte révisée, attendue dans 10 jours : elle est quand même là.
    final first = (await db.cards()).first;
    await db.recordReview(
      before: first,
      after: Memory(
          state: LearningState.review,
          due: now.add(const Duration(days: 10)),
          lastReview: now,
          stability: 10,
          difficulty: 5),
      grade: Grade.good,
      at: now,
    );
    expect((await store.cardsIn(const FolderCards('Cours'))).map((c) => c.front),
        ['a', 'b']);
    expect(await store.cardsIn(const AllCards()), hasLength(3));
  });

  test('le dernier paquet utilisé est retenu', () async {
    final store = await AppStore.open(database: db, clock: () => now);
    final a = await store.createDeck('A', 'P1');
    final b = await store.createDeck('B', 'P2');
    expect(store.lastDeck, isNull);
    await store.rememberDeck(b);
    expect(store.lastDeck?.id, b.id);
    final reopened = await AppStore.open(database: db, clock: () => now);
    expect(reopened.lastDeck?.name, 'P2');
    await reopened.deleteDeck(b);
    expect(reopened.lastDeck, isNull, reason: 'paquet supprimé');
    expect(a.name, 'P1');
  });

  test('réglages enregistrés et relus', () async {
    await db.saveSettings(const AppSettings(newPerDay: 7).toMap());
    expect(AppSettings.fromMap(await db.settings()).newPerDay, 7);
  });

  test('la limite de nouvelles cartes par jour compte ce qui a déjà été vu', () async {
    final store = await AppStore.open(database: db, clock: () => now);
    await store.updateSettings(const AppSettings(newPerDay: 2, shuffle: false));
    await store.importText('# paquet: P\na\t1\nb\t2\nc\t3\n', fallbackDeck: 'f');
    expect(store.newLeftToday, 2);

    var session = await store.startSession(const AllCards());
    expect(session.remaining, 2);
    final before = session.current!;
    final after = session.answer(Grade.easy);
    await store.recordAnswer(before: before, after: after, grade: Grade.easy);
    expect(store.newLeftToday, 1);

    session = await store.startSession(const AllCards());
    expect(session.remaining, 1);
  });
}
