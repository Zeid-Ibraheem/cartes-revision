// Base SQLite réelle, en mémoire, sur le PC (sqflite_common_ffi).
import 'package:cartes_revision/data/database.dart';
import 'package:cartes_revision/data/fsrs_scheduler.dart';
import 'package:cartes_revision/data/store.dart';
import 'package:cartes_revision/domain/card_file.dart';
import 'package:cartes_revision/domain/models.dart';
import 'package:cartes_revision/domain/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
