import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/card_file.dart';
import '../domain/models.dart';
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

class FolderCards extends StudyScope {
  const FolderCards(this.folder);

  final String folder;

  @override
  String get label => folder;
}

class DeckCards extends StudyScope {
  const DeckCards(this.deck);

  final Deck deck;

  @override
  String get label => deck.name;
}

/// Un dossier et ses paquets, pour l'écran d'accueil.
class FolderStats {
  FolderStats(this.name);

  final String name;
  final List<DeckStats> decks = [];

  int get total => decks.fold(0, (sum, deck) => sum + deck.total);

  DueCounts get counts =>
      decks.fold(const DueCounts(), (sum, deck) => sum + deck.counts);
}

/// L'état de l'appli, partagé par tous les écrans : réglages, paquets et
/// compteurs. Les écrans l'écoutent et se redessinent quand il change.
class AppStore extends ChangeNotifier {
  AppStore._(this._db, this._settings, this._clock);

  final AppDatabase _db;
  final DateTime Function() _clock;
  AppSettings _settings;
  List<FolderStats> _folders = const [];
  int _newSeenToday = 0;

  static Future<AppStore> open({
    AppDatabase? database,
    DateTime Function()? clock,
  }) async {
    final db = database ?? await AppDatabase.open();
    final settings = AppSettings.fromMap(await db.settings());
    final store = AppStore._(db, settings, clock ?? DateTime.now);
    await store.refresh();
    return store;
  }

  AppSettings get settings => _settings;

  /// Les dossiers et leurs paquets, triés par nom.
  List<FolderStats> get folders => _folders;

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
  List<Deck> get decks => [
        for (final folder in _folders)
          for (final stats in folder.decks) stats.deck,
      ];

  /// Relit les compteurs dans la base.
  Future<void> refresh() async {
    final now = _clock();
    final dayStart = studyDayStart(now, _settings.dayStartHour);
    final dayEnd = studyDayEnd(now, _settings.dayStartHour);
    final stats = await _db.deckStats(dayEnd);
    _newSeenToday = await _db.newCardsSeenSince(dayStart);
    final byName = <String, FolderStats>{};
    for (final deck in stats) {
      byName.putIfAbsent(deck.deck.folder, () => FolderStats(deck.deck.folder))
          .decks
          .add(deck);
    }
    _folders = byName.values.toList();
    notifyListeners();
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
    final deck = await _db.createDeck(cleanName(folder), cleanName(name), _clock());
    await refresh();
    return deck;
  }

  /// Renomme un paquet ou le déplace dans un autre dossier.
  Future<Deck> updateDeck(Deck deck, String folder, String name) async {
    final updated = Deck(id: deck.id, folder: cleanName(folder), name: cleanName(name));
    await _db.updateDeck(updated.id, updated.folder, updated.name);
    await refresh();
    return updated;
  }

  Future<void> deleteDeck(Deck deck) async {
    await _db.deleteDeck(deck.id);
    await refresh();
  }

  Future<void> renameFolder(String from, String to) async {
    await _db.renameFolder(from, cleanName(to));
    await refresh();
  }

  Future<void> deleteFolder(String folder) async {
    await _db.deleteFolder(folder);
    await refresh();
  }

  /// Tous les noms de dossiers, pour les proposer à la saisie.
  List<String> get folderNames => [for (final folder in _folders) folder.name];

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
