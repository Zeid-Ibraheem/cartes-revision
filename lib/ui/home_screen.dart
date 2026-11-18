import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import '../data/database.dart';
import '../data/store.dart';
import '../domain/card_file.dart';
import '../domain/folder_path.dart';
import '../domain/models.dart';
import '../domain/study_session.dart';
import 'card_editor_screen.dart';
import 'common.dart';
import 'deck_screen.dart';
import 'review_screen.dart';
import 'settings_screen.dart';

/// Écran d'accueil, à la façon d'Anki : la liste des dossiers et des paquets,
/// avec leurs trois compteurs. Un appui lance la révision, un appui long
/// ouvre les actions (voir, ajouter, renommer, supprimer).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final today = store.today(store.counts);
        return Scaffold(
          appBar: AppBar(
            title: const Text(appName),
            actions: [
              IconButton(
                tooltip: 'Réglages',
                icon: const Icon(Icons.tune),
                onPressed: () => _push(context, SettingsScreen(store: store)),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Ajouter',
            onPressed: () => _addMenu(context),
            child: const Icon(Icons.add),
          ),
          bottomNavigationBar: store.isEmpty
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54)),
                      onPressed: today.total == 0
                          ? null
                          : () => _review(context, const AllCards()),
                      child: Text(today.total == 0
                          ? 'Rien à réviser pour l’instant'
                          : 'Tout réviser · ${today.total}'),
                    ),
                  ),
                ),
          body: store.isEmpty ? _empty(context) : _list(context),
        );
      },
    );
  }

  // ---------------------------------------------------------------- Liste

  Widget _list(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = <Widget>[];
    void addFolder(FolderNode folder) {
      final open = store.isExpanded(folder.path);
      if (folder.depth == 0) rows.add(const SizedBox(height: 8));
      rows.add(_Row(
        title: folder.name,
        depth: folder.depth,
        folder: true,
        open: open,
        counts: store.today(folder.counts),
        onTap: () => store.toggleExpanded(folder.path),
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
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  store.newLeftToday == 0 && store.counts.fresh > 0
                      ? 'Nouvelles cartes : limite du jour atteinte'
                      : 'Appui long pour réviser ou modifier',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const CountsLegend(),
            ],
          ),
        ),
        ...rows,
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
              'Écris tes premières cartes, ou importe un fichier.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54)),
              onPressed: () => _push(context, CardEditorScreen(store: store)),
              child: const Text('Écrire une carte'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54)),
              onPressed: () => importCardFiles(context, store),
              child: const Text('Importer un fichier'),
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

  /// Appui sur un paquet : révision s'il y a quelque chose à voir, sinon la
  /// liste de ses cartes.
  void _openDeck(BuildContext context, DeckStats stats) {
    if (store.today(stats.counts).total > 0) {
      _review(context, DeckCards(stats.deck));
    } else {
      _push(context, DeckScreen(store: store, deck: stats.deck));
    }
  }

  Future<void> _addMenu(BuildContext context) async {
    final choice = await showActionSheet<String>(
      context,
      actions: const [
        SheetAction('card', 'Écrire des cartes', Icons.edit_outlined),
        SheetAction('deck', 'Nouveau paquet', Icons.style_outlined),
        SheetAction('import', 'Importer un fichier', Icons.file_open_outlined),
      ],
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case 'card':
        _push(context, CardEditorScreen(store: store));
      case 'deck':
        await _newDeck(context);
      case 'import':
        await importCardFiles(context, store);
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


/// Une ligne de l'arbre : flèche (dossiers), nom, puis les trois compteurs.
/// Chaque niveau est un peu plus décalé vers la droite.
class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.counts,
    required this.onTap,
    required this.onLongPress,
    required this.depth,
    this.folder = false,
    this.open = false,
  });

  final String title;
  final DueCounts counts;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final int depth;
  final bool folder;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.0 + depth * 18, 13, 20, 13),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: folder
                  ? Icon(
                      open ? Icons.expand_more : Icons.chevron_right,
                      size: 22,
                      color: scheme.onSurfaceVariant,
                    )
                  : null,
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: folder && depth == 0 ? 17 : 16,
                  fontWeight: folder ? FontWeight.w700 : FontWeight.w400,
                  color: scheme.onSurface,
                ),
              ),
            ),
            CountsRow(counts),
          ],
        ),
      ),
    );
  }
}
