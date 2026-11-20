/// L'entraînement libre : revoir des cartes quand on veut (avant un
/// contrôle, par exemple) SANS rien changer à leurs dates de révision ni aux
/// statistiques. Rien n'est enregistré.
library;

import 'dart:math';

import 'models.dart';

/// Une carte ratée revient après ce nombre de cartes (ou à la fin s'il en
/// reste moins) : assez loin pour ne pas répondre de mémoire immédiate.
const practiceRetryGap = 3;

class PracticeSession {
  PracticeSession({
    required Iterable<Flashcard> cards,
    bool shuffle = true,
    Random? random,
  }) {
    _queue.addAll(cards);
    _queue.sort((a, b) => a.id.compareTo(b.id));
    if (shuffle) _queue.shuffle(random ?? Random());
    total = _queue.length;
  }

  final List<Flashcard> _queue = [];

  /// Cartes ratées au moins une fois.
  final Set<int> _missed = {};

  /// Nombre de cartes au départ.
  late final int total;

  int _done = 0;

  /// La carte à montrer, ou `null` quand l'entraînement est fini.
  Flashcard? get current => _queue.isEmpty ? null : _queue.first;

  bool get isFinished => _queue.isEmpty;

  /// Cartes pas encore sues (celle en cours comprise).
  int get remaining => _queue.length;

  /// Cartes sues (réussies au moins une fois).
  int get done => _done;

  /// Cartes sues du premier coup.
  int get firstTry => _done - _missed.length;

  /// Cartes ratées au moins une fois.
  int get missed => _missed.length;

  /// Numéros des cartes ratées au moins une fois (pour les revoir).
  Set<int> get missedIds => Set.unmodifiable(_missed);

  /// Carte sue : elle sort de l'entraînement.
  void know() {
    if (_queue.isEmpty) return;
    _queue.removeAt(0);
    _done++;
  }

  /// Carte ratée : elle revient un peu plus loin.
  void again() {
    if (_queue.isEmpty) return;
    final card = _queue.removeAt(0);
    _missed.add(card.id);
    final at = practiceRetryGap < _queue.length ? practiceRetryGap : _queue.length;
    _queue.insert(at, card);
  }

  /// Remplace le texte de la carte en cours (après une correction).
  void replaceCurrent(Flashcard card) {
    if (_queue.isNotEmpty && _queue.first.id == card.id) _queue[0] = card;
  }

  /// Retire la carte en cours (elle vient d'être supprimée).
  void dropCurrent() {
    if (_queue.isEmpty) return;
    _queue.removeAt(0);
  }
}
