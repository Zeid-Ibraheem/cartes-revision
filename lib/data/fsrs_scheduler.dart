import 'package:fsrs/fsrs.dart' as fsrs;

import '../domain/models.dart';
import '../domain/scheduler.dart';
import '../domain/settings.dart';

/// Le moteur FSRS (paquet « fsrs », port Dart de py-fsrs), branché sur
/// l'interface [Scheduler] de l'appli.
///
/// C'est le SEUL fichier qui connaît le paquet fsrs : en changer ne touche
/// rien d'autre.
class FsrsScheduler implements Scheduler {
  FsrsScheduler({
    double desiredRetention = 0.9,
    List<int> learningStepsMinutes = const [1, 10],
    List<int> relearningStepsMinutes = const [10],
    int maximumIntervalDays = 36500,
    bool fuzz = true,
  }) : _engine = fsrs.Scheduler(
          desiredRetention: desiredRetention,
          learningSteps: [
            for (final minutes in learningStepsMinutes)
              Duration(minutes: minutes),
          ],
          relearningSteps: [
            for (final minutes in relearningStepsMinutes)
              Duration(minutes: minutes),
          ],
          maximumInterval: maximumIntervalDays,
          enableFuzzing: fuzz,
        );

  factory FsrsScheduler.fromSettings(AppSettings settings) => FsrsScheduler(
        desiredRetention: settings.desiredRetention,
        learningStepsMinutes: settings.learningStepsMinutes,
        relearningStepsMinutes: settings.relearningStepsMinutes,
        maximumIntervalDays: settings.maximumIntervalDays,
        fuzz: settings.fuzz,
      );

  final fsrs.Scheduler _engine;

  @override
  Map<Grade, Memory> outcomes(Memory memory, DateTime now) {
    final at = now.toUtc();
    final card = _toFsrs(memory);
    return {
      for (final grade in Grade.values)
        grade: _fromFsrs(
          _engine.reviewCard(card, _rating(grade), reviewDateTime: at).card,
        ),
    };
  }

  static fsrs.Rating _rating(Grade grade) => switch (grade) {
        Grade.again => fsrs.Rating.again,
        Grade.hard => fsrs.Rating.hard,
        Grade.good => fsrs.Rating.good,
        Grade.easy => fsrs.Rating.easy,
      };

  static fsrs.Card _toFsrs(Memory memory) => fsrs.Card(
        // L'identifiant ne sert qu'au journal du paquet, que l'appli n'utilise
        // pas : elle tient son propre historique (table reviews).
        cardId: 0,
        state: switch (memory.state) {
          LearningState.learning => fsrs.State.learning,
          LearningState.review => fsrs.State.review,
          LearningState.relearning => fsrs.State.relearning,
        },
        step: memory.step,
        stability: memory.stability,
        difficulty: memory.difficulty,
        due: memory.due.toUtc(),
        lastReview: memory.lastReview?.toUtc(),
      );

  static Memory _fromFsrs(fsrs.Card card) => Memory(
        state: switch (card.state) {
          fsrs.State.learning => LearningState.learning,
          fsrs.State.review => LearningState.review,
          fsrs.State.relearning => LearningState.relearning,
        },
        step: card.step,
        stability: card.stability,
        difficulty: card.difficulty,
        due: card.due.toUtc(),
        lastReview: card.lastReview?.toUtc(),
      );
}
