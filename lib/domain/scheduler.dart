import 'models.dart';

/// Le moteur qui décide quand une carte doit revenir.
///
/// Le reste de l'appli ne connaît que cette interface. Changer de moteur
/// (autre version de FSRS, autre algorithme) = écrire une nouvelle classe qui
/// l'implémente, sans toucher aux écrans ni à la base.
abstract interface class Scheduler {
  /// Pour une carte dans l'état [memory], révisée à l'instant [now] : le
  /// nouvel état pour chacune des quatre notes possibles.
  ///
  /// L'appli affiche les délais à partir de ce résultat, puis enregistre
  /// celui de la note choisie. Le délai affiché est donc exactement celui
  /// appliqué, même quand le moteur fait varier les intervalles au hasard.
  Map<Grade, Memory> outcomes(Memory memory, DateTime now);
}
