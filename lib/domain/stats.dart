/// Les statistiques : calculs purs, à partir de l'historique des réponses et
/// de l'état des cartes. Aucune dépendance (ni base, ni Flutter).
library;

import 'models.dart';
import 'study_session.dart';

/// Une carte est « mûre » quand son intervalle atteint 21 jours (repère
/// d'Anki) : elle est vraiment installée en mémoire.
const matureIntervalDays = 21;

/// Une réponse donnée, telle qu'enregistrée dans l'historique.
class ReviewEntry {
  const ReviewEntry({
    required this.at,
    required this.grade,
    required this.stateBefore,
    required this.wasNew,
    this.durationMs,
  });

  final DateTime at;
  final Grade grade;

  /// État de la carte juste avant la réponse.
  final LearningState stateBefore;

  /// Première fois que la carte était vue.
  final bool wasNew;
  final int? durationMs;

  /// Réponse réussie : tout sauf « À revoir ».
  bool get passed => grade != Grade.again;
}

/// Ce qui a été fait pendant une journée de révision.
class DayActivity {
  DayActivity(this.day);

  /// Début de la journée de révision.
  final DateTime day;
  int answers = 0;
  int passed = 0;
  int fresh = 0;
  int durationMs = 0;

  int get failed => answers - passed;
}

/// Total d'une période : nombre de réponses et temps passé.
class StudyTotals {
  const StudyTotals({this.answers = 0, this.durationMs = 0});

  final int answers;
  final int durationMs;

  /// Temps moyen par réponse, en secondes.
  double get secondsPerAnswer => answers == 0 ? 0 : durationMs / 1000 / answers;
}

/// Taux de réussite : réussies / total. `null` s'il n'y a aucune réponse.
class SuccessRate {
  const SuccessRate(this.passed, this.total);

  final int passed;
  final int total;

  double? get ratio => total == 0 ? null : passed / total;
}

/// Où en sont les cartes, toutes ensemble.
class CollectionState {
  const CollectionState({
    this.fresh = 0,
    this.learning = 0,
    this.young = 0,
    this.mature = 0,
  });

  /// Jamais vues.
  final int fresh;

  /// En apprentissage ou réapprentissage (étapes en minutes).
  final int learning;

  /// Apprises, intervalle de moins de 21 jours.
  final int young;

  /// Apprises, intervalle de 21 jours ou plus.
  final int mature;

  int get total => fresh + learning + young + mature;

  /// Part des cartes déjà vues au moins une fois.
  double get seenRatio => total == 0 ? 0 : (total - fresh) / total;
}

/// Toutes les statistiques d'un ensemble de cartes, sur une période.
class StatsReport {
  const StatsReport({
    required this.days,
    required this.today,
    required this.period,
    required this.reviewRate,
    required this.learningRate,
    required this.collection,
    required this.forecast,
    required this.streak,
    required this.learnedPerDay,
    required this.desiredRetention,
  });

  /// Une entrée par jour de la période, du plus ancien à aujourd'hui.
  final List<DayActivity> days;
  final StudyTotals today;
  final StudyTotals period;

  /// Réussite sur les cartes déjà apprises : à comparer à la mémorisation
  /// visée. C'est le vrai indicateur d'efficacité.
  final SuccessRate reviewRate;

  /// Réussite sur les cartes nouvelles ou en apprentissage.
  final SuccessRate learningRate;
  final CollectionState collection;

  /// Cartes à revoir pour chacun des prochains jours (0 = aujourd'hui).
  final List<int> forecast;

  /// Jours de révision d'affilée, jusqu'à aujourd'hui (ou hier si rien
  /// n'est encore fait aujourd'hui).
  final int streak;

  /// Cartes nouvelles vues pour la première fois, cumulées jour après jour.
  final List<int> learnedPerDay;
  final double desiredRetention;
}

/// Calcule les statistiques.
///
/// - [entries] : réponses données, sur au moins [periodDays] jours (plus
///   pour calculer la série de jours d'affilée).
/// - [cards] : l'état actuel des cartes concernées.
StatsReport computeStats({
  required List<ReviewEntry> entries,
  required List<Memory> cards,
  required DateTime now,
  required int dayStartHour,
  required int periodDays,
  int forecastDays = 14,
  double desiredRetention = 0.9,
}) {
  final todayStart = studyDayStart(now, dayStartHour);
  DateTime dayOffset(int offset) => DateTime(
      todayStart.year, todayStart.month, todayStart.day + offset, dayStartHour);

  final periodStart = dayOffset(-(periodDays - 1));
  final days = [for (var i = periodDays - 1; i >= 0; i--) DayActivity(dayOffset(-i))];
  final activeDays = <DateTime>{};

  var todayAnswers = 0, todayMs = 0, periodAnswers = 0, periodMs = 0;
  var reviewPassed = 0, reviewTotal = 0, learnPassed = 0, learnTotal = 0;

  for (final entry in entries) {
    final day = studyDayStart(entry.at, dayStartHour);
    activeDays.add(day);
    if (day.isBefore(periodStart)) continue;
    final index = _daysBetween(periodStart, day);
    if (index < 0 || index >= days.length) continue;
    final activity = days[index];
    final ms = entry.durationMs ?? 0;
    activity
      ..answers += 1
      ..durationMs += ms;
    if (entry.passed) activity.passed += 1;
    if (entry.wasNew) activity.fresh += 1;
    periodAnswers++;
    periodMs += ms;
    if (day == todayStart) {
      todayAnswers++;
      todayMs += ms;
    }
    if (entry.stateBefore == LearningState.review && !entry.wasNew) {
      reviewTotal++;
      if (entry.passed) reviewPassed++;
    } else {
      learnTotal++;
      if (entry.passed) learnPassed++;
    }
  }

  // Série : on remonte depuis aujourd'hui (ou hier, la journée n'étant pas
  // finie) tant qu'il y a eu au moins une réponse.
  var streak = 0;
  var cursor = activeDays.contains(todayStart) ? 0 : -1;
  while (activeDays.contains(dayOffset(cursor))) {
    streak++;
    cursor--;
  }

  // État des cartes et prévision.
  var fresh = 0, learning = 0, young = 0, mature = 0;
  final forecast = List<int>.filled(forecastDays, 0);
  for (final memory in cards) {
    if (memory.isNew) {
      fresh++;
      continue;
    }
    if (memory.state == LearningState.review) {
      final interval = memory.due.difference(memory.lastReview!).inHours / 24;
      if (interval >= matureIntervalDays) {
        mature++;
      } else {
        young++;
      }
    } else {
      learning++;
    }
    final day = studyDayStart(memory.due, dayStartHour);
    final offset = day.isBefore(todayStart) ? 0 : _daysBetween(todayStart, day);
    if (offset < forecastDays) forecast[offset]++;
  }

  var cumulative = 0;
  final learned = [
    for (final day in days) cumulative += day.fresh,
  ];

  return StatsReport(
    days: days,
    today: StudyTotals(answers: todayAnswers, durationMs: todayMs),
    period: StudyTotals(answers: periodAnswers, durationMs: periodMs),
    reviewRate: SuccessRate(reviewPassed, reviewTotal),
    learningRate: SuccessRate(learnPassed, learnTotal),
    collection: CollectionState(
        fresh: fresh, learning: learning, young: young, mature: mature),
    forecast: forecast,
    streak: streak,
    learnedPerDay: learned,
    desiredRetention: desiredRetention,
  );
}

/// Nombre de jours entre deux débuts de journée (insensible aux changements
/// d'heure d'été : on arrondit).
int _daysBetween(DateTime from, DateTime to) =>
    (to.difference(from).inMinutes / (24 * 60)).round();

/// « 42 s », « 4 min », « 1 h 05 ».
String formatStudyTime(int milliseconds) {
  final seconds = (milliseconds / 1000).round();
  if (seconds < 60) return '$seconds s';
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h h $m';
}

/// « 87 % », ou « — » s'il n'y a rien à mesurer.
String formatPercent(double? ratio) =>
    ratio == null ? '—' : '${(ratio * 100).round()} %';

/// La ligne du bas de l'accueil : « Aujourd'hui : 12 cartes en 4 min
/// (20 s/carte) ».
String todayLine(StudyTotals today) {
  final n = today.answers;
  final cards = n > 1 ? '$n cartes' : '$n carte';
  final perCard = today.secondsPerAnswer.round();
  return 'Aujourd’hui : $cards en ${formatStudyTime(today.durationMs)} '
      '($perCard s/carte)';
}
