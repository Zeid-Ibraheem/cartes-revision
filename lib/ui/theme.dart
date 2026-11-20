import 'package:material_ui/material_ui.dart';

import '../domain/models.dart';
import '../domain/study_session.dart';

/// Le thème de l'appli : du noir, du gris, du blanc. La couleur est réservée
/// à ce qui porte une information (compteurs, notes, erreurs).
///
/// Toutes les couleurs de l'appli sont ici : un seul endroit à changer.
ThemeData buildTheme({required Brightness brightness, bool black = true}) {
  final dark = brightness == Brightness.dark;
  final Color background;
  final Color box;
  final Color boxHigh;
  final Color line;
  final Color text;
  final Color muted;
  if (!dark) {
    background = const Color(0xFFFFFFFF);
    box = const Color(0xFFF4F4F4);
    boxHigh = const Color(0xFFE9E9E9);
    line = const Color(0xFFDCDCDC);
    text = const Color(0xFF111111);
    muted = const Color(0xFF6B6B6B);
  } else if (black) {
    background = const Color(0xFF000000);
    box = const Color(0xFF111111);
    boxHigh = const Color(0xFF242424);
    line = const Color(0xFF2A2A2A);
    text = const Color(0xFFEDEDED);
    muted = const Color(0xFF8C8C8C);
  } else {
    background = const Color(0xFF121212);
    box = const Color(0xFF1C1C1C);
    boxHigh = const Color(0xFF2C2C2C);
    line = const Color(0xFF353535);
    text = const Color(0xFFEDEDED);
    muted = const Color(0xFF9A9A9A);
  }
  final danger = dark ? const Color(0xFFFF6B6B) : const Color(0xFFC62828);

  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF808080),
    brightness: brightness,
  ).copyWith(
    surface: background,
    onSurface: text,
    onSurfaceVariant: muted,
    surfaceTint: Colors.transparent,
    surfaceContainerLowest: background,
    surfaceContainerLow: box,
    surfaceContainer: box,
    surfaceContainerHigh: box,
    surfaceContainerHighest: boxHigh,
    primary: text,
    onPrimary: background,
    primaryContainer: boxHigh,
    onPrimaryContainer: text,
    secondary: text,
    onSecondary: background,
    secondaryContainer: boxHigh,
    onSecondaryContainer: text,
    tertiary: text,
    onTertiary: background,
    outline: muted,
    outlineVariant: line,
    error: danger,
    onError: background,
    inverseSurface: text,
    onInverseSurface: background,
  );
  // Boutons pleins : gris foncé et texte clair (comme le bouton + d'AnkiDroid),
  // pas de gros pavé blanc. La couleur reste réservée aux informations.
  final buttons = FilledButton.styleFrom(
    backgroundColor: boxHigh,
    foregroundColor: text,
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    dividerColor: line,
    filledButtonTheme: FilledButtonThemeData(style: buttons),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: boxHigh,
      foregroundColor: text,
      elevation: 0,
    ),
    // Messages du bas de l'écran : sombres, pas un bandeau blanc.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: boxHigh,
      contentTextStyle: TextStyle(color: text, fontSize: 15),
      actionTextColor: text,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Les couleurs qui portent une information. Les trois premières sont les
/// repères d'Anki : bleu = nouvelles, rouge = en apprentissage, vert = à
/// réviser.
class Signal {
  const Signal._(this.fresh, this.learning, this.review, this.hard, this.faint);

  factory Signal.of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;

  static const _dark = Signal._(
    Color(0xFF5AA9FF),
    Color(0xFFFF6B6B),
    Color(0xFF4CD080),
    Color(0xFFFFB454),
    Color(0xFF5C5C5C),
  );
  static const _light = Signal._(
    Color(0xFF1565C0),
    Color(0xFFC62828),
    Color(0xFF2E7D32),
    Color(0xFFB26A00),
    Color(0xFF8A8A8A),
  );

  final Color fresh;
  final Color learning;
  final Color review;
  final Color hard;

  /// Gris discret mais lisible (contraste 3:1) : zéros des compteurs.
  final Color faint;

  Color kind(CardKind kind) => switch (kind) {
        CardKind.fresh => fresh,
        CardKind.learning => learning,
        CardKind.review => review,
      };

  /// Couleur d'un bouton de réponse.
  Color grade(Grade grade) => switch (grade) {
        Grade.again => learning,
        Grade.hard => hard,
        Grade.good => review,
        Grade.easy => fresh,
      };
}
