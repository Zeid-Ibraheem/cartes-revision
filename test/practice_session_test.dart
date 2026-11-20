import 'package:cartes_revision/domain/models.dart';
import 'package:cartes_revision/domain/practice_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 20, 12);

  Flashcard card(int id) => Flashcard(
        id: id,
        deckId: 1,
        front: 'Q$id',
        back: 'R$id',
        memory: Memory.fresh(now),
      );

  PracticeSession session(int n) =>
      PracticeSession(cards: [for (var i = 1; i <= n; i++) card(i)], shuffle: false);

  test('toutes les cartes, dans l’ordre si pas de mélange', () {
    final s = session(3);
    expect(s.total, 3);
    expect(s.current!.id, 1);
    expect(s.remaining, 3);
  });

  test('« Su » sort la carte, « À revoir » la remet 3 cartes plus loin', () {
    final s = session(6);
    s.again(); // 1 revient après 2, 3, 4
    expect(s.current!.id, 2);
    s.know(); // 2
    s.know(); // 3
    s.know(); // 4
    expect(s.current!.id, 1);
    expect(s.remaining, 3, reason: '1, 5 et 6');
  });

  test('carte ratée quand il en reste peu : elle passe à la fin', () {
    final s = session(2);
    s.again();
    expect(s.current!.id, 2);
    s.know();
    expect(s.current!.id, 1);
    s.know();
    expect(s.isFinished, isTrue);
  });

  test('bilan : sues, du premier coup, ratées', () {
    final s = session(3);
    s.know(); // 1 du premier coup
    s.again(); // 2 ratée
    s.know(); // 3 du premier coup
    s.know(); // 2 finalement sue
    expect(s.isFinished, isTrue);
    expect(s.done, 3);
    expect(s.firstTry, 2);
    expect(s.missed, 1);
    expect(s.missedIds, {2});
  });

  test('rien n’est modifié sur les cartes', () {
    final cards = [card(1), card(2)];
    final s = PracticeSession(cards: cards, shuffle: false);
    s.again();
    s.know();
    s.know();
    expect(cards.every((c) => c.memory.isNew), isTrue);
  });

  test('correction et suppression de la carte en cours', () {
    final s = session(2);
    s.replaceCurrent(card(1).copyWith(front: 'corrigée'));
    expect(s.current!.front, 'corrigée');
    s.dropCurrent();
    expect(s.current!.id, 2);
    expect(s.done, 0, reason: 'une carte supprimée ne compte pas comme sue');
  });

  test('aucune carte', () {
    final s = session(0);
    expect(s.isFinished, isTrue);
    expect(s.current, isNull);
    s.know();
    s.again();
    expect(s.done, 0);
  });
}
