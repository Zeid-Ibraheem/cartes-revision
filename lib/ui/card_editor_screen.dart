import 'package:material_ui/material_ui.dart';

import '../data/database.dart';
import '../data/store.dart';
import '../domain/folder_path.dart';
import '../domain/models.dart';
import 'common.dart';

/// Ce que l'écran renvoie quand il corrigeait une carte.
class CardEditResult {
  const CardEditResult.saved(Flashcard this.card) : deleted = false;
  const CardEditResult.deleted()
      : card = null,
        deleted = true;

  /// La carte corrigée, ou `null` si elle a été supprimée.
  final Flashcard? card;
  final bool deleted;
}

/// Écran plein pour écrire une carte.
///
/// - Sans [card] : ajout. Après chaque carte, les champs se vident et on
///   enchaîne sur la suivante, dans le paquet choisi en haut (existant ou créé
///   sur place).
/// - Avec [card] : correction ou suppression de cette carte.
class CardEditorScreen extends StatefulWidget {
  const CardEditorScreen({super.key, required this.store, this.deck, this.card});

  final AppStore store;

  /// Paquet proposé au départ (ajout).
  final Deck? deck;

  /// Carte à corriger.
  final Flashcard? card;

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  late final TextEditingController _front =
      TextEditingController(text: widget.card?.front ?? '');
  late final TextEditingController _back =
      TextEditingController(text: widget.card?.back ?? '');
  final FocusNode _frontFocus = FocusNode();
  late Deck? _deck = widget.deck;
  int _added = 0;
  String? _error;
  bool _busy = false;

  /// Ajouter aussi la carte dans l'autre sens (réponse → question).
  bool _inverse = false;

  AppStore get _store => widget.store;
  bool get _editing => widget.card != null;

  @override
  void initState() {
    super.initState();
    // Paquet proposé : celui de la dernière carte écrite, ou le seul qui
    // existe. Inutile de le rechoisir à chaque fois.
    final decks = _store.decks;
    if (_deck == null && !_editing) {
      _deck = _store.lastDeck ?? (decks.length == 1 ? decks.single : null);
    }
  }

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    _frontFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDeck() async {
    const create = Object();
    final choice = await showActionSheet<Object>(
      context,
      title: 'Dans quel paquet ?',
      actions: [
        for (final deck in _store.decks)
          SheetAction(deck, '${displayFolder(deck.folder)} › ${deck.name}',
              Icons.style_outlined),
        const SheetAction(create, 'Nouveau paquet…', Icons.add),
      ],
    );
    if (choice == null || !mounted) return;
    if (choice is Deck) {
      setState(() => _deck = choice);
      return;
    }
    final values = await showFieldsDialog(
      context,
      title: 'Nouveau paquet',
      action: 'Créer',
      fields: [
        FieldSpec(
          label: 'Dossier',
          hint: 'ex. Cours/R3.07 (niveaux séparés par /)',
          initial: _deck?.folder ?? '',
          suggestions: _store.folderNames,
        ),
        const FieldSpec(label: 'Paquet', hint: 'ex. Contrôle 1'),
      ],
    );
    if (values == null || !mounted) return;
    try {
      final deck = await _store.createDeck(values[0], values[1]);
      await _store.reveal(deck.folder);
      if (mounted) setState(() => _deck = deck);
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error));
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final deck = _deck;
    if (!_editing && deck == null) {
      setState(() => _error = 'Choisis d’abord un paquet, en haut.');
      return;
    }
    if (_front.text.trim().isEmpty || _back.text.trim().isEmpty) {
      setState(() => _error = 'Il faut une question et une réponse.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final card = widget.card;
      if (card != null) {
        final updated = await _store.updateCard(card, _front.text, _back.text);
        if (mounted) Navigator.of(context).pop(CardEditResult.saved(updated));
        return;
      }
      await _store.addCard(deck!, _front.text, _back.text);
      var added = 1;
      String? note;
      if (_inverse) {
        try {
          await _store.addCard(deck, _back.text, _front.text);
          added++;
        } on CardFrontTaken {
          note = 'Carte inverse non ajoutée : cette question existe déjà '
              'dans le paquet.';
        }
      }
      await _store.rememberDeck(deck);
      if (!mounted) return;
      setState(() {
        _added += added;
        _error = note;
        _front.clear();
        _back.clear();
      });
      _frontFocus.requestFocus();
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final card = widget.card;
    if (card == null) return;
    final sure = await confirmDialog(
      context,
      title: 'Supprimer la carte ?',
      message: 'La carte et son historique de révision seront effacés.',
      action: 'Supprimer',
      danger: true,
    );
    if (!sure || !mounted) return;
    try {
      await _store.deleteCard(card);
      if (mounted) Navigator.of(context).pop(const CardEditResult.deleted());
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error));
    }
  }

  /// Du texte a été tapé et pas encore enregistré.
  bool get _dirty =>
      _front.text != (widget.card?.front ?? '') ||
      _back.text != (widget.card?.back ?? '');

  /// Retour arrière : si du texte serait perdu, on demande d'abord.
  Future<void> _leave() async {
    if (_dirty) {
      final sure = await confirmDialog(
        context,
        title: _editing ? 'Abandonner les corrections ?' : 'Abandonner cette carte ?',
        message: 'Ce que tu as tapé ne sera pas enregistré.',
        action: 'Abandonner',
        danger: true,
      );
      if (!sure) return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final deck = _deck;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Corriger la carte' : 'Nouvelle carte'),
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Supprimer la carte',
              icon: Icon(Icons.delete_outline, color: scheme.error),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  if (!_editing) ...[
                    const Caption('Paquet'),
                    Panel(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      onTap: _pickDeck,
                      child: Row(
                          children: [
                            Expanded(
                              child: deck == null
                                  ? Text('Choisir un paquet',
                                      style: TextStyle(
                                          color: scheme.onSurfaceVariant))
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(displayFolder(deck.folder),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                    color: scheme
                                                        .onSurfaceVariant)),
                                        Text(deck.name,
                                            style: theme.textTheme.titleMedium),
                                      ],
                                    ),
                            ),
                            Icon(Icons.expand_more,
                                color: scheme.onSurfaceVariant),
                          ],
                        ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  const Caption('Question'),
                  _SideField(
                    controller: _front,
                    focusNode: _frontFocus,
                    autofocus: !_editing && deck != null,
                    minLines: 4,
                    hint: 'Ce que l’appli te demandera',
                  ),
                  const SizedBox(height: 20),
                  const Caption('Réponse'),
                  _SideField(
                    controller: _back,
                    minLines: 6,
                    hint: 'Ce que tu dois retrouver',
                  ),
                  if (!_editing) ...[
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: const Text('Créer aussi la carte inverse'),
                      subtitle: Text(
                        'La réponse devient la question, et inversement.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      value: _inverse,
                      onChanged: (value) => setState(() => _inverse = value),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: TextStyle(color: scheme.error)),
                  ],
                  if (_added > 0) ...[
                    const SizedBox(height: 16),
                    Text(
                      _added == 1
                          ? '1 carte ajoutée. Écris la suivante, ou reviens en arrière.'
                          : '$_added cartes ajoutées. Écris la suivante, ou reviens en arrière.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54)),
                onPressed: _busy ? null : _save,
                child: Text(_editing
                    ? 'Enregistrer'
                    : _inverse
                        ? 'Ajouter les 2 cartes'
                        : 'Ajouter la carte'),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

/// Grand champ de texte pour une face de carte.
class _SideField extends StatelessWidget {
  const _SideField({
    required this.controller,
    required this.minLines,
    required this.hint,
    this.focusNode,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final int minLines;
  final String hint;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color),
        );
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      minLines: minLines,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 17, height: 1.35),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withAlpha(170)),
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.all(16),
        border: border(scheme.outlineVariant),
        enabledBorder: border(scheme.outlineVariant),
        focusedBorder: border(scheme.onSurfaceVariant),
      ),
    );
  }
}
