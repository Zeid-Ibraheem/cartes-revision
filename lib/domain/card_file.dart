/// Lecture des fichiers de cartes (voir docs/FORMAT-DES-CARTES.md).
library;

import 'dart:convert';

import 'folder_path.dart';
import 'models.dart';

/// Dossier utilisé quand le fichier n'en indique pas.
const defaultFolder = 'Divers';

class ParsedCard {
  ParsedCard(this.front, this.back, [this.wrongAnswers = const []]);

  final String front;
  String back;

  /// Mauvaises réponses pour le QCM (colonnes après la réponse).
  List<String> wrongAnswers;
}

class ParsedDeck {
  ParsedDeck(this.folder, this.name, {this.mode});

  final String folder;
  final String name;

  /// Façon de réviser donnée par « # mode: » ; `null` = ne pas la changer.
  AnswerMode? mode;
  final List<ParsedCard> cards = [];
}

/// Le mot écrit après « # mode: » pour chaque façon de réviser.
String answerModeWord(AnswerMode mode) => switch (mode) {
      AnswerMode.reveal => 'classique',
      AnswerMode.type => 'écrire',
      AnswerMode.choice => 'qcm',
    };

/// Lit le mot écrit après « # mode: » (accents et majuscules sans
/// importance). `null` s'il n'est pas reconnu.
AnswerMode? parseAnswerMode(String word) {
  final plain = word.trim().toLowerCase().replaceAll('é', 'e').replaceAll('è', 'e');
  return switch (plain) {
    'classique' || 'normal' || 'voir' => AnswerMode.reveal,
    'ecrire' || 'clavier' || 'ecrit' => AnswerMode.type,
    'qcm' || 'choix' || 'choix multiples' => AnswerMode.choice,
    _ => null,
  };
}

/// Une ligne du fichier qui n'a pas pu être lue, ou qui mérite un avertissement.
class FileIssue {
  const FileIssue(this.line, this.message);

  /// Numéro de la ligne dans le fichier (la première est la ligne 1).
  final int line;
  final String message;
}

class ParsedFile {
  const ParsedFile(this.decks, this.issues);

  final List<ParsedDeck> decks;
  final List<FileIssue> issues;

  int get cardCount =>
      decks.fold(0, (total, deck) => total + deck.cards.length);
}

/// Résultat d'un import dans la base.
class ImportReport {
  const ImportReport({
    this.newDecks = 0,
    this.added = 0,
    this.updated = 0,
    this.unchanged = 0,
    this.issues = const [],
  });

  final int newDecks;

  /// Cartes nouvelles.
  final int added;

  /// Cartes déjà connues dont la réponse a changé (historique gardé).
  final int updated;

  /// Cartes déjà connues, identiques.
  final int unchanged;

  final List<FileIssue> issues;
}

final _directive =
    RegExp(r'^#\s*(dossier|paquet|mode)\s*:(.*)$', caseSensitive: false);
final _lineBreak = RegExp(r'<br\s*/?>', caseSensitive: false);

/// Lit le texte d'un fichier de cartes.
///
/// [fallbackDeck] est le nom du paquet pour les cartes placées avant toute
/// ligne « # paquet: » (en pratique : le nom du fichier).
ParsedFile parseCardFile(String text, {required String fallbackDeck}) {
  final decks = <ParsedDeck>[];
  final issues = <FileIssue>[];
  final byKey = <String, ParsedDeck>{};
  final byFront = <ParsedDeck, Map<String, ParsedCard>>{};

  var folder = defaultFolder;
  String? deckName;
  AnswerMode? mode;

  ParsedDeck currentDeck() {
    final name = deckName ?? fallbackDeck;
    final deck = byKey.putIfAbsent('$folder\n$name', () {
      final deck = ParsedDeck(folder, name);
      decks.add(deck);
      byFront[deck] = {};
      return deck;
    });
    if (mode != null) deck.mode = mode;
    return deck;
  }

  if (text.startsWith('﻿')) text = text.substring(1);
  final lines = const LineSplitter().convert(text);

  for (var index = 0; index < lines.length; index++) {
    final lineNumber = index + 1;
    final raw = lines[index];
    final trimmed = raw.trim();
    if (trimmed.isEmpty) continue;

    // Une ligne avec tabulation est une carte, même si la question commence
    // par « # » (« #include », « # de pages »…).
    final tab = raw.indexOf('\t');
    if (trimmed.startsWith('#') && tab < 0) {
      final match = _directive.firstMatch(trimmed);
      if (match == null) continue; // simple commentaire
      final keyword = match.group(1)!.toLowerCase();
      if (keyword == 'mode') {
        final value = parseAnswerMode(match.group(2)!);
        if (value == null) {
          issues.add(FileIssue(lineNumber,
              'mode inconnu (classique, écrire ou qcm) : ligne ignorée'));
        } else {
          mode = value;
        }
        continue;
      }
      // Un dossier peut avoir plusieurs niveaux : « Cours/R3.07 ».
      final value = keyword == 'dossier'
          ? normalizeFolder(match.group(2)!)
          : _oneLine(match.group(2)!);
      if (value.isEmpty) {
        issues.add(FileIssue(lineNumber, 'nom manquant après « # $keyword: »'));
      } else if (keyword == 'dossier') {
        folder = value;
        deckName = null;
        mode = null;
      } else {
        deckName = value;
        mode = null;
      }
      continue;
    }

    if (tab < 0) {
      issues.add(FileIssue(lineNumber,
          'pas de tabulation entre la question et la réponse : ligne ignorée'));
      continue;
    }
    // Question, réponse, puis éventuellement les mauvaises réponses du QCM.
    final columns = raw.split('\t');
    final front = _clean(columns[0]);
    final back = _clean(columns[1]);
    final wrong = <String>[];
    for (final column in columns.skip(2)) {
      final value = _clean(column);
      if (value.isNotEmpty && value != back && !wrong.contains(value)) {
        wrong.add(value);
      }
    }
    if (front.isEmpty || back.isEmpty) {
      issues.add(FileIssue(
          lineNumber, 'question ou réponse vide : ligne ignorée'));
      continue;
    }

    final deck = currentDeck();
    final known = byFront[deck]![front];
    if (known != null) {
      known
        ..back = back
        ..wrongAnswers = wrong;
      issues.add(FileIssue(lineNumber,
          'question déjà présente plus haut dans ce paquet : cette réponse remplace la précédente'));
      continue;
    }
    final card = ParsedCard(front, back, wrong);
    deck.cards.add(card);
    byFront[deck]![front] = card;
  }

  return ParsedFile(decks, issues);
}

/// Où iront les cartes d'un fichier, une ligne par paquet :
/// « Cours › R3.07 › Contrôle 1 : 12 cartes ». Au plus [limit] lignes, puis
/// « … et N autre(s) paquet(s) ».
List<String> importPreview(ParsedFile file, {int limit = 6}) {
  final lines = [
    for (final deck in file.decks.take(limit))
      '${displayFolder(deck.folder)} › ${deck.name} : '
          '${deck.cards.length} carte${deck.cards.length > 1 ? 's' : ''}',
  ];
  final more = file.decks.length - limit;
  if (more > 0) lines.add('… et $more autre(s) paquet(s)');
  return lines;
}

/// Écrit des paquets au format des fichiers de cartes : l'inverse de
/// [parseCardFile]. Réimporter le texte obtenu redonne les mêmes paquets,
/// rangés dans les mêmes dossiers. Les paquets vides sont omis.
String writeCardFile(Iterable<ParsedDeck> decks, {String? header}) {
  final buffer = StringBuffer();
  if (header != null) {
    for (final line in const LineSplitter().convert(header)) {
      buffer.writeln('# $line');
    }
  }
  String? folder;
  for (final deck in decks) {
    if (deck.cards.isEmpty) continue;
    if (buffer.isNotEmpty) buffer.writeln();
    if (deck.folder != folder) {
      buffer.writeln('# dossier: ${deck.folder}');
      folder = deck.folder;
    }
    buffer.writeln('# paquet: ${deck.name}');
    final mode = deck.mode;
    if (mode != null && mode != AnswerMode.reveal) {
      buffer.writeln('# mode: ${answerModeWord(mode)}');
    }
    for (final card in deck.cards) {
      buffer.writeln([card.front, card.back, ...card.wrongAnswers]
          .map(_flatten)
          .join('\t'));
    }
  }
  return buffer.toString();
}

/// Une face sur une seule ligne : retours à la ligne en « <br> ».
String _flatten(String text) => text
    .replaceAll('\r\n', '\n')
    .replaceAll('\t', ' ')
    .replaceAll('\n', '<br>');

/// Nom de fichier d'export : « cartes-r3-07-2026-11-21.txt ».
String exportFileName(String label, DateTime day) {
  const accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e',
    'ë': 'e', 'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u',
    'ü': 'u', 'ÿ': 'y', 'œ': 'oe', 'æ': 'ae',
  };
  final plain = label
      .toLowerCase()
      .split('')
      .map((char) => accents[char] ?? char)
      .join();
  final slug = plain
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  String two(int value) => value.toString().padLeft(2, '0');
  final date = '${day.year}-${two(day.month)}-${two(day.day)}';
  return slug.isEmpty || slug == 'cartes'
      ? 'cartes-$date.txt'
      : 'cartes-$slug-$date.txt';
}

/// Texte d'une face : « <br> » devient un retour à la ligne, les tabulations
/// restantes deviennent des espaces.
String _clean(String text) {
  return text
      .replaceAll(_lineBreak, '\n')
      .replaceAll('\t', ' ')
      .split('\n')
      .map((line) => line.trim())
      .join('\n')
      .trim();
}

/// Nom de dossier ou de paquet : sur une seule ligne, espaces resserrés.
String _oneLine(String text) => text.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Nettoie un nom de dossier ou de paquet saisi à la main, de la même façon
/// que ceux lus dans un fichier.
String cleanName(String text) => _oneLine(text);

/// Nettoie des mauvaises réponses saisies à la main : sur une ligne chacune,
/// sans vides, sans doublons ni la bonne réponse [answer].
List<String> cleanWrongAnswers(Iterable<String> wrong, String answer) {
  final right = cleanSide(answer);
  final result = <String>[];
  for (final item in wrong) {
    final value = cleanSide(item).replaceAll('\n', ' ');
    if (value.isNotEmpty && value != right && !result.contains(value)) {
      result.add(value);
    }
  }
  return result;
}

/// Nettoie une question ou une réponse saisie à la main : espaces de début et
/// de fin retirés, retours à la ligne gardés.
String cleanSide(String text) => text
    .replaceAll('\r\n', '\n')
    .replaceAll('\t', ' ')
    .split('\n')
    .map((line) => line.trim())
    .join('\n')
    .trim();
