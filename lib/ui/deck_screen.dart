import 'package:material_ui/material_ui.dart';

import '../data/store.dart';
import '../domain/folder_path.dart';
import '../domain/format.dart';
import '../domain/models.dart';
import '../domain/study_session.dart';
import 'card_editor_screen.dart';
import 'common.dart';
import 'home_screen.dart';
import 'practice_screen.dart';
import 'review_screen.dart';
import 'stats_screen.dart';
import 'theme.dart';

/// Un paquet : ses compteurs, le bouton de révision et la liste de ses cartes.
/// Appui sur une carte pour la corriger, appui long pour la supprimer.
class DeckScreen extends StatefulWidget {
  const DeckScreen({super.key, required this.store, required this.deck});

  final AppStore store;
  final Deck deck;

  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen> {
  late Deck _deck = widget.deck;
  List<Flashcard>? _cards;
  String _query = '';

  AppStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final cards = await _store.cardsOf(_deck);
    if (mounted) setState(() => _cards = cards);
  }

  List<Flashcard> _visible(List<Flashcard> cards) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return cards;
    return cards
        .where((card) =>
            card.front.toLowerCase().contains(query) ||
            card.back.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<Object?>(builder: (_) => screen));
    await _reload();
  }

  Future<void> _cardMenu(Flashcard card) async {
    final choice = await showActionSheet<String>(
      context,
      title: card.front,
      actions: const [
        SheetAction('edit', 'Corriger', Icons.edit_outlined),
        SheetAction('delete', 'Supprimer', Icons.delete_outline, danger: true),
      ],
    );
    if (choice == null || !mounted) return;
    if (choice == 'edit') {
      await _open(CardEditorScreen(store: _store, card: card));
      return;
    }
    final sure = await confirmDialog(
      context,
      title: 'Supprimer la carte ?',
      message: 'La carte et son historique de révision seront effacés.',
      action: 'Supprimer',
      danger: true,
    );
    if (!sure) return;
    await _store.deleteCard(card);
    await _reload();
  }

  Future<void> _deckMenu() async {
    final choice = await showActionSheet<String>(
      context,
      title: '${displayFolder(_deck.folder)} › ${_deck.name}',
      actions: const [
        SheetAction('stats', 'Statistiques', Icons.bar_chart),
        SheetAction('rename', 'Renommer ou déplacer', Icons.drive_file_move_outline),
        SheetAction('delete', 'Supprimer le paquet', Icons.delete_outline,
            danger: true),
      ],
    );
    if (choice == null || !mounted) return;
    if (choice == 'stats') {
      await _open(StatsScreen(store: _store, scope: DeckCards(_deck)));
      return;
    }
    if (choice == 'rename') {
      final deck = await renameDeck(context, _store, _deck);
      if (deck == null) return;
      await _store.reveal(deck.folder);
      if (mounted) setState(() => _deck = deck);
      return;
    }
    final deleted = await deleteDeck(context, _store, _deck);
    if (deleted && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cards = _cards;
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_deck.name),
            Text(displayFolder(_deck.folder),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actions du paquet',
            icon: const Icon(Icons.more_horiz),
            onPressed: _deckMenu,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Écrire des cartes',
        onPressed: () => _open(CardEditorScreen(store: _store, deck: _deck)),
        child: const Icon(Icons.add),
      ),
      body: cards == null
          ? const Center(child: CircularProgressIndicator())
          : _content(context, cards, now),
    );
  }

  Widget _content(BuildContext context, List<Flashcard> cards, DateTime now) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final signal = Signal.of(context);
    final today = _store
        .today(countDue(cards, now, _store.settings.dayStartHour));
    final visible = _visible(cards);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _BigCount(today.fresh, 'Nouvelles', signal.fresh),
                  _BigCount(today.learning, 'En apprentissage', signal.learning),
                  _BigCount(today.review, 'À réviser', signal.review),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                onPressed: today.total == 0
                    ? null
                    : () => _open(
                        ReviewScreen(store: _store, scope: DeckCards(_deck))),
                child: Text(today.total == 0
                    ? 'Rien à réviser pour l’instant'
                    : 'Réviser · ${today.total}'),
              ),
              if (cards.isNotEmpty) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: scheme.onSurface,
                    side: BorderSide(color: scheme.outlineVariant),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _open(
                      PracticeScreen(store: _store, scope: DeckCards(_deck))),
                  icon: const Icon(Icons.fitness_center, size: 20),
                  label: const Text('Entraînement libre'),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toutes les cartes, sans changer leurs dates de révision.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Caption(cards.length > 1 ? '${cards.length} cartes' : '${cards.length} carte'),
        if (cards.length > 8) ...[
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Chercher',
              isDense: true,
              filled: true,
              fillColor: scheme.surfaceContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 12),
        ],
        if (cards.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Text(
              'Ce paquet est vide. Écris ta première carte avec le bouton +.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        for (final card in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              padding: const EdgeInsets.all(14),
              onTap: () => _open(CardEditorScreen(store: _store, card: card)),
              onLongPress: () => _cardMenu(card),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.front,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(card.back,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Text(
                      describeDue(card.memory, now),
                      style: TextStyle(
                        fontSize: 12,
                        color: card.memory.due.isAfter(now) && !card.memory.isNew
                            ? scheme.onSurfaceVariant
                            : signal.kind(kindOf(card.memory)),
                      ),
                    ),
                  ],
                ),
            ),
          ),
      ],
    );
  }
}

/// Un grand compteur coloré avec son nom dessous.
class _BigCount extends StatelessWidget {
  const _BigCount(this.value, this.label, this.color);

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: value == 0 ? Signal.of(context).faint : color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
