import 'dart:math' as math;

import 'package:cartes_revision/domain/answer_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalisation : accents, majuscules, ponctuation, espaces', () {
    expect(normalizeAnswer('  Ça  VA ? '), 'ca va');
    expect(normalizeAnswer('Adresse-IP'), 'adresse ip');
    expect(normalizeAnswer('Œuvre'), 'oeuvre');
    expect(normalizeAnswer('802.11ac'), '802 11ac');
  });

  test('distance de Levenshtein', () {
    expect(levenshtein('chat', 'chat'), 0);
    expect(levenshtein('chat', 'chats'), 1);
    expect(levenshtein('chat', 'chien'), 3);
    expect(levenshtein('', 'abc'), 3);
    expect(levenshtein('kitten', 'sitting'), 3);
  });

  test('verdicts', () {
    expect(checkTypedAnswer('DHCP', 'DHCP').verdict, TypedVerdict.exact);
    expect(checkTypedAnswer('  DHCP ', 'DHCP').verdict, TypedVerdict.exact,
        reason: 'espaces de début et de fin ignorés');
    expect(checkTypedAnswer('dhcp', 'DHCP').verdict, TypedVerdict.nearly);
    expect(checkTypedAnswer('Systeme de noms', 'Système de noms').verdict,
        TypedVerdict.nearly);
    final close = checkTypedAnswer('Dynamic Host Configuraton Protocol',
        'Dynamic Host Configuration Protocol');
    expect(close.verdict, TypedVerdict.close);
    expect(close.distance, 1);
    expect(checkTypedAnswer('DHCPv6', 'DHCP').verdict, isNot(TypedVerdict.exact));
    expect(checkTypedAnswer('Mo', 'Go').verdict, TypedVerdict.close,
        reason: 'une lettre de différence : à toi de juger');
    expect(checkTypedAnswer('routeur', 'commutateur').verdict,
        TypedVerdict.wrong);
    expect(checkTypedAnswer('', 'DHCP').verdict, TypedVerdict.wrong);
  });

  test('comparaison lettre à lettre', () {
    expect(diffChars('chat', 'chat'), [const DiffPart(DiffKind.same, 'chat')]);
    expect(diffChars('cht', 'chat'), const [
      DiffPart(DiffKind.same, 'ch'),
      DiffPart(DiffKind.missing, 'a'),
      DiffPart(DiffKind.same, 't'),
    ]);
    expect(diffChars('chats', 'chat'), const [
      DiffPart(DiffKind.same, 'chat'),
      DiffPart(DiffKind.extra, 's'),
    ]);
    // Rebâtir les deux textes à partir de la comparaison.
    final parts = diffChars('Configuraton', 'Configuration');
    expect(parts.where((p) => p.kind != DiffKind.missing).map((p) => p.text).join(),
        'Configuraton');
    expect(parts.where((p) => p.kind != DiffKind.extra).map((p) => p.text).join(),
        'Configuration');
  });

  test('QCM : mauvaises réponses écrites, complétées par le paquet', () {
    final random = math.Random(1);
    final choices =
        buildChoices('22', ['21', '23'], ['22', '443', '80', '21', '25'], random)!;
    expect(choices, hasLength(choiceCount));
    expect(choices, containsAll(['22', '21', '23']));
    expect(choices.toSet(), hasLength(choiceCount), reason: 'sans doublons');

    final fromPool = buildChoices('22', const [], ['22', '443', '80'], random)!;
    expect(fromPool, unorderedEquals(['22', '443', '80']));

    expect(buildChoices('22', const [], ['22', ' 22 '], random), isNull,
        reason: 'aucune mauvaise réponse possible');

    final written = buildChoices('A', ['B', 'C', 'D', 'E'], const [], random)!;
    expect(written, hasLength(choiceCount));
  });
}
