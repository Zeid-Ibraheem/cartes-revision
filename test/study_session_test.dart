import 'package:cartes_revision/domain/models.dart';
import 'package:cartes_revision/domain/scheduler.dart';
import 'package:cartes_revision/domain/study_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Moteur factice aux délais fixes, pour tester la séance seule.
class FakeScheduler implements Scheduler {
  @override
  Map<Grade, Memory> outcomes(Memory memory, DateTime now) {
    final at = now.toUtc();
    Memory make(LearningState state, Duration delay) => Memory(
          state: state,
          due: at.add(delay),
          lastReview: at,
          step: state == LearningState.review ? null : 0,
          stability: 1,
          difficulty: 5,
        );
    return {
      Grade.again: make(LearningState.learning, const Duration(minutes: 1)),
      Grade.hard: make(LearningState.learning, const Duration(minutes: 30)),
      Grade.good: make(LearningState.review, const Duration(days: 1)),
      Grade.easy: make(LearningState.review, const Duration(days: 4)),
    };
  }
}

void main() {
  // Midi heure locale : loin du changement de journée (4 h).
  late DateTime now;
  DateTime clock() => now;

  setUp(() => now = DateTime(2026, 11, 16, 12));

  Flashcard fresh(int id) => Flashcard(
      id: id, deckId: 1, front: 'Q$id', back: 'R$id', memory: Memory.fresh(now));

  Flashcard reviewed(int id, Duration dueIn) => Flashcard(
        id: id,
        deckId: 1,
        front: 'Q$id',
        back: 'R$id',
        memory: Memory(
          state: LearningState.review,
          due: now.add(dueIn).toUtc(),
          lastReview: now.subtract(const Duration(days: 5)).toUtc(),
          stability: 5,
          difficulty: 5,
        ),
      );

  StudySession session(List<Flashcard> cards, {int newLimit = 20}) =>
      StudySession(
        cards: cards,
        scheduler: FakeScheduler(),
        newLimit: newLimit,
        dayStartHour: 4,
        shuffle: false,
        clock: clock,
      );

  test('la limite de nouvelles cartes est respectée', () {
    final s = session([for (var i = 1; i <= 5; i++) fresh(i)], newLimit: 2);
    expect(s.remaining, 2);
    expect(s.current!.id, 1);
  });

  test('les révisions attendues aujourd’hui sont prises, pas celles de plus tard', () {
    final s = session([
      reviewed(1, const Duration(days: -1)),
      reviewed(2, const Duration(hours: 2)),
      reviewed(3, const Duration(days: 3)),
    ]);
    expect(s.remaining, 2);
    expect(s.current!.id, 1);
  });

  test('le délai affiché correspond au résultat enregistré', () {
    final s = session([fresh(1)]);
    expect(s.delayFor(Grade.good), const Duration(days: 1));
    final answered = s.answer(Grade.good);
    expect(answered.memory.state, LearningState.review);
    expect(s.isFinished, isTrue);
    expect(s.answered, 1);
  });

  test('« À revoir » : la carte revient après les autres', () {
    final s = session([fresh(1), fresh(2)]);
    s.answer(Grade.again); // carte 1, revient dans 1 min
    expect(s.current!.id, 2);
    s.answer(Grade.good);
    // Plus rien d'autre : la carte 1 (dans moins de 20 min) revient en avance.
    expect(s.current!.id, 1);
    s.answer(Grade.good);
    expect(s.isFinished, isTrue);
    expect(s.answered, 3);
  });

  test('une carte attendue dans plus de 20 min met la séance en pause', () {
    final s = session([fresh(1)]);
    s.answer(Grade.hard); // revient dans 30 min
    expect(s.current, isNull);
    expect(s.isFinished, isFalse);
    expect(s.waitingUntil, isNotNull);
    expect(s.remaining, 1);

    now = now.add(const Duration(minutes: 9));
    s.resume();
    expect(s.current, isNull, reason: 'encore 21 min : trop tôt');

    now = now.add(const Duration(minutes: 2));
    s.resume();
    expect(s.current!.id, 1, reason: '19 min : montrée un peu en avance');
  });

  test('début de la journée de révision', () {
    expect(studyDayStart(DateTime(2026, 11, 16, 1), 4), DateTime(2026, 11, 15, 4));
    expect(studyDayStart(DateTime(2026, 11, 16, 4), 4), DateTime(2026, 11, 16, 4));
    expect(studyDayEnd(DateTime(2026, 11, 16, 23), 4), DateTime(2026, 11, 17, 4));
  });

  test('compteurs', () {
    final counts = countDue([
      fresh(1),
      reviewed(2, const Duration(days: -1)),
      reviewed(3, const Duration(days: 3)),
    ], now, 4);
    expect(counts.fresh, 1);
    expect(counts.learning, 0);
    expect(counts.review, 1);
    expect(counts.due, 1);
    expect(counts.total, 2);
  });

  test('la limite du jour ne touche que les nouvelles', () {
    const counts = DueCounts(fresh: 30, learning: 2, review: 7);
    final today = counts.withFreshLimit(5);
    expect(today.fresh, 5);
    expect(today.learning, 2);
    expect(today.review, 7);
    expect(counts.withFreshLimit(-3).fresh, 0);
    expect((counts + today).fresh, 35);
  });

  test('les trois compteurs suivent la séance', () {
    final s = session([fresh(1), fresh(2), reviewed(3, const Duration(days: -1))]);
    expect(s.counts.fresh, 2);
    expect(s.counts.learning, 0);
    expect(s.counts.review, 1);
    expect(kindOf(s.current!.memory), CardKind.review);

    s.answer(Grade.good); // la révision est faite
    expect(s.counts.review, 0);
    expect(s.counts.fresh, 2);

    s.answer(Grade.again); // une nouvelle passe en apprentissage
    expect(s.counts.fresh, 1);
    expect(s.counts.learning, 1);
  });

  test('annuler la dernière réponse remet la carte, telle qu’avant', () {
    final s = session([fresh(1), fresh(2)]);
    final before = s.current!;
    s.answer(Grade.again); // carte 1 en apprentissage, carte 2 affichée
    expect(s.current!.id, 2);
    expect(s.answered, 1);

    s.undo(before);
    expect(s.current!.id, 1);
    expect(s.current!.memory.isNew, isTrue, reason: 'état d’avant la réponse');
    expect(s.answered, 0);
    expect(s.remaining, 2, reason: 'la carte 1 n’est pas en double');
    expect(s.counts.fresh, 2);
    expect(s.counts.learning, 0);

    // La carte 2 repasse juste après.
    s.answer(Grade.good);
    expect(s.current!.id, 2);
  });

  test('annuler après la fin de la séance la rouvre', () {
    final s = session([fresh(1)]);
    final before = s.current!;
    s.answer(Grade.good);
    expect(s.isFinished, isTrue);
    s.undo(before);
    expect(s.isFinished, isFalse);
    expect(s.current!.id, 1);
  });

  test('supprimer la carte en cours passe à la suivante', () {
    final s = session([fresh(1), fresh(2)]);
    s.dropCurrent();
    expect(s.current!.id, 2);
    expect(s.remaining, 1);
    s.dropCurrent();
    expect(s.isFinished, isTrue);
  });
}
