import 'package:cartes_revision/domain/models.dart';
import 'package:cartes_revision/domain/stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Mercredi 18 nov. 2026, 12 h. Journée de révision : à partir de 4 h.
  final now = DateTime(2026, 11, 18, 12);

  ReviewEntry answer(DateTime at, Grade grade,
          {LearningState before = LearningState.review,
          bool fresh = false,
          int ms = 10000}) =>
      ReviewEntry(
          at: at.toUtc(),
          grade: grade,
          stateBefore: fresh ? LearningState.learning : before,
          wasNew: fresh,
          durationMs: ms);

  Memory learned(int intervalDays, {int dueInDays = 1}) => Memory(
        state: LearningState.review,
        lastReview: now.subtract(Duration(days: intervalDays - dueInDays)).toUtc(),
        due: now.add(Duration(days: dueInDays)).toUtc(),
        stability: intervalDays.toDouble(),
        difficulty: 5,
      );

  StatsReport compute(List<ReviewEntry> entries,
          {List<Memory> cards = const [], int period = 7}) =>
      computeStats(
        entries: entries,
        cards: cards,
        now: now,
        dayStartHour: 4,
        periodDays: period,
      );

  test('aujourd’hui, période et jours', () {
    final r = compute([
      answer(DateTime(2026, 11, 18, 9), Grade.good, ms: 20000),
      answer(DateTime(2026, 11, 18, 10), Grade.again, ms: 10000),
      // 2 h du matin : compte encore pour mardi (journée à partir de 4 h).
      answer(DateTime(2026, 11, 18, 2), Grade.good),
      answer(DateTime(2026, 11, 10, 9), Grade.good), // hors période (7 j)
    ]);
    expect(r.days, hasLength(7));
    expect(r.days.last.day, DateTime(2026, 11, 18, 4));
    expect(r.today.answers, 2);
    expect(r.today.durationMs, 30000);
    expect(r.days.last.passed, 1);
    expect(r.days.last.failed, 1);
    expect(r.days[r.days.length - 2].answers, 1, reason: 'mardi');
    expect(r.period.answers, 3);
    expect(r.period.secondsPerAnswer, closeTo(13.33, 0.01));
  });

  test('réussite : cartes apprises et apprentissage séparées', () {
    final r = compute([
      answer(DateTime(2026, 11, 17, 9), Grade.good),
      answer(DateTime(2026, 11, 17, 9), Grade.hard),
      answer(DateTime(2026, 11, 17, 9), Grade.easy),
      answer(DateTime(2026, 11, 17, 9), Grade.again),
      answer(DateTime(2026, 11, 17, 9), Grade.again, fresh: true),
      answer(DateTime(2026, 11, 17, 9), Grade.good, fresh: true),
      answer(DateTime(2026, 11, 17, 9), Grade.good,
          before: LearningState.relearning),
    ]);
    expect(r.reviewRate.passed, 3);
    expect(r.reviewRate.total, 4);
    expect(r.reviewRate.ratio, 0.75);
    expect(r.learningRate.passed, 2);
    expect(r.learningRate.total, 3);
    expect(compute([]).reviewRate.ratio, isNull);
  });

  test('série de jours d’affilée', () {
    // Aujourd'hui pas encore révisé : la série compte jusqu'à hier.
    final r = compute([
      answer(DateTime(2026, 11, 17, 9), Grade.good),
      answer(DateTime(2026, 11, 16, 9), Grade.good),
      answer(DateTime(2026, 11, 14, 9), Grade.good), // trou le 15
    ]);
    expect(r.streak, 2);
    final withToday = compute([
      answer(DateTime(2026, 11, 18, 9), Grade.good),
      answer(DateTime(2026, 11, 17, 9), Grade.good),
    ]);
    expect(withToday.streak, 2);
    expect(compute([answer(DateTime(2026, 11, 15, 9), Grade.good)]).streak, 0);
  });

  test('état des cartes et prévision', () {
    final r = compute([], cards: [
      Memory.fresh(now),
      Memory.fresh(now),
      Memory(
          state: LearningState.learning,
          step: 1,
          due: now.add(const Duration(minutes: 10)).toUtc(),
          lastReview: now.toUtc(),
          stability: 1,
          difficulty: 5),
      learned(5, dueInDays: 1), // jeune, demain
      learned(30, dueInDays: 3), // mûre, dans 3 j
      learned(40, dueInDays: -2), // mûre, en retard : compte aujourd'hui
    ]);
    expect(r.collection.fresh, 2);
    expect(r.collection.learning, 1);
    expect(r.collection.young, 1);
    expect(r.collection.mature, 2);
    expect(r.collection.seenRatio, closeTo(4 / 6, 0.001));
    expect(r.forecast, hasLength(14));
    expect(r.forecast[0], 2, reason: 'en apprentissage + en retard');
    expect(r.forecast[1], 1);
    expect(r.forecast[3], 1);
  });

  test('nouvelles apprises, cumulées', () {
    final r = compute([
      answer(DateTime(2026, 11, 16, 9), Grade.good, fresh: true),
      answer(DateTime(2026, 11, 16, 9), Grade.good, fresh: true),
      answer(DateTime(2026, 11, 18, 9), Grade.good, fresh: true),
      answer(DateTime(2026, 11, 18, 9), Grade.good),
    ], period: 4);
    expect(r.learnedPerDay, [0, 2, 2, 3]);
  });

  test('textes', () {
    expect(formatStudyTime(42000), '42 s');
    expect(formatStudyTime(240000), '4 min');
    expect(formatStudyTime(3900000), '1 h 05');
    expect(formatPercent(0.874), '87 %');
    expect(formatPercent(null), '—');
    expect(todayLine(const StudyTotals()),
        'Aujourd’hui : 0 carte en 0 s (0 s/carte)');
    expect(todayLine(const StudyTotals(answers: 12, durationMs: 240000)),
        'Aujourd’hui : 12 cartes en 4 min (20 s/carte)');
  });
}
