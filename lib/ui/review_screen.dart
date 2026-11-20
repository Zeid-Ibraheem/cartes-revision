import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../data/store.dart';
import '../domain/format.dart';
import '../domain/models.dart';
import '../domain/stats.dart';
import '../domain/study_session.dart';
import 'card_editor_screen.dart';
import 'common.dart';
import 'theme.dart';

/// Une réponse donnée dans cette séance : de quoi l'annuler et faire le bilan.
class _Answered {
  const _Answered(this.before, this.reviewId, this.grade, this.durationMs);

  /// La carte telle qu'elle était avant la réponse.
  final Flashcard before;
  final int reviewId;
  final Grade grade;
  final int durationMs;
}

/// Une séance de révision : la question dans son bloc, un appui pour voir la
/// réponse, puis la note. Les trois compteurs restent visibles en haut, celui
/// de la carte affichée est souligné. ↶ annule la dernière réponse.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.store, required this.scope});

  final AppStore store;
  final StudyScope scope;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  /// Temps de réponse maximum compté (comme Anki) : un téléphone posé sur une
  /// carte ne fausse pas les statistiques.
  static const _maxAnswerTime = Duration(seconds: 60);

  /// Après chaque changement d'écran, les appuis sont ignorés un instant : un
  /// double appui ne note pas la carte suivante sans l'avoir vue.
  static const _tapLock = Duration(milliseconds: 300);

  StudySession? _session;
  bool _showAnswer = false;

  /// Réponses en cours d'enregistrement : l'annulation attend qu'elles soient
  /// finies. Les réponses suivantes, elles, n'attendent pas.
  int _saving = 0;
  bool _undoing = false;
  final Stopwatch _watch = Stopwatch();
  DateTime _lockedUntil = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _wakeUp;
  final List<_Answered> _history = [];

  AppStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _wakeUp?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final session = await _store.startSession(widget.scope);
    if (!mounted) return;
    setState(() => _session = session);
    _afterMove();
  }

  bool get _locked => DateTime.now().isBefore(_lockedUntil);

  void _lock() => _lockedUntil = DateTime.now().add(_tapLock);

  /// Après chaque changement de carte : chronomètre, verrou anti double
  /// appui, et réveil automatique si la séance attend une carte en
  /// apprentissage.
  void _afterMove() {
    _lock();
    _watch
      ..reset()
      ..start();
    _wakeUp?.cancel();
    final until = _session?.waitingUntil;
    if (until != null) {
      final delay = until.difference(DateTime.now().toUtc());
      _wakeUp = Timer(delay.isNegative ? Duration.zero : delay, () {
        if (!mounted) return;
        setState(() => _session!.resume());
        _afterMove();
      });
    }
  }

  void _reveal() {
    if (_showAnswer || _locked) return;
    _lock();
    setState(() => _showAnswer = true);
  }

  Future<void> _answer(Grade grade) async {
    final session = _session;
    final before = session?.current;
    if (session == null || before == null || !_showAnswer || _locked) return;
    final durationMs =
        math.min(_watch.elapsedMilliseconds, _maxAnswerTime.inMilliseconds);
    final after = session.answer(grade);
    setState(() {
      _showAnswer = false;
      _saving++;
    });
    _afterMove();
    try {
      final reviewId = await _store.recordAnswer(
        before: before,
        after: after,
        grade: grade,
        durationMs: durationMs,
      );
      _history.add(_Answered(before, reviewId, grade, durationMs));
    } catch (error) {
      if (mounted) {
        showSnack(context, 'Réponse non enregistrée : ${errorMessage(error)}');
      }
    } finally {
      _saving--;
      if (mounted) setState(() {});
    }
  }

  bool get _canUndo => _history.isNotEmpty && _saving == 0 && !_undoing;

  /// Annule la dernière réponse : la carte revient, telle qu'avant.
  Future<void> _undo() async {
    final session = _session;
    if (session == null || !_canUndo) return;
    final last = _history.removeLast();
    setState(() => _undoing = true);
    try {
      await _store.undoAnswer(before: last.before, reviewId: last.reviewId);
      if (!mounted) return;
      setState(() {
        session.undo(last.before);
        _showAnswer = false;
      });
      _afterMove();
      showSnack(context, 'Réponse annulée');
    } catch (error) {
      _history.add(last);
      if (mounted) showSnack(context, errorMessage(error));
    } finally {
      _undoing = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _edit() async {
    final session = _session;
    final card = session?.current;
    if (session == null || card == null) return;
    final result = await Navigator.of(context).push(
      MaterialPageRoute<CardEditResult>(
        builder: (_) => CardEditorScreen(store: _store, card: card),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      final updated = result.card;
      if (updated != null) {
        session.replaceCurrent(updated);
      } else {
        // Carte supprimée : ses réponses de la séance ne s'annulent plus.
        _history.removeWhere((a) => a.before.id == card.id);
        session.dropCurrent();
        _showAnswer = false;
      }
    });
    if (result.deleted) _afterMove();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final card = session?.current;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.scope.label),
        actions: [
          IconButton(
            tooltip: 'Annuler la dernière réponse',
            icon: const Icon(Icons.undo),
            onPressed: _canUndo ? _undo : null,
          ),
          if (card != null)
            IconButton(
              tooltip: 'Corriger la carte',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
        ],
      ),
      body: SafeArea(
        child: session == null
            ? const Center(child: CircularProgressIndicator())
            : card == null
                ? _pause(context, session)
                : _card(context, session, card),
      ),
    );
  }

  Widget _card(BuildContext context, StudySession session, Flashcard card) {
    final size = 20 * _store.settings.textScale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Center(
            child: CountsRow(
              session.counts,
              highlight: kindOf(card.memory),
              fontSize: 17,
              columnWidth: 52,
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showAnswer ? null : _reveal,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Caption('Question'),
                  Panel(
                    padding: const EdgeInsets.all(20),
                    child: Text(card.front,
                        style: TextStyle(fontSize: size, height: 1.4)),
                  ),
                  if (_showAnswer) ...[
                    const SizedBox(height: 20),
                    const Caption('Réponse'),
                    Panel(
                      padding: const EdgeInsets.all(20),
                      child: Text(card.back,
                          style: TextStyle(fontSize: size, height: 1.4)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: _showAnswer
              ? _gradeButtons(context, session)
              : FilledButton(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(60)),
                  onPressed: _reveal,
                  child: const Text('Voir la réponse'),
                ),
        ),
      ],
    );
  }

  Widget _gradeButtons(BuildContext context, StudySession session) {
    final settings = _store.settings;
    final scheme = Theme.of(context).colorScheme;
    final signal = Signal.of(context);
    final grades =
        settings.fourButtons ? Grade.values : const [Grade.again, Grade.good];
    return Row(
      children: [
        for (final grade in grades)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  foregroundColor: signal.grade(grade),
                ),
                onPressed: () => _answer(grade),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_label(grade),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (settings.showDelays)
                      Text(
                        formatDelay(session.delayFor(grade)),
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _label(Grade grade) => switch (grade) {
        Grade.again => 'À revoir',
        Grade.hard => 'Difficile',
        Grade.good => 'Correct',
        Grade.easy => 'Facile',
      };

  /// Rien à montrer : séance terminée (avec son bilan), ou attente d'une
  /// carte en apprentissage.
  Widget _pause(BuildContext context, StudySession session) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final until = session.waitingUntil;
    final String title;
    final String? message;
    if (until != null) {
      title = 'Pause';
      message = 'Une carte en apprentissage revient dans '
          '${formatDelay(until.difference(DateTime.now().toUtc()))}. '
          'Elle s’affichera toute seule si tu restes ici.';
    } else if (_history.isEmpty) {
      title = 'Rien à réviser';
      message = 'Tout est à jour ici pour l’instant.';
    } else {
      title = 'Séance terminée';
      message = null;
    }
    final passed = _history.where((a) => a.grade != Grade.again).length;
    final ms = _history.fold(0, (sum, a) => sum + a.durationMs);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 20),
            Panel(
              child: Row(
                children: [
                  _Figure('${_history.length}',
                      _history.length > 1 ? 'cartes' : 'carte'),
                  _Figure(formatStudyTime(ms), 'de révision'),
                  _Figure(formatPercent(passed / _history.length), 'réussite'),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          FilledButton(
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }
}

/// Un chiffre du bilan, avec son nom dessous.
class _Figure extends StatelessWidget {
  const _Figure(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
