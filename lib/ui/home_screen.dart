import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import '../data/store.dart';
import '../domain/card_file.dart';
import 'common.dart';
import 'deck_screen.dart';
import 'review_screen.dart';
import 'settings_screen.dart';

/// Écran d'accueil : les dossiers, leurs paquets, et ce qu'il y a à réviser.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text(appName),
          actions: [
            IconButton(
              tooltip: 'Importer un fichier de cartes',
              icon: const Icon(Icons.file_open_outlined),
              onPressed: () => importCardFiles(context, store),
            ),
            IconButton(
              tooltip: 'Réglages',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(store: store),
              )),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _newDeck(context),
          icon: const Icon(Icons.add),
          label: const Text('Paquet'),
        ),
        body: store.isEmpty ? _EmptyState(store: store) : _DeckList(store: store),
      ),
    );
  }

  Future<void> _newDeck(BuildContext context) async {
    final result = await showFieldsDialog(
      context,
      title: 'Nouveau paquet',
      action: 'Créer',
      fields: [
        FieldSpec(
          label: 'Dossier',
          hint: 'ex. R3.07',
          suggestions: store.folderNames,
        ),
        const FieldSpec(label: 'Paquet', hint: 'ex. Contrôle 1'),
      ],
    );
    if (result == null || !context.mounted) return;
    try {
      final deck = await store.createDeck(result.values[0], result.values[1]);
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => DeckScreen(store: store, deck: deck),
      ));
    } catch (error) {
      if (context.mounted) showSnack(context, errorMessage(error));
    }
  }
}

/// Ouvre un sélecteur de fichiers, importe les cartes choisies et affiche le
/// bilan.
Future<void> importCardFiles(BuildContext context, AppStore store) async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['txt', 'tsv'],
  );
  if (files.isEmpty || !context.mounted) return;

  final lines = <String>[];
  for (final file in files) {
    try {
      final bytes = <int>[];
      await for (final chunk in file.readAsByteStream()) {
        bytes.addAll(chunk);
      }
      final report = await store.importBytes(bytes, file.name);
      lines.add(_reportText(file.name, report));
    } catch (error) {
      lines.add('${file.name} : échec de la lecture ($error)');
    }
  }
  try {
    await FilePicker.clearTemporaryFiles();
  } catch (_) {
    // Pas grave : Android vide aussi ce cache tout seul.
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Import'),
      content: SingleChildScrollView(child: Text(lines.join('\n\n'))),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

String _reportText(String fileName, ImportReport report) {
  final buffer = StringBuffer(fileName)
    ..write('\n${report.added} carte(s) ajoutée(s)')
    ..write(', ${report.updated} réponse(s) mise(s) à jour')
    ..write(', ${report.unchanged} déjà à jour');
  if (report.newDecks > 0) buffer.write('\n${report.newDecks} nouveau(x) paquet(s)');
  if (report.issues.isNotEmpty) {
    buffer.write('\n${report.issues.length} remarque(s) :');
    for (final issue in report.issues.take(10)) {
      buffer.write('\n· ligne ${issue.line} : ${issue.message}');
    }
    if (report.issues.length > 10) {
      buffer.write('\n· … et ${report.issues.length - 10} autre(s)');
    }
  }
  return buffer.toString();
}

void _openReview(BuildContext context, AppStore store, StudyScope scope) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => ReviewScreen(store: store, scope: scope),
  ));
}

class _DeckList extends StatelessWidget {
  const _DeckList({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = store.studyableToday(fresh: store.freshTotal, due: store.dueTotal);
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: FilledButton.icon(
            onPressed: today == 0
                ? null
                : () => _openReview(context, store, const AllCards()),
            icon: const Icon(Icons.play_arrow),
            label: Text(today == 0
                ? 'Rien à réviser pour l’instant'
                : 'Tout réviser ($today)'),
          ),
        ),
        if (store.freshTotal > 0 && store.newLeftToday == 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Limite de nouvelles cartes atteinte pour aujourd’hui '
              '(${store.settings.newPerDay}, modifiable dans les réglages).',
              style: theme.textTheme.bodySmall,
            ),
          ),
        for (final folder in store.folders) ...[
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(folder.name, style: theme.textTheme.titleMedium),
            subtitle: Text(countsLabel(
                due: folder.due, fresh: folder.fresh, total: folder.total)),
            trailing: IconButton(
              tooltip: 'Réviser le dossier',
              icon: const Icon(Icons.play_circle_outline),
              onPressed: store.studyableToday(fresh: folder.fresh, due: folder.due) == 0
                  ? null
                  : () => _openReview(context, store, FolderCards(folder.name)),
            ),
          ),
          for (final stats in folder.decks)
            ListTile(
              contentPadding: const EdgeInsets.only(left: 56, right: 16),
              title: Text(stats.deck.name),
              subtitle: Text(countsLabel(
                  due: stats.due, fresh: stats.fresh, total: stats.total)),
              trailing: IconButton(
                tooltip: 'Réviser le paquet',
                icon: const Icon(Icons.play_arrow),
                onPressed: store.studyableToday(fresh: stats.fresh, due: stats.due) == 0
                    ? null
                    : () => _openReview(context, store, DeckCards(stats.deck)),
              ),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => DeckScreen(store: store, deck: stats.deck),
              )),
            ),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.style_outlined, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Aucune carte pour l’instant', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Importe un fichier de cartes (une carte par ligne : la question, '
              'une tabulation, la réponse), ou crée un paquet avec le bouton +.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: () => importCardFiles(context, store),
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Importer un fichier'),
            ),
          ],
        ),
      ),
    );
  }
}
