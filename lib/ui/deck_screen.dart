import 'package:material_ui/material_ui.dart';

import '../data/store.dart';
import '../domain/format.dart';
import '../domain/models.dart';
import 'common.dart';
import 'review_screen.dart';

/// Un paquet : ses cartes, et les actions pour le modifier.
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

  List<Flashcard> get _visible {
    final cards = _cards ?? const <Flashcard>[];
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return cards;
    return cards
        .where((card) =>
            card.front.toLowerCase().contains(query) ||
            card.back.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_deck.name),
            Text(_deck.folder, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Réviser ce paquet',
            icon: const Icon(Icons.play_arrow),
            onPressed: () => _review(context),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => switch (value) {
              'rename' => _rename(context),
              'delete' => _delete(context),
              _ => null,
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Renommer ou déplacer')),
              PopupMenuItem(value: 'delete', child: Text('Supprimer le paquet')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCard(context),
        icon: const Icon(Icons.add),
        label: const Text('Carte'),
      ),
      body: cards == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (cards.length > 8)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Chercher dans les cartes',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                Expanded(
                  child: cards.isEmpty
                      ? const Center(child: Text('Aucune carte : ajoute-en avec +'))
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: _visible.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final card = _visible[index];
                            return ListTile(
                              title: Text(card.front,
                                  maxLines: 3, overflow: TextOverflow.ellipsis),
                              subtitle: Text(card.back,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              trailing: Text(describeDue(card.memory, now),
                                  style: Theme.of(context).textTheme.bodySmall),
                              onTap: () => _editCard(context, card),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _review(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ReviewScreen(store: _store, scope: DeckCards(_deck)),
    ));
    await _reload();
  }

  Future<void> _addCard(BuildContext context) async {
    // La fenêtre se rouvre après chaque carte : on en ajoute plusieurs
    // d'affilée, et « Annuler » arrête.
    while (true) {
      if (!context.mounted) return;
      final result = await showFieldsDialog(
        context,
        title: 'Nouvelle carte',
        action: 'Ajouter',
        fields: const [
          FieldSpec(label: 'Question', multiline: true),
          FieldSpec(label: 'Réponse', multiline: true),
        ],
      );
      if (result == null || !context.mounted) break;
      try {
        await _store.addCard(_deck, result.values[0], result.values[1]);
        await _reload();
      } catch (error) {
        if (context.mounted) showSnack(context, errorMessage(error));
        break;
      }
    }
  }

  Future<void> _editCard(BuildContext context, Flashcard card) async {
    final result = await showFieldsDialog(
      context,
      title: 'Corriger la carte',
      action: 'Enregistrer',
      deleteLabel: 'Supprimer',
      fields: [
        FieldSpec(label: 'Question', initial: card.front, multiline: true),
        FieldSpec(label: 'Réponse', initial: card.back, multiline: true),
      ],
    );
    if (result == null || !context.mounted) return;
    try {
      if (result.deleted) {
        final sure = await confirmDialog(
          context,
          title: 'Supprimer la carte ?',
          message: 'La carte et son historique de révision seront effacés.',
          action: 'Supprimer',
        );
        if (!sure) return;
        await _store.deleteCard(card);
      } else {
        await _store.updateCard(card, result.values[0], result.values[1]);
      }
      await _reload();
    } catch (error) {
      if (context.mounted) showSnack(context, errorMessage(error));
    }
  }

  Future<void> _rename(BuildContext context) async {
    final result = await showFieldsDialog(
      context,
      title: 'Renommer ou déplacer',
      action: 'Enregistrer',
      fields: [
        FieldSpec(
          label: 'Dossier',
          initial: _deck.folder,
          suggestions: _store.folderNames,
        ),
        FieldSpec(label: 'Paquet', initial: _deck.name),
      ],
    );
    if (result == null || !context.mounted) return;
    try {
      final deck = await _store.updateDeck(_deck, result.values[0], result.values[1]);
      if (mounted) setState(() => _deck = deck);
    } catch (error) {
      if (context.mounted) showSnack(context, errorMessage(error));
    }
  }

  Future<void> _delete(BuildContext context) async {
    final count = _cards?.length ?? 0;
    final sure = await confirmDialog(
      context,
      title: 'Supprimer « ${_deck.name} » ?',
      message: 'Ses $count carte(s) et leur historique de révision seront '
          'effacés. Impossible de revenir en arrière.',
      action: 'Supprimer',
    );
    if (!sure || !context.mounted) return;
    await _store.deleteDeck(_deck);
    if (context.mounted) Navigator.of(context).pop();
  }
}
