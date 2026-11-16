import 'package:cartes_revision/domain/format.dart';
import 'package:cartes_revision/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('délais lisibles', () {
    expect(formatDelay(const Duration(seconds: 30)), '< 1 min');
    expect(formatDelay(const Duration(minutes: 1)), '1 min');
    expect(formatDelay(const Duration(seconds: 330)), '5 min');
    expect(formatDelay(const Duration(hours: 3, minutes: 59)), '3 h');
    expect(formatDelay(const Duration(days: 1)), '1 j');
    expect(formatDelay(const Duration(days: 30)), '30 j');
    expect(formatDelay(const Duration(days: 60)), '2 mois');
    expect(formatDelay(const Duration(days: 76)), '2,5 mois');
    expect(formatDelay(const Duration(days: 365)), '1 an');
    expect(formatDelay(const Duration(days: 500)), '1,4 an');
    expect(formatDelay(const Duration(days: 730)), '2 ans');
  });

  test('échéance d’une carte', () {
    final now = DateTime.utc(2026, 11, 16, 12);
    expect(describeDue(Memory.fresh(now), now), 'nouvelle');
    final reviewed = Memory(
      state: LearningState.review,
      due: now.add(const Duration(days: 3)),
      lastReview: now,
      stability: 3,
      difficulty: 5,
    );
    expect(describeDue(reviewed, now), 'dans 3 j');
    expect(describeDue(reviewed, now.add(const Duration(days: 4))), 'à revoir');
  });
}
