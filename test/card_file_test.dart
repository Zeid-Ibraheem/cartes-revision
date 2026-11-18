import 'package:cartes_revision/domain/card_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lit le dossier, le paquet et les cartes', () {
    final file = parseCardFile(
      '# dossier: R3.07\n# paquet: Contrôle 1\nQ1\tR1\nQ2\tR2<br>suite\n',
      fallbackDeck: 'fichier',
    );
    expect(file.issues, isEmpty);
    expect(file.decks, hasLength(1));
    final deck = file.decks.single;
    expect(deck.folder, 'R3.07');
    expect(deck.name, 'Contrôle 1');
    expect(deck.cards.map((card) => card.front), ['Q1', 'Q2']);
    expect(deck.cards[1].back, 'R2\nsuite');
    expect(file.cardCount, 2);
  });

  test('sans en-tête : dossier Divers, paquet au nom du fichier', () {
    final file = parseCardFile('Q\tR', fallbackDeck: 'mon-fichier');
    expect(file.decks.single.folder, defaultFolder);
    expect(file.decks.single.name, 'mon-fichier');
  });

  test('plusieurs paquets ; un nouveau dossier repart du nom par défaut', () {
    final file = parseCardFile(
      '# dossier: A\n# paquet: P1\nq\tr\n# paquet: P2\nq\tr\n# dossier: B\nq\tr\n',
      fallbackDeck: 'fichier',
    );
    expect(
      file.decks.map((deck) => '${deck.folder}/${deck.name}'),
      ['A/P1', 'A/P2', 'B/fichier'],
    );
  });

  test('revenir à un paquet déjà vu complète le même paquet', () {
    final file = parseCardFile(
      '# paquet: P1\na\t1\n# paquet: P2\nb\t2\n# paquet: P1\nc\t3\n',
      fallbackDeck: 'f',
    );
    expect(file.decks, hasLength(2));
    expect(file.decks.first.cards.map((card) => card.front), ['a', 'c']);
  });

  test('lignes fautives ignorées et signalées avec leur numéro', () {
    final file = parseCardFile(
      'sans tabulation\n\tR\nQ\t\n# simple commentaire\n\nQ\tR\nQ\tR2\n',
      fallbackDeck: 'f',
    );
    expect(file.issues.map((issue) => issue.line), [1, 2, 3, 7]);
    expect(file.decks.single.cards, hasLength(1));
    // Question en double : la dernière réponse gagne.
    expect(file.decks.single.cards.single.back, 'R2');
  });

  test('BOM, fins de ligne Windows, majuscules et espaces dans les en-têtes', () {
    final file = parseCardFile(
      '﻿#  Dossier :  R3.07  \r\n# PAQUET:Essai   1\r\nQ\tR\r\n',
      fallbackDeck: 'f',
    );
    expect(file.decks.single.folder, 'R3.07');
    expect(file.decks.single.name, 'Essai 1');
    expect(file.decks.single.cards.single.back, 'R');
  });

  test('en-tête sans nom : signalé, le paquet précédent reste', () {
    final file = parseCardFile('# paquet: P\n# paquet:\nQ\tR\n', fallbackDeck: 'f');
    expect(file.issues.single.line, 2);
    expect(file.decks.single.name, 'P');
  });

  test('tabulation en trop dans la réponse et variantes de <br>', () {
    final file =
        parseCardFile('Q\tR\tS\nA<BR/>B\tC<br />D\n', fallbackDeck: 'f');
    final cards = file.decks.single.cards;
    expect(cards[0].back, 'R S');
    expect(cards[1].front, 'A\nB');
    expect(cards[1].back, 'C\nD');
  });

  test('dossiers sur plusieurs niveaux', () {
    final file = parseCardFile(
      '# dossier: Cours / R3.07\n# paquet: C1\nQ\tR\n# dossier: Connaissances › Physique\nq\tr\n',
      fallbackDeck: 'f',
    );
    expect(file.decks.map((d) => d.folder), ['Cours/R3.07', 'Connaissances/Physique']);
  });

  test('nettoyage des saisies à la main', () {
    expect(cleanName('  R3.07   Contrôle\n1 '), 'R3.07 Contrôle 1');
    expect(cleanSide('  ligne 1  \r\n  ligne 2 \t '), 'ligne 1\nligne 2');
  });
}
