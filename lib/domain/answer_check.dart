/// Réponses écrites au clavier et questions à choix multiples (QCM).
///
/// Rien ici ne note à ta place, sauf une réponse exacte lettre pour lettre :
/// le reste sert à montrer la différence, et c'est toi qui choisis la note.
library;

import 'dart:math' as math;

/// Résultat de la comparaison d'une réponse écrite.
enum TypedVerdict {
  /// Identique, lettre pour lettre (espaces de début et de fin mis à part).
  exact,

  /// Identique aux accents, majuscules, espaces et ponctuation près.
  nearly,

  /// Quelques lettres de différence (voir [TypedCheck.distance]).
  close,

  /// Différente.
  wrong,
}

/// Morceau de la comparaison lettre à lettre.
enum DiffKind {
  /// Pareil dans les deux.
  same,

  /// Dans ta réponse, pas dans la bonne (en trop ou faux).
  extra,

  /// Dans la bonne réponse, absent de la tienne.
  missing,
}

class DiffPart {
  const DiffPart(this.kind, this.text);

  final DiffKind kind;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is DiffPart && other.kind == kind && other.text == text;

  @override
  int get hashCode => Object.hash(kind, text);

  @override
  String toString() => '${kind.name}:$text';
}

class TypedCheck {
  const TypedCheck(this.verdict, this.distance, this.diff);

  final TypedVerdict verdict;

  /// Nombre de lettres à ajouter, enlever ou changer, une fois les accents,
  /// majuscules, espaces et ponctuation mis de côté (distance de Levenshtein).
  final int distance;

  /// Comparaison lettre à lettre de ta réponse avec la bonne, telles
  /// qu'écrites. Vide si les textes sont trop longs pour être comparés.
  final List<DiffPart> diff;
}

/// Au-delà, pas de comparaison lettre à lettre (trop long à calculer).
const maxDiffLength = 400;

/// Compare [typed] (ce que tu as écrit) à [expected] (la réponse de la carte).
TypedCheck checkTypedAnswer(String typed, String expected) {
  final a = typed.trim();
  final b = expected.trim();
  final diff = a.length <= maxDiffLength && b.length <= maxDiffLength
      ? diffChars(a, b)
      : const <DiffPart>[];
  if (a == b) return TypedCheck(TypedVerdict.exact, 0, diff);
  final na = normalizeAnswer(a);
  final nb = normalizeAnswer(b);
  if (na == nb) return TypedCheck(TypedVerdict.nearly, 0, diff);
  final distance = levenshtein(na, nb);
  // Une faute de frappe par tranche de 6 lettres, au moins 1 : « presque ».
  final tolerance = math.max(1, nb.length ~/ 6);
  final verdict = na.isNotEmpty && distance <= tolerance
      ? TypedVerdict.close
      : TypedVerdict.wrong;
  return TypedCheck(verdict, distance, diff);
}

const _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y',
  'œ': 'oe', 'æ': 'ae', 'ß': 'ss',
};

final _notLetterOrDigit = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

/// Texte ramené à l'essentiel : minuscules, sans accents, sans ponctuation,
/// espaces resserrés. « Ça  va ? » → « ca va ».
String normalizeAnswer(String text) {
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString().replaceAll(_notLetterOrDigit, ' ').trim();
}

/// Distance de Levenshtein : le nombre minimum de lettres à ajouter, enlever
/// ou remplacer pour passer de [a] à [b].
int levenshtein(String a, String b) {
  final x = a.runes.toList();
  final y = b.runes.toList();
  if (x.isEmpty) return y.length;
  if (y.isEmpty) return x.length;
  var previous = List<int>.generate(y.length + 1, (j) => j);
  for (var i = 1; i <= x.length; i++) {
    final current = List<int>.filled(y.length + 1, 0)..[0] = i;
    for (var j = 1; j <= y.length; j++) {
      final cost = x[i - 1] == y[j - 1] ? 0 : 1;
      current[j] = math.min(
        math.min(current[j - 1] + 1, previous[j] + 1),
        previous[j - 1] + cost,
      );
    }
    previous = current;
  }
  return previous[y.length];
}

/// Comparaison lettre à lettre de [typed] avec [expected] (plus longue suite
/// commune). Les morceaux voisins de même sorte sont regroupés.
List<DiffPart> diffChars(String typed, String expected) {
  final a = typed.runes.map(String.fromCharCode).toList();
  final b = expected.runes.map(String.fromCharCode).toList();
  // lcs[i][j] : longueur de la plus longue suite commune de a[i..] et b[j..].
  final lcs = List.generate(a.length + 1, (_) => List<int>.filled(b.length + 1, 0));
  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      lcs[i][j] = a[i] == b[j]
          ? lcs[i + 1][j + 1] + 1
          : math.max(lcs[i + 1][j], lcs[i][j + 1]);
    }
  }
  final parts = <DiffPart>[];
  void add(DiffKind kind, String char) {
    if (parts.isNotEmpty && parts.last.kind == kind) {
      parts[parts.length - 1] = DiffPart(kind, parts.last.text + char);
    } else {
      parts.add(DiffPart(kind, char));
    }
  }

  var i = 0, j = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      add(DiffKind.same, a[i]);
      i++;
      j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      add(DiffKind.extra, a[i++]);
    } else {
      add(DiffKind.missing, b[j++]);
    }
  }
  while (i < a.length) {
    add(DiffKind.extra, a[i++]);
  }
  while (j < b.length) {
    add(DiffKind.missing, b[j++]);
  }
  return parts;
}

/// Nombre de réponses proposées dans un QCM (la bonne comprise).
const choiceCount = 4;

/// Les réponses proposées pour une carte en QCM, mélangées : la bonne
/// ([answer]), ses mauvaises réponses écrites ([written]), complétées si
/// besoin par des réponses d'autres cartes du même paquet ([pool]).
///
/// `null` s'il n'y a pas au moins une mauvaise réponse : la carte se révise
/// alors de façon classique.
List<String>? buildChoices(
  String answer,
  List<String> written,
  Iterable<String> pool,
  math.Random random,
) {
  final seen = {normalizeAnswer(answer)};
  final wrong = <String>[];
  void take(String candidate) {
    if (wrong.length >= choiceCount - 1) return;
    final key = normalizeAnswer(candidate);
    if (key.isEmpty || !seen.add(key)) return;
    wrong.add(candidate);
  }

  written.forEach(take);
  final others = pool.toList()..shuffle(random);
  others.forEach(take);
  if (wrong.isEmpty) return null;
  return [answer, ...wrong]..shuffle(random);
}
