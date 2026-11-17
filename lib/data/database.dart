import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/card_file.dart';
import '../domain/models.dart';
import '../domain/study_session.dart';

/// Un paquet et le nombre de ses cartes par catégorie.
class DeckStats {
  const DeckStats({
    required this.deck,
    required this.total,
    required this.counts,
  });

  final Deck deck;

  /// Nombre de cartes du paquet.
  final int total;

  /// Cartes à voir aujourd'hui (toutes les nouvelles, sans la limite du jour).
  final DueCounts counts;

  int get fresh => counts.fresh;
  int get due => counts.due;
}

/// Le dossier d'arrivée contient déjà un paquet du même nom.
class FolderNameTaken implements Exception {
  const FolderNameTaken(this.folder);

  final String folder;

  @override
  String toString() =>
      'Le dossier « $folder » contient déjà un paquet du même nom.';
}

/// Le paquet existe déjà sous ce dossier et ce nom.
class DeckNameTaken implements Exception {
  const DeckNameTaken(this.folder, this.name);

  final String folder;
  final String name;

  @override
  String toString() => 'Le paquet « $name » existe déjà dans « $folder ».';
}

/// La question existe déjà dans ce paquet.
class CardFrontTaken implements Exception {
  const CardFrontTaken();

  @override
  String toString() => 'Cette question existe déjà dans ce paquet.';
}

/// Base SQLite locale : paquets, cartes, historique des révisions, réglages.
///
/// Versions du schéma :
/// 1. decks, cards, reviews, settings
///
/// Pour faire évoluer le schéma : ajouter une fonction _createV2, l'appeler
/// dans onCreate ET dans onUpgrade (si oldVersion < 2), passer version à 2.
/// Ne jamais modifier une table existante autrement que par une migration.
class AppDatabase {
  AppDatabase._(this._db, this.path);

  final Database _db;

  /// Chemin du fichier de la base.
  final String path;

  static const fileName = 'cartes.db';
  static const _version = 1;

  /// Ouvre la base. [factory] et [path] servent aux tests (base en mémoire).
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath =
        path ?? p.join(await dbFactory.getDatabasesPath(), fileName);
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await _createV1(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // Rien pour l'instant : une seule version du schéma.
        },
      ),
    );
    return AppDatabase._(db, dbPath);
  }

  Future<void> close() => _db.close();

  // ---------------------------------------------------------------- Schéma

  static Future<void> _createV1(Database db) async {
    await db.execute('''
      CREATE TABLE decks (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        folder     TEXT NOT NULL,
        name       TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        UNIQUE (folder, name)
      )
    ''');
    await db.execute('''
      CREATE TABLE cards (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        deck_id     INTEGER NOT NULL REFERENCES decks(id) ON DELETE CASCADE,
        front       TEXT NOT NULL,
        back        TEXT NOT NULL,
        state       TEXT NOT NULL,
        step        INTEGER,
        stability   REAL,
        difficulty  REAL,
        due         INTEGER NOT NULL,
        last_review INTEGER,
        created_at  INTEGER NOT NULL,
        updated_at  INTEGER NOT NULL,
        UNIQUE (deck_id, front)
      )
    ''');
    await db.execute('CREATE INDEX cards_by_due ON cards (due)');
    // Une ligne par réponse donnée : la base des futures statistiques, et de
    // l'optimisation des paramètres de FSRS sur tes propres révisions.
    await db.execute('''
      CREATE TABLE reviews (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        card_id      INTEGER NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
        reviewed_at  INTEGER NOT NULL,
        grade        TEXT NOT NULL,
        state_before TEXT NOT NULL,
        was_new      INTEGER NOT NULL,
        duration_ms  INTEGER
      )
    ''');
    await db.execute('CREATE INDEX reviews_by_time ON reviews (reviewed_at)');
    await db.execute('CREATE INDEX reviews_by_card ON reviews (card_id)');
    await db.execute('''
      CREATE TABLE settings (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // Les états et les notes sont enregistrés par leur nom (« review »,
  // « good ») : réordonner les enums ne casse pas une base existante.

  static int _ms(DateTime time) => time.toUtc().millisecondsSinceEpoch;

  static DateTime _time(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

  static Map<String, Object?> _memoryColumns(Memory memory) => {
        'state': memory.state.name,
        'step': memory.step,
        'stability': memory.stability,
        'difficulty': memory.difficulty,
        'due': _ms(memory.due),
        'last_review': memory.lastReview == null ? null : _ms(memory.lastReview!),
      };

  static Flashcard _card(Map<String, Object?> row) {
    final lastReview = row['last_review'] as int?;
    return Flashcard(
      id: row['id']! as int,
      deckId: row['deck_id']! as int,
      front: row['front']! as String,
      back: row['back']! as String,
      memory: Memory(
        state: LearningState.values.byName(row['state']! as String),
        step: row['step'] as int?,
        stability: (row['stability'] as num?)?.toDouble(),
        difficulty: (row['difficulty'] as num?)?.toDouble(),
        due: _time(row['due']! as int),
        lastReview: lastReview == null ? null : _time(lastReview),
      ),
    );
  }

  static Deck _deck(Map<String, Object?> row) => Deck(
        id: row['id']! as int,
        folder: row['folder']! as String,
        name: row['name']! as String,
      );

  // ---------------------------------------------------------------- Paquets

  /// Tous les paquets avec leurs compteurs, triés par dossier puis par nom.
  /// [dayEnd] : fin de la journée de révision en cours.
  Future<List<DeckStats>> deckStats(DateTime dayEnd) async {
    final rows = await _db.rawQuery('''
      SELECT d.id, d.folder, d.name,
             COUNT(c.id) AS total,
             COALESCE(SUM(c.last_review IS NULL), 0) AS fresh,
             COALESCE(SUM(c.last_review IS NOT NULL AND c.state <> 'review'
                          AND c.due < ?), 0) AS learning,
             COALESCE(SUM(c.last_review IS NOT NULL AND c.state = 'review'
                          AND c.due < ?), 0) AS review
      FROM decks d
      LEFT JOIN cards c ON c.deck_id = d.id
      GROUP BY d.id
      ORDER BY d.folder COLLATE NOCASE, d.name COLLATE NOCASE
    ''', [_ms(dayEnd), _ms(dayEnd)]);
    return [
      for (final row in rows)
        DeckStats(
          deck: _deck(row),
          total: row['total']! as int,
          counts: DueCounts(
            fresh: row['fresh']! as int,
            learning: row['learning']! as int,
            review: row['review']! as int,
          ),
        ),
    ];
  }

  Future<Deck> createDeck(String folder, String name, DateTime now) async {
    try {
      final id = await _db.insert('decks', {
        'folder': folder,
        'name': name,
        'created_at': _ms(now),
      });
      return Deck(id: id, folder: folder, name: name);
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) throw DeckNameTaken(folder, name);
      rethrow;
    }
  }

  /// Renomme un paquet ou le déplace dans un autre dossier.
  Future<void> updateDeck(int id, String folder, String name) async {
    try {
      await _db.update('decks', {'folder': folder, 'name': name},
          where: 'id = ?', whereArgs: [id]);
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) throw DeckNameTaken(folder, name);
      rethrow;
    }
  }

  /// Supprime un paquet, ses cartes et leur historique.
  Future<void> deleteDeck(int id) =>
      _db.delete('decks', where: 'id = ?', whereArgs: [id]);

  /// Renomme un dossier : tous ses paquets changent de dossier.
  Future<void> renameFolder(String from, String to) async {
    try {
      await _db.update('decks', {'folder': to},
          where: 'folder = ?', whereArgs: [from]);
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) throw FolderNameTaken(to);
      rethrow;
    }
  }

  /// Supprime un dossier : ses paquets, leurs cartes et leur historique.
  Future<void> deleteFolder(String folder) =>
      _db.delete('decks', where: 'folder = ?', whereArgs: [folder]);

  // ---------------------------------------------------------------- Cartes

  /// Les cartes d'un paquet, d'un dossier, ou de tout (les deux à `null`).
  Future<List<Flashcard>> cards({int? deckId, String? folder}) async {
    final String? where;
    final List<Object?> args;
    if (deckId != null) {
      where = 'deck_id = ?';
      args = [deckId];
    } else if (folder != null) {
      where = 'deck_id IN (SELECT id FROM decks WHERE folder = ?)';
      args = [folder];
    } else {
      where = null;
      args = const [];
    }
    final rows = await _db.query('cards',
        where: where, whereArgs: args, orderBy: 'id');
    return rows.map(_card).toList();
  }

  Future<Flashcard> addCard(
      int deckId, String front, String back, DateTime now) async {
    final memory = Memory.fresh(now);
    try {
      final id = await _db.insert('cards', {
        'deck_id': deckId,
        'front': front,
        'back': back,
        ..._memoryColumns(memory),
        'created_at': _ms(now),
        'updated_at': _ms(now),
      });
      return Flashcard(
          id: id, deckId: deckId, front: front, back: back, memory: memory);
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) throw const CardFrontTaken();
      rethrow;
    }
  }

  /// Corrige le texte d'une carte. Son historique est gardé.
  Future<void> updateCardText(
      int id, String front, String back, DateTime now) async {
    try {
      await _db.update(
          'cards', {'front': front, 'back': back, 'updated_at': _ms(now)},
          where: 'id = ?', whereArgs: [id]);
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) throw const CardFrontTaken();
      rethrow;
    }
  }

  Future<void> deleteCard(int id) =>
      _db.delete('cards', where: 'id = ?', whereArgs: [id]);

  /// Enregistre une réponse : nouvel état de la carte + une ligne d'historique.
  Future<void> recordReview({
    required Flashcard before,
    required Memory after,
    required Grade grade,
    required DateTime at,
    int? durationMs,
  }) async {
    await _db.transaction((txn) async {
      await txn.update('cards', _memoryColumns(after),
          where: 'id = ?', whereArgs: [before.id]);
      await txn.insert('reviews', {
        'card_id': before.id,
        'reviewed_at': _ms(at),
        'grade': grade.name,
        'state_before': before.memory.state.name,
        'was_new': before.memory.isNew ? 1 : 0,
        'duration_ms': durationMs,
      });
    });
  }

  /// Nombre de cartes nouvelles vues pour la première fois depuis [since].
  Future<int> newCardsSeenSince(DateTime since) async {
    final rows = await _db.rawQuery(
        'SELECT COUNT(*) AS n FROM reviews WHERE was_new = 1 AND reviewed_at >= ?',
        [_ms(since)]);
    return rows.first['n']! as int;
  }

  // ---------------------------------------------------------------- Import

  /// Ajoute le contenu d'un fichier de cartes.
  ///
  /// Une carte est reconnue par son paquet (dossier + nom) et sa question :
  /// réimporter un fichier corrigé met à jour les réponses sans perdre
  /// l'historique, et n'ajoute que les nouvelles questions.
  Future<ImportReport> importFile(ParsedFile file, DateTime now) async {
    var newDecks = 0, added = 0, updated = 0, unchanged = 0;
    await _db.transaction((txn) async {
      for (final parsed in file.decks) {
        final found = await txn.query('decks',
            columns: ['id'],
            where: 'folder = ? AND name = ?',
            whereArgs: [parsed.folder, parsed.name]);
        final int deckId;
        if (found.isEmpty) {
          deckId = await txn.insert('decks', {
            'folder': parsed.folder,
            'name': parsed.name,
            'created_at': _ms(now),
          });
          newDecks++;
        } else {
          deckId = found.first['id']! as int;
        }

        for (final card in parsed.cards) {
          final existing = await txn.query('cards',
              columns: ['id', 'back'],
              where: 'deck_id = ? AND front = ?',
              whereArgs: [deckId, card.front]);
          if (existing.isEmpty) {
            await txn.insert('cards', {
              'deck_id': deckId,
              'front': card.front,
              'back': card.back,
              ..._memoryColumns(Memory.fresh(now)),
              'created_at': _ms(now),
              'updated_at': _ms(now),
            });
            added++;
          } else if (existing.first['back'] != card.back) {
            await txn.update(
                'cards', {'back': card.back, 'updated_at': _ms(now)},
                where: 'id = ?', whereArgs: [existing.first['id']]);
            updated++;
          } else {
            unchanged++;
          }
        }
      }
    });
    return ImportReport(
      newDecks: newDecks,
      added: added,
      updated: updated,
      unchanged: unchanged,
      issues: file.issues,
    );
  }

  // ---------------------------------------------------------------- Réglages

  Future<Map<String, String>> settings() async {
    final rows = await _db.query('settings');
    return {
      for (final row in rows) row['key']! as String: row['value']! as String,
    };
  }

  Future<void> saveSettings(Map<String, String> values) async {
    final batch = _db.batch();
    values.forEach((key, value) {
      batch.insert('settings', {'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await batch.commit(noResult: true);
  }
}
