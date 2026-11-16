import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../data/store.dart';
import '../domain/format.dart';
import '../domain/models.dart';
import '../domain/study_session.dart';
import 'common.dart';

/// Une séance de révision : question, « Voir la réponse », puis la note.
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
    final card = _session?.current;
    if (card == null) return;
    final result = await showFieldsDialog(
      context,
      title: 'Corriger la carte',
      action: 'Enregistrer',
      fields: [
        FieldSpec(label: 'Question', initial: card.front, multiline: true),
        FieldSpec(label: 'Réponse', initial: card.back, multiline: true),
      ],
    );
    if (result == null || !mounted) return;
    try {
      final updated = await _store.updateCard(card, result.values[0], result.values[1]);
      if (mounted) setState(() => _session!.replaceCurrent(updated));
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.scope.label),
            if (session != null)
              Text(
                '${session.remaining} restante(s) · ${session.answered} faite(s)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          if (session?.current != null)
            IconButton(
              tooltip: 'Corriger la carte',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
        ],
      ),
      body: SafeArea(child: _body(context, session)),
    );
  }

  Widget _body(BuildContext context, StudySession? session) {
    if (session == null) return const Center(child: CircularProgressIndicator());
    final card = session.current;
    if (card == null) return _pause(context, session);

    final settings = _store.settings;
    final theme = Theme.of(context);
    final size = 20 * settings.textScale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (card.memory.isNew)
                  Text('Nouvelle carte',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 8),
                SelectableText(card.front,
                    style: TextStyle(fontSize: size, height: 1.35)),
                if (_showAnswer) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(),
                  ),
                  SelectableText(
                    card.back,
                    style: TextStyle(
                      fontSize: size,
                      height: 1.35,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: _showAnswer
              ? _gradeButtons(context, session)
              : FilledButton(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56)),
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
    final grades = settings.fourButtons
        ? Grade.values
        : const [Grade.again, Grade.good];
    return Row(
      children: [
        for (final grade in grades)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  backgroundColor: grade == Grade.again
                      ? scheme.errorContainer
                      : null,
                  foregroundColor: grade == Grade.again
                      ? scheme.onErrorContainer
                      : null,
                ),
                onPressed: () => _answer(grade),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_label(grade), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (settings.showDelays)
                      Text(formatDelay(session.delayFor(grade)),
                          style: const TextStyle(fontSize: 12)),
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

  Widget _pause(BuildContext context, StudySession session) {
    final theme = Theme.of(context);
    final until = session.waitingUntil;
    final finished = session.isFinished;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(finished ? Icons.check_circle_outline : Icons.hourglass_empty,
                size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              finished ? 'Séance terminée' : 'Pause',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              finished
                  ? (session.answered == 0
                      ? 'Rien à réviser ici pour l’instant.'
                      : '${session.answered} réponse(s) enregistrée(s).')
                  : 'Une carte en apprentissage revient dans '
                      '${formatDelay(until!.difference(DateTime.now().toUtc()))}. '
                      'Elle s’affichera toute seule si tu restes sur cet écran.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }
}
