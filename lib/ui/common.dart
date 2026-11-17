import 'package:material_ui/material_ui.dart';

import '../domain/study_session.dart';
import 'theme.dart';

/// Petit message en bas de l'écran.
void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Message lisible pour une erreur attendue (nom déjà pris…) ou inattendue.
String errorMessage(Object error) {
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}

/// Demande une confirmation. Renvoie `true` si l'utilisateur accepte.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return confirmed == true;
}

// ------------------------------------------------------------ Menu d'actions

/// Une ligne d'un menu qui monte du bas de l'écran.
class SheetAction<T> {
  const SheetAction(this.value, this.label, this.icon, {this.danger = false});

  final T value;
  final String label;
  final IconData icon;

  /// Action destructrice (suppression) : affichée en rouge.
  final bool danger;
}

/// Menu qui monte du bas de l'écran (appui long sur un élément, bouton +).
/// Renvoie la valeur de l'action choisie, ou `null` si le menu est refermé.
Future<T?> showActionSheet<T>(
  BuildContext context, {
  String? title,
  required List<SheetAction<T>> actions,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null)
                ListTile(
                  title: Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium),
                ),
              for (final action in actions)
                ListTile(
                  leading: Icon(action.icon,
                      color: action.danger ? theme.colorScheme.error : null),
                  title: Text(
                    action.label,
                    style: action.danger
                        ? TextStyle(color: theme.colorScheme.error)
                        : null,
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(action.value),
                ),
            ],
          ),
        ),
      );
    },
  );
}

// ------------------------------------------------------------ Blocs visuels

/// Un bloc à bords arrondis, légèrement détaché du fond. Avec [onTap] ou
/// [onLongPress], tout le bloc réagit à l'appui.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = SizedBox(
      width: double.infinity,
      child: Padding(padding: padding, child: child),
    );
    return Material(
      color: scheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: onTap == null && onLongPress == null
          ? content
          : InkWell(onTap: onTap, onLongPress: onLongPress, child: content),
    );
  }
}

/// Petit titre gris au-dessus d'un bloc.
class Caption extends StatelessWidget {
  const Caption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// Les trois compteurs d'Anki : nouvelles (bleu), en apprentissage (rouge),
/// à réviser (vert). Un zéro est affiché en gris.
class CountsRow extends StatelessWidget {
  const CountsRow(
    this.counts, {
    super.key,
    this.highlight,
    this.fontSize = 15,
    this.columnWidth = 38,
  });

  final DueCounts counts;

  /// Catégorie de la carte affichée : son compteur est souligné.
  final CardKind? highlight;
  final double fontSize;
  final double columnWidth;

  @override
  Widget build(BuildContext context) {
    final signal = Signal.of(context);
    final muted = Theme.of(context).colorScheme.outlineVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final kind in CardKind.values)
          SizedBox(
            width: columnWidth,
            child: Text(
              '${counts.of(kind)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: counts.of(kind) == 0 ? muted : signal.kind(kind),
                decoration:
                    highlight == kind ? TextDecoration.underline : null,
                decorationColor: signal.kind(kind),
              ),
            ),
          ),
      ],
    );
  }
}

/// La légende des trois colonnes de compteurs.
class CountsLegend extends StatelessWidget {
  const CountsLegend({super.key, this.columnWidth = 38});

  final double columnWidth;

  static const _labels = {
    CardKind.fresh: 'Nouv.',
    CardKind.learning: 'Appr.',
    CardKind.review: 'Rév.',
  };

  @override
  Widget build(BuildContext context) {
    final signal = Signal.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final kind in CardKind.values)
          SizedBox(
            width: columnWidth,
            child: Text(
              _labels[kind]!,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, color: signal.kind(kind)),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------ Saisie courte

/// Un champ d'une fenêtre de saisie courte (un nom, un nombre).
class FieldSpec {
  const FieldSpec({
    required this.label,
    this.initial = '',
    this.number = false,
    this.hint,
    this.suggestions = const [],
  });

  final String label;
  final String initial;
  final bool number;
  final String? hint;

  /// Valeurs proposées sous le champ (un appui les recopie dedans).
  final List<String> suggestions;
}

/// Fenêtre avec un ou plusieurs champs courts. Renvoie les valeurs saisies,
/// ou `null` si elle est annulée.
///
/// [validate] reçoit les valeurs et renvoie un message d'erreur, ou `null`
/// si tout va bien. Par défaut, aucun champ ne doit être vide.
Future<List<String>?> showFieldsDialog(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  required String action,
  String? Function(List<String> values)? validate,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _FieldsDialog(
      title: title,
      fields: fields,
      action: action,
      validate: validate ?? _notEmpty,
    ),
  );
}

String? _notEmpty(List<String> values) =>
    values.any((value) => value.trim().isEmpty)
        ? 'Tous les champs doivent être remplis.'
        : null;

class _FieldsDialog extends StatefulWidget {
  const _FieldsDialog({
    required this.title,
    required this.fields,
    required this.action,
    required this.validate,
  });

  final String title;
  final List<FieldSpec> fields;
  final String action;
  final String? Function(List<String>) validate;

  @override
  State<_FieldsDialog> createState() => _FieldsDialogState();
}

class _FieldsDialogState extends State<_FieldsDialog> {
  late final List<TextEditingController> _controllers = [
    for (final field in widget.fields)
      TextEditingController(text: field.initial),
  ];
  String? _error;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final values = [for (final controller in _controllers) controller.text];
    final error = widget.validate(values);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, values);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < widget.fields.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              TextField(
                controller: _controllers[i],
                autofocus: i == 0,
                keyboardType: widget.fields[i].number
                    ? TextInputType.number
                    : TextInputType.text,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: widget.fields[i].label,
                  hintText: widget.fields[i].hint,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (widget.fields[i].suggestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final suggestion in widget.fields[i].suggestions)
                        ActionChip(
                          label: Text(suggestion),
                          onPressed: () =>
                              setState(() => _controllers[i].text = suggestion),
                        ),
                    ],
                  ),
                ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.action)),
      ],
    );
  }
}
