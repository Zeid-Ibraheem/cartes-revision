import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../data/store.dart';
import '../domain/format.dart';
import '../domain/models.dart';
import '../domain/study_session.dart';
import 'card_editor_screen.dart';
import 'common.dart';
import 'theme.dart';

/// Une séance de révision : la question dans son bloc, un appui pour voir la
/// réponse, puis la note. Les trois compteurs restent visibles en haut, celui
/// de la carte affichée est souligné.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.store, required this.scope});

  final AppStore store;
  final StudyScope scope;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  StudySession? _session;
  bool _showAnswer = false;
  final Stopwatch _watch = Stopwatch();
  Timer? _wakeUp;

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

  /// Après chaque changement de carte : chronomètre, et réveil automatique si
  /// la séance attend une carte en apprentissage.
  void _afterMove() {
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

  Future<void> _answer(Grade grade) async {
    final session = _session!;
    final before = session.current!;
    final durationMs = _watch.elapsedMilliseconds;
    final after = session.answer(grade);
    setState(() => _showAnswer = false);
    _afterMove();
    try {
      await _store.recordAnswer(
        before: before,
        after: after,
        grade: grade,
        durationMs: durationMs,
      );
    } catch (error) {
      if (mounted) {
        showSnack(context, 'Réponse non enregistrée : ${errorMessage(error)}');
      }
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
    final scheme = Theme.of(context).colorScheme;
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
            onTap: _showAnswer ? null : () => setState(() => _showAnswer = true),
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
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 28),
                      child: Text(
                        'Réponds dans ta tête, puis touche l’écran.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.outlineVariant),
                      ),
                    ),
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
                  onPressed: () => setState(() => _showAnswer = true),
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
                  backgroundColor: scheme.surfaceContainerHighest,
                  foregroundColor: signal.grade(grade),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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

  /// Rien à montrer : séance terminée, ou attente d'une carte en
  /// apprentissage.
  Widget _pause(BuildContext context, StudySession session) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final until = session.waitingUntil;
    final String title;
    final String message;
    if (until != null) {
      title = 'Pause';
      message = 'Une carte en apprentissage revient dans '
          '${formatDelay(until.difference(DateTime.now().toUtc()))}. '
          'Elle s’affichera toute seule si tu restes ici.';
    } else if (session.answered == 0) {
      title = 'Rien à réviser';
      message = 'Tout est à jour ici pour l’instant.';
    } else {
      title = 'Séance terminée';
      message = session.answered == 1
          ? '1 réponse enregistrée.'
          : '${session.answered} réponses enregistrées.';
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant)),
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
