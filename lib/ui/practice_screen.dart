import 'package:material_ui/material_ui.dart';

import '../data/store.dart';
import '../domain/practice_session.dart';
import '../domain/stats.dart';
import 'card_editor_screen.dart';
import 'common.dart';
import 'theme.dart';

/// Entraînement libre : toutes les cartes d'un paquet ou d'un dossier, dans
/// le désordre, sans toucher aux dates de révision ni aux statistiques.
/// « À revoir » : la carte revient un peu plus loin. « Su » : elle sort.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, required this.store, required this.scope});

  final AppStore store;
  final StudyScope scope;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  /// Même protection contre le double appui que les vraies révisions.
  static const _tapLock = Duration(milliseconds: 300);

  PracticeSession? _session;
  bool _showAnswer = false;

  /// Si non nul : ne reprendre que ces cartes (les ratées du tour d'avant).
  Set<int>? _only;
  DateTime _lockedUntil = DateTime.fromMillisecondsSinceEpoch(0);

  AppStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final only = _only;
    final cards = [
      for (final card in await _store.cardsIn(widget.scope))
        if (only == null || only.contains(card.id)) card,
    ];
    if (!mounted) return;
    setState(() {
      _session = PracticeSession(cards: cards, shuffle: _store.settings.shuffle);
      _lock();
    });
  }

  bool get _locked => DateTime.now().isBefore(_lockedUntil);

  void _lock() => _lockedUntil = DateTime.now().add(_tapLock);

  void _reveal() {
    if (_showAnswer || _locked) return;
    setState(() {
      _showAnswer = true;
      _lock();
    });
  }

  void _grade({required bool known}) {
    final session = _session;
    if (session == null || !_showAnswer || _locked) return;
    setState(() {
      if (known) {
        session.know();
      } else {
        session.again();
      }
      _showAnswer = false;
      _lock();
    });
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
      _lock();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final card = session?.current;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.scope.label),
            Text(
              'Entraînement libre · les dates ne changent pas',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
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
                ? _end(context, session)
                : _card(context, session),
      ),
    );
  }

  Widget _card(BuildContext context, PracticeSession session) {
    final card = session.current!;
    final scheme = Theme.of(context).colorScheme;
    final signal = Signal.of(context);
    final size = 20 * _store.settings.textScale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: session.total == 0 ? 0 : session.done / session.total,
                  minHeight: 6,
                  color: signal.review,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${session.done} sue(s) sur ${session.total} · '
                '${session.remaining} restante(s)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showAnswer ? null : _reveal,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
              ? Row(
                  children: [
                    _gradeButton('À revoir', signal.learning,
                        () => _grade(known: false)),
                    _gradeButton('Su', signal.review, () => _grade(known: true)),
                  ],
                )
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

  Widget _gradeButton(String label, Color color, VoidCallback onPressed) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(60),
            foregroundColor: color,
          ),
          onPressed: onPressed,
          child: Text(label),
        ),
      ),
    );
  }

  Widget _end(BuildContext context, PracticeSession session) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final empty = session.total == 0;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            empty ? 'Aucune carte ici' : 'Entraînement terminé',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          if (!empty) ...[
            const SizedBox(height: 20),
            Panel(
              child: Row(
                children: [
                  _Figure('${session.done}', 'cartes sues'),
                  _Figure('${session.firstTry}', 'du premier coup'),
                  _Figure(
                    formatPercent(
                        session.done == 0 ? null : session.firstTry / session.done),
                    'réussite',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Rien n’a été enregistré : tes dates de révision et tes '
              'statistiques n’ont pas bougé.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 28),
          if (!empty && session.missed > 0) ...[
            FilledButton(
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              onPressed: () {
                setState(() {
                  _only = session.missedIds;
                  _session = null;
                  _showAnswer = false;
                });
                _start();
              },
              child: Text(session.missed == 1
                  ? 'Revoir la carte ratée'
                  : 'Revoir les ${session.missed} cartes ratées'),
            ),
            const SizedBox(height: 10),
          ],
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
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
