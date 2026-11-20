import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import '../data/database.dart';
import '../data/store.dart';
import '../domain/card_file.dart';
import '../domain/folder_path.dart';
import '../domain/models.dart';
import '../domain/stats.dart';
import '../domain/study_session.dart';
import 'card_editor_screen.dart';
import 'common.dart';
import 'deck_screen.dart';
import 'review_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

/// Écran d'accueil, comme AnkiDroid : l'arbre des dossiers et des paquets,
/// les trois compteurs à droite, le bouton + qui ouvre ses actions, et le
/// bilan du jour en bas.
///
/// - Appui sur un nom : révision (ou, s'il n'y a rien à revoir, ouverture
///   du dossier ou de la liste des cartes du paquet).
/// - Appui sur la flèche : déplier ou replier le dossier.
/// - Appui long : toutes les actions (statistiques, renommer, déplacer…).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _dialOpen = false;

  AppStore get store => widget.store;

  void _closeDial() {
    if (_dialOpen) setState(() => _dialOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => PopScope(
        // Le retour arrière referme d'abord le menu du bouton +.
        canPop: !_dialOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _closeDial();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text(appName),
            actions: [
              IconButton(
                tooltip: 'Statistiques',
                icon: const Icon(Icons.bar_chart),
                onPressed: () => _push(
                    context, StatsScreen(store: store, scope: const AllCards())),
              ),
              IconButton(
                tooltip: 'Réglages',
                icon: const Icon(Icons.tune),
                onPressed: () => _push(context, SettingsScreen(store: store)),
              ),
            ],
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: store.isEmpty ? _empty(context) : _list(context),
              ),
              if (_dialOpen)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _closeDial,
                    child: ColoredBox(color: scheme.surface.withAlpha(215)),
                  ),
                ),
            ],
          ),
          floatingActionButton: _SpeedDial(
            open: _dialOpen,
            onToggle: () => setState(() => _dialOpen = !_dialOpen),
            actions: [
              _DialAction('Importer un fichier', Icons.download, () {
                importCardFiles(context, store);
              }),
              _DialAction('Créer un dossier', Icons.create_new_folder_outlined,
                  () => _newFolder(context)),
              _DialAction('Créer un paquet', Icons.style_outlined,
                  () => _newDeck(context)),
              _DialAction('Ajouter des cartes', Icons.add_box_outlined,
                  () => _push(context, CardEditorScreen(store: store))),
            ],
            onAction: _closeDial,
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!store.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _reviewAllButton(context),
                    ),
                  Text(
                    todayLine(store.todayTotals),
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// « Tout réviser · 14 » : une seule séance avec les cartes dues de tous
  /// les dossiers. Grisé quand il n'y a rien à faire.
  Widget _reviewAllButton(BuildContext context) {
    final total = store.today(store.counts).total;
    return FilledButton(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      onPressed: total == 0 ? null : () => _review(context, const AllCards()),
      child: Text(total == 0 ? 'Rien à réviser' : 'Tout réviser · $total'),
    );
  }

  // ---------------------------------------------------------------- Liste

  Widget _list(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <Widget>[];
    void addFolder(FolderNode folder) {
      final open = store.isExpanded(folder.path);
      rows.add(_Row(
        title: folder.name,
        depth: folder.depth,
        folder: true,
        open: open,
        counts: store.today(folder.counts),
        onToggle: () => store.toggleExpanded(folder.path),
        onTap: () => _openFolder(context, folder),
        onLongPress: () => _folderMenu(context, folder),
      ));
      if (!open) return;
      folder.folders.forEach(addFolder);
      for (final stats in folder.decks) {
        rows.add(_Row(
          title: stats.deck.name,
          depth: folder.depth + 1,
          counts: store.today(stats.counts),
          onTap: () => _openDeck(context, stats),
          onLongPress: () => _deckMenu(context, stats.deck),
        ));
      }
    }

    store.folders.forEach(addFolder);
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 96),
      children: [
        ...rows,
        if (store.newLeftToday == 0 && store.counts.fresh > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              'Limite de nouvelles cartes atteinte pour aujourd’hui '
              '(${store.settings.newPerDay}, modifiable dans les réglages).',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Aucune carte', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Touche + pour créer un paquet, écrire des cartes ou importer '
              'un fichier.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Actions

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _review(BuildContext context, StudyScope scope) =>
      _push(context, ReviewScreen(store: store, scope: scope));

  /// Appui sur un dossier : révision de tout son contenu s'il y a quelque
  /// chose à voir, sinon il se déplie ou se replie.
  void _openFolder(BuildContext context, FolderNode folder) {
    if (store.today(folder.counts).total > 0) {
      _review(context, FolderCards(folder.path));
    } else {
      store.toggleExpanded(folder.path);
    }
  }

  /// Appui sur un paquet : révision s'il y a quelque chose à voir, sinon la
  /// liste de ses cartes.
  void _openDeck(BuildContext context, DeckStats stats) {
    if (store.today(stats.counts).total > 0) {
      _review(context, DeckCards(stats.deck));
    } else {
      _push(context, DeckScreen(store: store, deck: stats.deck));
    }
  }

  /// Un dossier n'existe qu'avec au moins un paquet : on crée les deux.
  Future<void> _newFolder(BuildContext context) async {
    final values = await showFieldsDialog(
      context,
      title: 'Créer un dossier',
      action: 'Créer',
      fields: [
        FieldSpec(
          label: 'Dossier',
          hint: 'ex. Connaissances, ou Cours/R3.07',
          suggestions: store.folderNames,
        ),
        const FieldSpec(label: 'Premier paquet', hint: 'ex. La Terre'),
      ],
    );
    if (values == null || !context.mounted) return;
    try {
      final deck = await store.createDeck(values[0], values[1]);
      await store.reveal(deck.folder);
      if (!context.mounted) return;
      _push(context, CardEditorScreen(store: store, deck: deck));
    } catch (error) {
      if (context.mounted) showSnack(context, errorMessage(error));
    }
  }

  Future<void> _newDeck(BuildContext context, {String folder = ''}) async {
    final values = await showFieldsDialog(
      context,
      title: 'Nouveau paquet',
      action: 'Créer',
      fields: [
        FieldSpec(
          label: 'Dossier',
          hint: 'ex. Cours/R3.07 (niveaux séparés par /)',
          initial: folder,
          suggestions: store.folderNames,
        ),
        const FieldSpec(label: 'Paquet', hint: 'ex. Contrôle 1'),
      ],
    );
    if (values == null || !context.mounted) return;
    try {
      final deck = await store.createDeck(values[0], values[1]);
      await store.reveal(deck.folder);
      if (!context.mounted) return;
      // Un paquet vide ne sert à rien : on enchaîne sur l'écriture des cartes.
      _push(context, CardEditorScreen(store: store, deck: deck));
    } catch (error) {
      if (context.mounted) showSnack(context, errorMessage(error));
    }
  }

  Future<void> _deckMenu(BuildContext context, Deck deck) async {
    final choice = await showActionSheet<String>(
      context,
      title: '${displayFolder(deck.folder)} › ${deck.name}',
      actions: const [
        SheetAction('review', 'Réviser', Icons.play_arrow),
        SheetAction('cards', 'Voir les cartes', Icons.list),
        SheetAction('stats', 'Statistiques', Icons.bar_chart),
        SheetAction('add', 'Écrire des cartes', Icons.edit_outlined),
        SheetAction('rename', 'Renommer ou déplacer', Icons.drive_file_move_outline),
        SheetAction('delete', 'Supprimer', Icons.delete_outline, danger: true),
      ],
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case 'review':
        _review(context, DeckCards(deck));
      case 'cards':
        _push(context, DeckScreen(store: store, deck: deck));
      case 'stats':
        _push(context, StatsScreen(store: store, scope: DeckCards(deck)));
      case 'add':
        _push(context, CardEditorScreen(store: store, deck: deck));
      case 'rename':
        final moved = await renameDeck(context, store, deck);
        if (moved != null) await store.reveal(moved.folder);
      case 'delete':
        await deleteDeck(context, store, deck);
    }
  }

  Future<void> _folderMenu(BuildContext context, FolderNode folder) async {
    final choice = await showActionSheet<String>(
      context,
      title: displayFolder(folder.path),
      actions: const [
        SheetAction('review', 'Réviser tout le dossier', Icons.play_arrow),
        SheetAction('stats', 'Statistiques', Icons.bar_chart),
        SheetAction('deck', 'Nouveau paquet ici', Icons.style_outlined),
        SheetAction('sub', 'Nouveau sous-dossier', Icons.create_new_folder_outlined),
        SheetAction('rename', 'Renommer', Icons.edit_outlined),
        SheetAction('move', 'Déplacer dans…', Icons.drive_file_move_outline),
        SheetAction('delete', 'Supprimer le dossier', Icons.delete_outline,
            danger: true),
      ],
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case 'review':
        if (store.today(folder.counts).total > 0) {
          _review(context, FolderCards(folder.path));
        } else {
          showSnack(context, 'Rien à réviser dans « ${folder.name} » pour l’instant');
        }
      case 'stats':
        _push(context, StatsScreen(store: store, scope: FolderCards(folder.path)));
      case 'deck':
        await _newDeck(context, folder: folder.path);
      case 'sub':
        await _newSubfolder(context, folder);
      case 'rename':
        final values = await showFieldsDialog(
          context,
          title: 'Renommer le dossier',
          action: 'Enregistrer',
          fields: [FieldSpec(label: 'Nom', initial: folder.name)],
        );
        if (values == null || !context.mounted) return;
        await _moveFolder(context, folder.path,
            joinFolder(folderParent(folder.path), values[0].replaceAll('/', ' ')));
      case 'move':
        final parent = folderParent(folder.path);
        final values = await showFieldsDialog(
          context,
          title: 'Déplacer « ${folder.name} » dans…',
          action: 'Déplacer',
          fields: [
            FieldSpec(
              label: 'Dossier parent (vide = tout en haut)',
              hint: 'ex. Cours',
              initial: parent,
              suggestions: [
                for (final path in store.folderNames)
                  if (!isInFolder(path, folder.path) && path != parent) path,
              ],
            ),
          ],
          validate: (_) => null,
        );
        if (values == null || !context.mounted) return;
        await _moveFolder(context, folder.path,
            joinFolder(normalizeFolder(values[0]), folder.name));
      case 'delete':
        final sure = await confirmDialog(
          context,
          title: 'Supprimer « ${folder.name} » ?',
          message: 'Tout ce qu’il contient sera effacé : '
              '${folder.deckCount} paquet(s), ${folder.total} carte(s) et '
              'leur historique de révision, sous-dossiers compris. '
              'Impossible de revenir en arrière.',
          action: 'Supprimer',
          danger: true,
        );
        if (sure) await store.deleteFolder(folder.path);
    }
  }

  Future<void> _moveFolder(BuildContext context, String from, String to) async {
    try {
      await store.moveFolder(from, to);
    } catch (error) {
      if (context.mounted) showSnack(context, errorMessage(error));
    }
  }

  /// Un dossier n'existe qu'avec au moins un paquet : on crée les deux.
  Future<void> _newSubfolder(BuildContext context, FolderNode parent) async {
    final values = await showFieldsDialog(
      context,
      title: 'Nouveau sous-dossier dans « ${parent.name} »',
      action: 'Créer',
      fields: const [
        FieldSpec(label: 'Sous-dossier', hint: 'ex. Physique'),
        FieldSpec(label: 'Premier paquet', hint: 'ex. La Terre'),
      ],
    );
    if (values == null || !context.mounted) return;
    try {
      final deck = await store.createDeck(
          joinFolder(parent.path, values[0].replaceAll('/', ' ')), values[1]);
      await store.reveal(deck.folder);
      if (!context.mounted) return;
      _push(context, CardEditorScreen(store: store, deck: deck));
    } catch (error) {
      if (context.mounted) showSnack(context, errorMessage(error));
    }
  }
}

/// Renomme un paquet ou le déplace dans un autre dossier. Renvoie le paquet
/// modifié, ou `null` si rien n'a changé.
Future<Deck?> renameDeck(BuildContext context, AppStore store, Deck deck) async {
  final values = await showFieldsDialog(
    context,
    title: 'Renommer ou déplacer',
    action: 'Enregistrer',
    fields: [
      FieldSpec(
        label: 'Dossier (niveaux séparés par /)',
        initial: deck.folder,
        suggestions: store.folderNames,
      ),
      FieldSpec(label: 'Paquet', initial: deck.name),
    ],
  );
  if (values == null) return null;
  try {
    return await store.updateDeck(deck, values[0], values[1]);
  } catch (error) {
    if (context.mounted) showSnack(context, errorMessage(error));
    return null;
  }
}

/// Supprime un paquet après confirmation. Renvoie `true` s'il a été supprimé.
Future<bool> deleteDeck(BuildContext context, AppStore store, Deck deck) async {
  final sure = await confirmDialog(
    context,
    title: 'Supprimer « ${deck.name} » ?',
    message: 'Ses cartes et leur historique de révision seront effacés. '
        'Impossible de revenir en arrière.',
    action: 'Supprimer',
    danger: true,
  );
  if (!sure) return false;
  await store.deleteDeck(deck);
  return true;
}

/// Ouvre un sélecteur de fichiers et importe les cartes choisies. Un import
/// sans remarque donne un simple message ; sinon le détail s'affiche.
Future<void> importCardFiles(BuildContext context, AppStore store) async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['txt', 'tsv'],
  );
  if (files.isEmpty || !context.mounted) return;

  var added = 0;
  var updated = 0;
  final details = <String>[];
  for (final file in files) {
    try {
      final bytes = <int>[];
      await for (final chunk in file.readAsByteStream()) {
        bytes.addAll(chunk);
      }
      final report = await store.importBytes(bytes, file.name);
      added += report.added;
      updated += report.updated;
      if (report.issues.isNotEmpty) details.add(_issuesText(file.name, report));
    } catch (error) {
      details.add('${file.name}\nLecture impossible : $error');
    }
  }
  try {
    await FilePicker.clearTemporaryFiles();
  } catch (_) {
    // Pas grave : Android vide aussi ce cache tout seul.
  }
  if (!context.mounted) return;

  final summary = '$added carte(s) ajoutée(s)'
      '${updated > 0 ? ', $updated réponse(s) mise(s) à jour' : ''}';
  if (details.isEmpty) {
    showSnack(context, summary);
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(summary),
      content: SingleChildScrollView(child: Text(details.join('\n\n'))),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

String _issuesText(String fileName, ImportReport report) {
  final buffer = StringBuffer('$fileName : ${report.issues.length} remarque(s)');
  for (final issue in report.issues.take(10)) {
    buffer.write('\n· ligne ${issue.line} : ${issue.message}');
  }
  if (report.issues.length > 10) {
    buffer.write('\n· … et ${report.issues.length - 10} autre(s)');
  }
  return buffer.toString();
}


/// Une ligne de l'arbre, comme AnkiDroid : flèche (dossiers), nom en gras,
/// puis les trois compteurs. Chaque niveau est décalé vers la droite.
class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.counts,
    required this.onTap,
    required this.onLongPress,
    required this.depth,
    this.onToggle,
    this.folder = false,
    this.open = false,
  });

  final String title;
  final DueCounts counts;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onToggle;
  final int depth;
  final bool folder;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 62),
        child: Padding(
          padding: EdgeInsets.only(left: 6.0 + depth * 24, right: 16),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 62,
                child: folder
                    ? InkResponse(
                        onTap: onToggle,
                        radius: 22,
                        child: Icon(
                          open ? Icons.expand_more : Icons.chevron_right,
                          size: 26,
                          color: scheme.onSurface,
                        ),
                      )
                    : null,
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              CountsRow(counts, fontSize: 18, columnWidth: 34),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une action du menu du bouton +.
class _DialAction {
  const _DialAction(this.label, this.icon, this.onPressed);

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

/// Le bouton + d'AnkiDroid : un appui déplie une pile d'actions au-dessus de
/// lui (la plus utilisée tout en bas, près du pouce), un autre appui la
/// replie.
class _SpeedDial extends StatelessWidget {
  const _SpeedDial({
    required this.open,
    required this.onToggle,
    required this.actions,
    required this.onAction,
  });

  final bool open;
  final VoidCallback onToggle;
  final List<_DialAction> actions;

  /// Appelé avant chaque action (pour refermer le menu).
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (open)
          for (final action in actions)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Material(
                color: scheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    onAction();
                    action.onPressed();
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(action.icon, size: 24, color: scheme.onSurface),
                        const SizedBox(width: 16),
                        Text(
                          action.label,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        FloatingActionButton(
          tooltip: open ? 'Fermer' : 'Ajouter',
          backgroundColor: scheme.surfaceContainerHighest,
          foregroundColor: scheme.onSurface,
          elevation: 0,
          onPressed: onToggle,
          child: AnimatedRotation(
            turns: open ? 0.125 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.add, size: 30),
          ),
        ),
      ],
    );
  }
}
