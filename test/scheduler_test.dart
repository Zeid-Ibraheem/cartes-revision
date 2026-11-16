// Vérifie l'adaptateur vers le paquet fsrs : c'est lui qui casserait si le
// paquet changeait de fonctionnement.
import 'package:cartes_revision/data/fsrs_scheduler.dart';
import 'package:cartes_revision/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 16, 10);

  test('carte nouvelle avec les étapes 1 et 10 min', () {
    final out = FsrsScheduler(fuzz: false).outcomes(Memory.fresh(now), now);

    expect(out[Grade.again]!.due.difference(now), const Duration(minutes: 1));
    expect(out[Grade.again]!.state, LearningState.learning);

    // « Difficile » sur la 1re étape : moyenne des deux étapes.
    expect(out[Grade.hard]!.due.difference(now), const Duration(seconds: 330));

    expect(out[Grade.good]!.due.difference(now), const Duration(minutes: 10));
    expect(out[Grade.good]!.state, LearningState.learning);
    expect(out[Grade.good]!.step, 1);

    expect(out[Grade.easy]!.state, LearningState.review);
    expect(out[Grade.easy]!.step, isNull);
    expect(out[Grade.easy]!.due.difference(now).inDays, greaterThanOrEqualTo(1));

    for (final memory in out.values) {
      expect(memory.lastReview, now);
      expect(memory.due.isUtc, isTrue);
      expect(memory.stability, isNotNull);
      expect(memory.difficulty, isNotNull);
    }
  });

  test('« Correct » sur la dernière étape : la carte passe en jours', () {
    final scheduler = FsrsScheduler(fuzz: false);
    final first = scheduler.outcomes(Memory.fresh(now), now)[Grade.good]!;
    final later = now.add(const Duration(minutes: 10));
    final second = scheduler.outcomes(first, later)[Grade.good]!;
    expect(second.state, LearningState.review);
    expect(second.due.difference(later).inDays, greaterThanOrEqualTo(1));
  });

  test('sans étapes : « Correct » donne directement un intervalle en jours', () {
    final out = FsrsScheduler(fuzz: false, learningStepsMinutes: const [])
        .outcomes(Memory.fresh(now), now);
    expect(out[Grade.good]!.state, LearningState.review);
  });

  test('oubli d’une carte apprise : réapprentissage à 10 min', () {
    final learned = Memory(
      state: LearningState.review,
      due: now,
      lastReview: now.subtract(const Duration(days: 8)),
      stability: 8,
      difficulty: 5,
    );
    final out = FsrsScheduler(fuzz: false).outcomes(learned, now);
    expect(out[Grade.again]!.state, LearningState.relearning);
    expect(out[Grade.again]!.due.difference(now), const Duration(minutes: 10));
    expect(out[Grade.good]!.state, LearningState.review);
    expect(
      out[Grade.easy]!.due.isAfter(out[Grade.good]!.due),
      isTrue,
      reason: '« Facile » repousse plus loin que « Correct »',
    );
  });

  test('mémorisation visée plus haute = intervalles plus courts', () {
    final learned = Memory(
      state: LearningState.review,
      due: now,
      lastReview: now.subtract(const Duration(days: 20)),
      stability: 20,
      difficulty: 5,
    );
    final at80 = FsrsScheduler(fuzz: false, desiredRetention: 0.80)
        .outcomes(learned, now)[Grade.good]!;
    final at95 = FsrsScheduler(fuzz: false, desiredRetention: 0.95)
        .outcomes(learned, now)[Grade.good]!;
    expect(at95.due.isBefore(at80.due), isTrue);
  });

  test('l’intervalle maximum est respecté', () {
    final learned = Memory(
      state: LearningState.review,
      due: now,
      lastReview: now.subtract(const Duration(days: 300)),
      stability: 300,
      difficulty: 2,
    );
    final out = FsrsScheduler(fuzz: false, maximumIntervalDays: 30)
        .outcomes(learned, now);
    expect(out[Grade.easy]!.due.difference(now).inDays, lessThanOrEqualTo(30));
  });

  test('la carte d’origine n’est pas modifiée', () {
    final fresh = Memory.fresh(now);
    FsrsScheduler().outcomes(fresh, now);
    expect(fresh.isNew, isTrue);
    expect(fresh.step, 0);
  });
}
