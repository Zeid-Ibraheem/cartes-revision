/// Le déroulement d'une séance de révision : quelles cartes, dans quel ordre.
library;

import 'dart:math';

import 'models.dart';
import 'scheduler.dart';

/// Début de la journée de révision qui contient [now] (heure locale).
/// Avec [startHour] = 4, une révision à 1 h du matin compte pour la veille.
DateTime studyDayStart(DateTime now, int startHour) {
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day, startHour);
  if (local.isBefore(today)) {
    return DateTime(local.year, local.month, local.day - 1, startHour);
  }
  return today;
}

/// Fin de la journée de révision qui contient [now].
DateTime studyDayEnd(DateTime now, int startHour) {
  final start = studyDayStart(now, startHour);
  return DateTime(start.year, start.month, start.day + 1, startHour);
}

/// Nombre de cartes à voir dans un ensemble de cartes.
class DueCounts {
  const DueCounts({this.fresh = 0, this.due = 0});

  /// Cartes jamais révisées.
  final int fresh;

  /// Cartes déjà révisées qui doivent revenir avant la fin de la journée.
  final int due;
}

DueCounts countDue(Iterable<Flashcard> cards, DateTime now, int dayStartHour) {
  final dayEnd = studyDayEnd(now, dayStartHour);
  var fresh = 0;
  var due = 0;
  for (final card in cards) {
    if (card.memory.isNew) {
      fresh++;
    } else if (card.memory.due.isBefore(dayEnd)) {
      due++;
    }
  }
  return DueCounts(fresh: fresh, due: due);
}

/// Une séance : la file des cartes à voir maintenant.
///
/// - Les cartes déjà révisées et attendues aujourd'hui sont toutes prises.
/// - Les cartes nouvelles sont limitées à [newLimit].
/// - Une carte en apprentissage (étapes en minutes) revient dans la même
///   séance quand son délai est écoulé. Quand il ne reste qu'elles, celles
///   attendues dans moins de [learnAhead] sont montrées en avance (comme
///   Anki) ; sinon la séance attend ([waitingUntil]).
class StudySession {
  StudySession({
    required Iterable<Flashcard> cards,
    required Scheduler scheduler,
    required int newLimit,
    required int dayStartHour,
    bool shuffle = true,
    DateTime Function()? clock,
    Random? random,
  })  : _scheduler = scheduler,
        _clock = clock ?? DateTime.now {
    final now = _clock();
    _dayEnd = studyDayEnd(now, dayStartHour);

    final fresh = <Flashcard>[];
    final reviews = <Flashcard>[];
    for (final card in cards) {
      final memory = card.memory;
      if (memory.isNew) {
        fresh.add(card);
      } else if (!memory.due.isBefore(_dayEnd)) {
        continue; // pas pour aujourd'hui
      } else if (memory.state == LearningState.review) {
        reviews.add(card);
      } else {
        _waiting.add(card);
      }
    }

    // Ordre de départ stable (ordre de création), mélangé si demandé.
    fresh.sort((a, b) => a.id.compareTo(b.id));
    reviews.sort((a, b) => a.memory.due.compareTo(b.memory.due));
    final generator = random ?? Random();
    if (shuffle) fresh.shuffle(generator);

    _queue
      ..addAll(reviews)
      ..addAll(fresh.take(newLimit < 0 ? 0 : newLimit));
    if (shuffle) _queue.shuffle(generator);

    _next();
  }

  /// Avance maximale accordée à une carte en apprentissage quand il n'y a
  /// plus rien d'autre à voir.
  static const learnAhead = Duration(minutes: 20);

  final Scheduler _scheduler;
  final DateTime Function() _clock;
  late final DateTime _dayEnd;

  /// Cartes pas encore vues dans cette séance.
  final List<Flashcard> _queue = [];

  /// Cartes en apprentissage, qui reviendront dans cette séance.
  final List<Flashcard> _waiting = [];

  Flashcard? _current;
  Map<Grade, Memory> _outcomes = const {};
  DateTime _shownAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  int _answered = 0;

  /// La carte à montrer, ou `null` s'il n'y a rien à montrer maintenant.
  Flashcard? get current => _current;

  /// Plus rien à voir aujourd'hui dans cette séance.
  bool get isFinished => _current == null && _waiting.isEmpty;

  /// Quand rien n'est à montrer maintenant mais qu'une carte en apprentissage
  /// revient plus tard aujourd'hui : le moment où elle revient.
  DateTime? get waitingUntil =>
      _current == null && _waiting.isNotEmpty ? _waiting.first.memory.due : null;

  /// À rappeler après une attente : montre la carte suivante si son heure est
  /// venue.
  void resume() {
    if (_current == null) _next();
  }

  /// Nombre de réponses données depuis le début de la séance.
  int get answered => _answered;

  /// Nombre de cartes encore à voir, celle en cours comprise.
  int get remaining =>
      _queue.length + _waiting.length + (_current == null ? 0 : 1);

  /// Dans combien de temps la carte en cours reviendra si on répond [grade].
  Duration delayFor(Grade grade) {
    final memory = _outcomes[grade];
    if (memory == null) return Duration.zero;
    return memory.due.difference(_shownAt);
  }

  /// Enregistre la réponse à la carte en cours et passe à la suivante.
  /// Renvoie la carte avec son nouvel état de mémorisation : à l'appelant de
  /// l'enregistrer dans la base.
  Flashcard answer(Grade grade) {
    final card = _current;
    final memory = _outcomes[grade];
    if (card == null || memory == null) {
      throw StateError('Aucune carte en cours.');
    }
    final updated = card.copyWith(memory: memory);
    _answered++;
    if (memory.state != LearningState.review && memory.due.isBefore(_dayEnd)) {
      _waiting.add(updated);
    }
    _next();
    return updated;
  }

  /// Remplace le texte de la carte en cours (après une correction).
  void replaceCurrent(Flashcard card) {
    if (_current?.id == card.id) _current = card;
  }

  void _next() {
    final now = _clock();
    _waiting.sort((a, b) => a.memory.due.compareTo(b.memory.due));

    Flashcard? next;
    if (_waiting.isNotEmpty && !_waiting.first.memory.due.isAfter(now)) {
      next = _waiting.removeAt(0); // son délai est écoulé
    } else if (_queue.isNotEmpty) {
      next = _queue.removeAt(0);
    } else if (_waiting.isNotEmpty &&
        !_waiting.first.memory.due.isAfter(now.add(learnAhead))) {
      next = _waiting.removeAt(0); // il ne reste qu'elles : un peu en avance
    }

    _current = next;
    _shownAt = now.toUtc();
    _outcomes =
        next == null ? const {} : _scheduler.outcomes(next.memory, now);
  }
}
