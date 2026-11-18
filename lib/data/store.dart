import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/card_file.dart';
import '../domain/folder_path.dart';
import '../domain/models.dart';
import '../domain/reminder_plan.dart';
import '../domain/settings.dart';
import '../domain/study_session.dart';
import 'database.dart';
import 'fsrs_scheduler.dart';

/// Ce qu'on révise : tout, un dossier, ou un paquet.
sealed class StudyScope {
  const StudyScope();

  String get label;
}

class AllCards extends StudyScope {
  const AllCards();

  @override
  String get label => 'Tout';
}

/// Un dossier et tout ce qu'il contient, sous-dossiers compris.
class FolderCards extends StudyScope {
  const FolderCards(this.folder);

  /// Chemin du dossier (« Cours/R3.07 »).
  final String folder;

  @override
  String get label => folderLeaf(folder);
}

class DeckCards extends StudyScope {
  const DeckCards(this.deck);

  final Deck deck;

  @override
  String get label => deck.name;
}

/// Un dossier de l'arbre : ses sous-dossiers et ses paquets. Les compteurs
/// additionnent tout ce qu'il contient, à tous les niveaux.
class FolderNode {
  FolderNode(this.path);

  /// Chemin complet (« Cours/R3.07 »).
  final String path;
  final List<FolderNode> folders = [];
  final List<DeckStats> decks = [];

  /// Nom affiché : le dernier niveau du chemin.
  String get name => folderLeaf(path);

  int get depth => folderDepth(path);

  int get total =>
      decks.fold(0, (sum, deck) => sum + deck.total) +
      folders.fold(0, (sum, folder) => sum + folder.total);

  /// Nombre de paquets, à tous les niveaux.
  int get deckCount =>
      decks.length + folders.fold(0, (sum, folder) => sum + folder.deckCount);

  DueCounts get counts => folders.fold(
        decks.fold(const DueCounts(), (sum, deck) => sum + deck.counts),
        (sum, folder) => sum + folder.counts,
      );
}

/// Range les paquets en arbre de dossiers, triés par nom. Les dossiers
/// intermédiaires sans paquet propre (« Cours » dans « Cours/R3.07 ») sont
/// créés au passage.
List<FolderNode> buildFolderTree(Iterable<DeckStats> stats) {
  final byPath = <String, FolderNode>{};
  final roots = <FolderNode>[];
  FolderNode node(String path) {
    final known = byPath[path];
    if (known != null) return known;
    final created = byPath[path] = FolderNode(path);
    final parent = folderParent(path);
    if (parent.isEmpty) {
      roots.add(created);
    } else {
      node(parent).folders.add(created);
    }
    return created;
  }

  for (final deck in stats) {
    node(deck.deck.folder).decks.add(deck);
  }
  int byName(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
  void sort(List<FolderNode> nodes) {
    nodes.sort((a, b) => byName(a.name, b.name));
    for (final n in nodes) {
      n.decks.sort((a, b) => byName(a.deck.name, b.deck.name));
      sort(n.folders);
    }
  }

  sort(roots);
  return roots;
}

/// L'état de l'appli, partagé par tous les écrans : réglages, paquets et
/// compteurs. Les écrans l'écoutent et se redessinent quand il change.
class AppStore extends ChangeNotifier {
  AppStore._(this._db, this._settings, this._clock, this._reminders);

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// Programmation des rappels, ou `null` (tests, plateforme sans
  /// notifications).
  final ReminderService? _reminders;
  Future<void> _reminderUpdate = Future.value();
  AppSettings _settings;
  List<FolderNode> _folders = const [];
  Set<String> _expanded = {};
  int _newSeenToday = 0;

  static Future<AppStore> open({
    AppDatabase? database,
    DateTime Function()? clock,
    ReminderService? reminders,
  }) async {
    final db = database ?? await AppDatabase.open();
    final settings = AppSettings.fromMap(await db.settings());
    final store = AppStore._(db, settings, clock ?? DateTime.now, reminders);
    final expanded = (await db.settings())[_kExpanded] ?? '';
    store._expanded = expanded.split('\n').where((p) => p.isNotEmpty).toSet();
    await store.refresh();
    return store;
  }

  // Clés enregistrées dans la table des réglages, hors des réglages visibles.
  static const _kPermissionAsked = 'notifications_autorisation_demandee';
  static const _kExpanded = 'dossiers_ouverts';

  /// Au premier démarrage, demande l'autorisation des notifications si le
  /// rappel est actif. Une seule fois : ensuite, on ne la redemande que si
  /// l'utilisateur réactive le rappel lui-même.
  Future<void> askReminderPermissionOnce() async {
    final reminders = _reminders;
    if (reminders == null || !_settings.reminderEnabled) return;
    final stored = await _db.settings();
    if (stored.containsKey(_kPermissionAsked)) return;
    await _db.saveSettings({_kPermissionAsked: 'true'});
    try {
      await reminders.requestPermission();
    } catch (_) {
      // Pas de notifications sur cet appareil : l'appli marche sans.
    }
  }

  /// Le rappel vient d'être activé par l'utilisateur : redemande
  /// l'autorisation. Renvoie `false` si elle est refusée.
  Future<bool> requestReminderPermission() async {
    final reminders = _reminders;
    if (reminders == null) return false;
    try {
      return await reminders.requestPermission();
    } catch (_) {
      return false;
    }
  }

  /// Recalcule et reprogramme les rappels. Les mises à jour s'enchaînent
  /// l'une après l'autre : la dernière gagne toujours.
  Future<void> _updateReminders(int newLeftToday) {
    final reminders = _reminders;
    if (reminders == null) return Future.value();
    final settings = _settings;
    _reminderUpdate = _reminderUpdate.then((_) async {
      try {
        final plan = planReminders(
          settings: settings,
          now: _clock(),
          dueTimes: await _db.dueTimes(),
          freshTotal: await _db.freshCount(),
          newLeftToday: newLeftToday,
        );
        await reminders.replaceAll(plan);
      } catch (_) {
        // Un rappel raté ne doit jamais bloquer l'appli.
      }
    });
    return _reminderUpdate;
  }

  AppSettings get settings => _settings;

  /// Les dossiers et leurs paquets, triés par nom.
  List<FolderNode> get folders => _folders;

  /// Le dossier est déplié sur l'accueil. Par défaut, tout est replié.
  bool isExpanded(String path) => _expanded.contains(path);

  /// Déplie ou replie un dossier. Retenu d'une ouverture à l'autre.
  Future<void> toggleExpanded(String path) async {
    if (!_expanded.remove(path)) _expanded.add(path);
    notifyListeners();
    await _db.saveSettings({_kExpanded: _expanded.join('\n')});
  }

  /// Déplie un dossier et tous ceux qui le contiennent (pour montrer un
  /// paquet qui vient d'y être rangé).
  Future<void> reveal(String path) async {
    final before = _expanded.length;
    _expanded.addAll(folderAncestry(path));
    if (_expanded.length == before) return;
    notifyListeners();
    await _db.saveSettings({_kExpanded: _expanded.join('\n')});
  }

  bool get isEmpty => _folders.isEmpty;

  /// Cartes nouvelles encore permises aujourd'hui (réglage « par jour »).
  int get newLeftToday {
    final left = _settings.newPerDay - _newSeenToday;
    return left < 0 ? 0 : left;
  }

  /// Ce qu'une séance montrera vraiment aujourd'hui pour ces compteurs :
  /// les nouvelles sont limitées par le réglage « par jour ».
  DueCounts today(DueCounts counts) => counts.withFreshLimit(newLeftToday);

  /// Tous les paquets confondus, sans la limite du jour.
  DueCounts get counts =>
      _folders.fold(const DueCounts(), (sum, folder) => sum + folder.counts);

  /// Tous les paquets, dans l'ordre de l'accueil.
  List<Deck> get decks {
    final decks = <Deck>[];
    void walk(List<FolderNode> nodes) {
      for (final node in nodes) {
        walk(node.folders);
        decks.addAll(node.decks.map((stats) => stats.deck));
      }
    }

    walk(_folders);
    return decks;
  }

  /// Relit les compteurs dans la base.
  Future<void> refresh() async {
    final now = _clock();
    final dayStart = studyDayStart(now, _settings.dayStartHour);
    final dayEnd = studyDayEnd(now, _settings.dayStartHour);
    final stats = await _db.deckStats(dayEnd);
    _newSeenToday = await _db.newCardsSeenSince(dayStart);
    _folders = buildFolderTree(stats);
    notifyListeners();
    await _updateReminders(newLeftToday);
  }

  // ---------------------------------------------------------------- Réglages

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    await _db.saveSettings(settings.toMap());
    await refresh(); // l'heure de début de journée change les compteurs
  }

  // ---------------------------------------------------------------- Import

  /// Lit les [bytes] d'un fichier de cartes et les ajoute.
  /// [fileName] donne le nom du paquet quand le fichier n'en indique pas.
  Future<ImportReport> importBytes(List<int> bytes, String fileName) {
    final text = utf8.decode(bytes, allowMalformed: true);
    return importText(text, fallbackDeck: _baseName(fileName));
  }

  Future<ImportReport> importText(String text,
      {required String fallbackDeck}) async {
    final parsed = parseCardFile(text, fallbackDeck: fallbackDeck);
    final report = await _db.importFile(parsed, _clock());
    await refresh();
    return report;
  }

  static String _baseName(String fileName) {
    final name = fileName.split(RegExp(r'[/\\]')).last;
    final dot = name.lastIndexOf('.');
    final base = cleanName(dot > 0 ? name.substring(0, dot) : name);
    return base.isEmpty ? 'Importé' : base;
  }

  // ---------------------------------------------------------------- Paquets

  Future<Deck> createDeck(String folder, String name) async {
    final deck = await _db.createDeck(
        _folderOrDefault(folder), cleanName(name), _clock());
    await refresh();
    return deck;
  }

  /// Renomme un paquet ou le déplace dans un autre dossier.
  Future<Deck> updateDeck(Deck deck, String folder, String name) async {
    final updated = Deck(
        id: deck.id, folder: _folderOrDefault(folder), name: cleanName(name));
    await _db.updateDeck(updated.id, updated.folder, updated.name);
    await refresh();
    return updated;
  }

  Future<void> deleteDeck(Deck deck) async {
    await _db.deleteDeck(deck.id);
    await refresh();
  }

  /// Renomme ou déplace un dossier ([to] est le nouveau chemin complet).
  /// Ses sous-dossiers et paquets suivent. Renvoie le nouveau chemin.
  Future<String> moveFolder(String from, String to) async {
    final path = normalizeFolder(to);
    if (path.isEmpty) throw const FormatException('Le nom est vide.');
    if (path == from) return path;
    await _db.renameFolder(from, path);
    // Les dossiers dépliés le restent sous leur nouveau nom.
    final moved = {
      for (final p in _expanded)
        isInFolder(p, from) ? path + p.substring(from.length) : p,
      ...folderAncestry(path),
    };
    _expanded = moved;
    await _db.saveSettings({_kExpanded: _expanded.join('\n')});
    await refresh();
    return path;
  }

  Future<void> deleteFolder(String folder) async {
    await _db.deleteFolder(folder);
    await refresh();
  }

  /// Tous les chemins de dossiers, dans l'ordre de l'accueil, pour les
  /// proposer à la saisie.
  List<String> get folderNames {
    final paths = <String>[];
    void walk(List<FolderNode> nodes) {
      for (final node in nodes) {
        paths.add(node.path);
        walk(node.folders);
      }
    }

    walk(_folders);
    return paths;
  }

  static String _folderOrDefault(String folder) {
    final path = normalizeFolder(folder);
    return path.isEmpty ? defaultFolder : path;
  }

  // ---------------------------------------------------------------- Cartes

  Future<List<Flashcard>> cardsOf(Deck deck) => _db.cards(deckId: deck.id);

  Future<Flashcard> addCard(Deck deck, String front, String back) async {
    final card = await _db.addCard(deck.id, cleanSide(front), cleanSide(back), _clock());
    await refresh();
    return card;
  }

  Future<Flashcard> updateCard(Flashcard card, String front, String back) async {
    final updated = card.copyWith(front: cleanSide(front), back: cleanSide(back));
    await _db.updateCardText(card.id, updated.front, updated.back, _clock());
    return updated;
  }

  Future<void> deleteCard(Flashcard card) async {
    await _db.deleteCard(card.id);
    await refresh();
  }

  // ---------------------------------------------------------------- Révision

  /// Prépare une séance avec les réglages actuels.
  Future<StudySession> startSession(StudyScope scope) async {
    await refresh(); // compteur des nouvelles du jour à jour
    final cards = await switch (scope) {
      AllCards() => _db.cards(),
      FolderCards(:final folder) => _db.cards(folder: folder),
      DeckCards(:final deck) => _db.cards(deckId: deck.id),
    };
    return StudySession(
      cards: cards,
      scheduler: FsrsScheduler.fromSettings(_settings),
      newLimit: newLeftToday,
      dayStartHour: _settings.dayStartHour,
      shuffle: _settings.shuffle,
      clock: _clock,
    );
  }

  /// Enregistre une réponse donnée pendant une séance.
  Future<void> recordAnswer({
    required Flashcard before,
    required Flashcard after,
    required Grade grade,
    int? durationMs,
  }) async {
    await _db.recordReview(
      before: before,
      after: after.memory,
      grade: grade,
      at: _clock(),
      durationMs: durationMs,
    );
    await refresh();
  }
}
