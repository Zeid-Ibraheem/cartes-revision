/// Les objets de base de l'appli. Aucune dépendance : ni Flutter, ni base de
/// données, ni moteur de calcul.
library;

/// Note donnée à une carte pendant une révision.
enum Grade { again, hard, good, easy }

/// Où en est une carte dans son apprentissage.
enum LearningState {
  /// Carte nouvelle ou en cours d'apprentissage (étapes courtes, en minutes).
  learning,

  /// Carte apprise : revue à intervalles longs (en jours).
  review,

  /// Carte oubliée, en cours de réapprentissage (étapes courtes).
  relearning,
}

/// Ce que l'appli sait de la mémorisation d'une carte. Les dates sont en UTC.
class Memory {
  const Memory({
    required this.state,
    required this.due,
    this.step,
    this.stability,
    this.difficulty,
    this.lastReview,
  });

  /// Mémoire d'une carte jamais révisée, disponible tout de suite.
  Memory.fresh(DateTime now)
      : this(state: LearningState.learning, due: now.toUtc(), step: 0);

  final LearningState state;

  /// Numéro de l'étape courte en cours, ou `null` pour une carte apprise.
  final int? step;

  /// Stabilité : durée, en jours, pendant laquelle le souvenir tient.
  final double? stability;

  /// Difficulté propre à la carte, de 1 (facile) à 10 (difficile).
  final double? difficulty;

  /// Moment où la carte doit revenir.
  final DateTime due;

  /// Dernière révision, ou `null` si la carte n'a jamais été révisée.
  final DateTime? lastReview;

  bool get isNew => lastReview == null;
}

/// Un paquet de cartes, rangé dans un dossier (ex. dossier « R3.07 »,
/// paquet « Contrôle 1 »).
class Deck {
  const Deck({required this.id, required this.folder, required this.name});

  final int id;
  final String folder;
  final String name;
}

/// Une carte : une question, une réponse, et l'état de sa mémorisation.
class Flashcard {
  const Flashcard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    required this.memory,
  });

  final int id;
  final int deckId;

  /// La question.
  final String front;

  /// La réponse.
  final String back;

  final Memory memory;

  Flashcard copyWith({String? front, String? back, Memory? memory}) {
    return Flashcard(
      id: id,
      deckId: deckId,
      front: front ?? this.front,
      back: back ?? this.back,
      memory: memory ?? this.memory,
    );
  }
}
