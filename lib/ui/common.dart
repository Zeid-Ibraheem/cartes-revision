import 'package:material_ui/material_ui.dart';

/// Petit message en bas de l'écran.
void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
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

/// Un champ d'une fenêtre de saisie.
class FieldSpec {
  const FieldSpec({
    required this.label,
    this.initial = '',
    this.multiline = false,
    this.number = false,
    this.hint,
    this.suggestions = const [],
  });

  final String label;
  final String initial;
  final bool multiline;
  final bool number;
  final String? hint;

  /// Valeurs proposées sous le champ (un appui les recopie dedans).
  final List<String> suggestions;
}

/// Réponse d'une fenêtre de saisie.
class FieldsResult {
  const FieldsResult.saved(this.values) : deleted = false;
  const FieldsResult.deleted()
      : values = const [],
        deleted = true;

  final List<String> values;

  /// L'utilisateur a choisi le bouton de suppression.
  final bool deleted;
}

/// Fenêtre avec un ou plusieurs champs de texte. Renvoie `null` si annulée.
///
/// [validate] reçoit les valeurs et renvoie un message d'erreur, ou `null`
/// si tout va bien. Par défaut, aucun champ ne doit être vide.
/// [deleteLabel] ajoute un bouton de suppression (pour corriger une carte).
Future<FieldsResult?> showFieldsDialog(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  required String action,
  String? Function(List<String> values)? validate,
  String? deleteLabel,
}) {
  return showDialog<FieldsResult>(
    context: context,
    builder: (_) => _FieldsDialog(
      title: title,
      fields: fields,
      action: action,
      validate: validate ?? _notEmpty,
      deleteLabel: deleteLabel,
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
    required this.deleteLabel,
  });

  final String title;
  final List<FieldSpec> fields;
  final String action;
  final String? Function(List<String>) validate;
  final String? deleteLabel;

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
    Navigator.pop(context, FieldsResult.saved(values));
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
                minLines: widget.fields[i].multiline ? 2 : 1,
                maxLines: widget.fields[i].multiline ? 8 : 1,
                keyboardType: widget.fields[i].number
                    ? TextInputType.number
                    : (widget.fields[i].multiline
                        ? TextInputType.multiline
                        : TextInputType.text),
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: widget.fields[i].label,
                  hintText: widget.fields[i].hint,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: widget.fields[i].multiline ? null : (_) => _submit(),
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
        if (widget.deleteLabel != null)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const FieldsResult.deleted()),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(widget.deleteLabel!),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.action)),
      ],
    );
  }
}

/// Texte court pour les compteurs d'un paquet ou d'un dossier.
String countsLabel({required int due, required int fresh, required int total}) {
  final parts = <String>[
    if (due > 0) '$due à revoir',
    if (fresh > 0) '$fresh ${fresh > 1 ? 'nouvelles' : 'nouvelle'}',
    '$total ${total > 1 ? 'cartes' : 'carte'}',
  ];
  return parts.join(' · ');
}

/// Message lisible pour une erreur attendue (nom déjà pris…) ou inattendue.
String errorMessage(Object error) {
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}
