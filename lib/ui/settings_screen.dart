import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import '../data/store.dart';
import '../domain/reminder_plan.dart';
import '../domain/settings.dart';
import 'common.dart';

/// Tous les réglages, rangés par blocs. Chaque changement est enregistré tout
/// de suite.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.settings;
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(title: const Text('Réglages')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const Caption('Chaque jour'),
              _Group(children: [
                _Value(
                  title: 'Nouvelles cartes par jour',
                  value: '${s.newPerDay}',
                  onTap: () => _editInt(
                    context,
                    title: 'Nouvelles cartes par jour',
                    value: s.newPerDay,
                    min: SettingLimits.minNewPerDay,
                    max: SettingLimits.maxNewPerDay,
                    apply: (value) => s.copyWith(newPerDay: value),
                  ),
                ),
                _Value(
                  title: 'Début de la journée',
                  subtitle: 'Avant cette heure, une révision compte pour la veille',
                  value: '${s.dayStartHour} h',
                  onTap: () => _editInt(
                    context,
                    title: 'Heure de début de la journée',
                    value: s.dayStartHour,
                    min: 0,
                    max: 23,
                    apply: (value) => s.copyWith(dayStartHour: value),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              const Caption('Rappel'),
              _Group(children: [
                _Toggle(
                  title: 'Rappel quotidien',
                  subtitle: 'Une notification par jour, seulement s’il y a '
                      'des cartes à réviser',
                  value: s.reminderEnabled,
                  onChanged: (value) => _toggleReminder(context, value),
                ),
                if (s.reminderEnabled)
                  _Value(
                    title: 'Heure du rappel',
                    value: formatTimeOfDay(s.reminderMinutes),
                    onTap: () => _pickReminderTime(context, s.reminderMinutes),
                  ),
              ]),
              const SizedBox(height: 24),
              const Caption('Mémorisation'),
              _Group(children: [
                _SliderRow(
                  title: 'Mémorisation visée',
                  subtitle: 'Chances de se souvenir d’une carte quand elle '
                      'revient. Plus haut = moins d’oublis, plus de révisions.',
                  label: '${(s.desiredRetention * 100).round()} %',
                  value: s.desiredRetention,
                  min: SettingLimits.minRetention,
                  max: SettingLimits.maxRetention,
                  divisions: 27,
                  onChanged: (value) => _save(
                      s.copyWith(desiredRetention: (value * 100).round() / 100)),
                ),
                _Value(
                  title: 'Étapes d’apprentissage',
                  subtitle: 'Délais d’une carte nouvelle, en minutes',
                  value: _stepsLabel(s.learningStepsMinutes),
                  onTap: () => _editSteps(
                    context,
                    title: 'Étapes d’apprentissage (minutes)',
                    value: s.learningStepsMinutes,
                    apply: (steps) => s.copyWith(learningStepsMinutes: steps),
                  ),
                ),
                _Value(
                  title: 'Étapes après un oubli',
                  subtitle: 'Délais d’une carte oubliée, en minutes',
                  value: _stepsLabel(s.relearningStepsMinutes),
                  onTap: () => _editSteps(
                    context,
                    title: 'Étapes après un oubli (minutes)',
                    value: s.relearningStepsMinutes,
                    apply: (steps) => s.copyWith(relearningStepsMinutes: steps),
                  ),
                ),
                _Value(
                  title: 'Intervalle maximum',
                  value: '${s.maximumIntervalDays} j',
                  onTap: () => _editInt(
                    context,
                    title: 'Intervalle maximum (jours)',
                    value: s.maximumIntervalDays,
                    min: SettingLimits.minIntervalDays,
                    max: SettingLimits.maxIntervalDays,
                    apply: (value) => s.copyWith(maximumIntervalDays: value),
                  ),
                ),
                _Toggle(
                  title: 'Variation des intervalles',
                  subtitle: 'Évite que les cartes apprises le même jour '
                      'reviennent toutes ensemble',
                  value: s.fuzz,
                  onChanged: (value) => _save(s.copyWith(fuzz: value)),
                ),
              ]),
              const SizedBox(height: 24),
              const Caption('Séance'),
              _Group(children: [
                _Toggle(
                  title: 'Quatre boutons',
                  subtitle: s.fourButtons
                      ? 'À revoir · Difficile · Correct · Facile'
                      : 'À revoir · Correct',
                  value: s.fourButtons,
                  onChanged: (value) => _save(s.copyWith(fourButtons: value)),
                ),
                _Toggle(
                  title: 'Délais sous les boutons',
                  subtitle: 'Dans combien de temps la carte revient',
                  value: s.showDelays,
                  onChanged: (value) => _save(s.copyWith(showDelays: value)),
                ),
                _Toggle(
                  title: 'Ordre aléatoire',
                  value: s.shuffle,
                  onChanged: (value) => _save(s.copyWith(shuffle: value)),
                ),
              ]),
              const SizedBox(height: 24),
              const Caption('Affichage'),
              _Group(children: [
                _SliderRow(
                  title: 'Taille du texte des cartes',
                  label: '${(s.textScale * 100).round()} %',
                  value: s.textScale,
                  min: SettingLimits.minTextScale,
                  max: SettingLimits.maxTextScale,
                  divisions: 12,
                  onChanged: (value) =>
                      _save(s.copyWith(textScale: (value * 10).round() / 10)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: SegmentedButton<AppTheme>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: AppTheme.black, label: Text('Noir')),
                      ButtonSegment(value: AppTheme.dark, label: Text('Sombre')),
                      ButtonSegment(value: AppTheme.light, label: Text('Clair')),
                      ButtonSegment(value: AppTheme.system, label: Text('Auto')),
                    ],
                    selected: {s.theme},
                    onSelectionChanged: (value) =>
                        _save(s.copyWith(theme: value.first)),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              _Group(children: [
                _Value(
                  title: 'Remettre les réglages par défaut',
                  subtitle: 'Les cartes et leur historique ne changent pas',
                  value: '',
                  onTap: () async {
                    final sure = await confirmDialog(
                      context,
                      title: 'Réglages par défaut ?',
                      message: 'Les cartes et leur historique ne changent pas.',
                      action: 'Remettre',
                    );
                    if (sure) await _save(const AppSettings());
                  },
                ),
              ]),
              const SizedBox(height: 24),
              Text(
                '$appName $appVersion\nTout reste sur ce téléphone : l’appli '
                'n’a pas accès à Internet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save(AppSettings settings) => store.updateSettings(settings);

  Future<void> _toggleReminder(BuildContext context, bool enabled) async {
    await _save(store.settings.copyWith(reminderEnabled: enabled));
    if (!enabled) return;
    final allowed = await store.requestReminderPermission();
    if (!allowed && context.mounted) {
      showSnack(
        context,
        'Notifications bloquées : autorise-les dans les réglages Android, '
        'Applis › Cartes › Notifications.',
      );
    }
  }

  Future<void> _pickReminderTime(BuildContext context, int minutes) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: 'Heure du rappel',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    await _save(store.settings
        .copyWith(reminderMinutes: picked.hour * 60 + picked.minute));
  }

  static String _stepsLabel(List<int> steps) =>
      steps.isEmpty ? 'aucune' : formatSteps(steps);

  Future<void> _editInt(
    BuildContext context, {
    required String title,
    required int value,
    required int min,
    required int max,
    required AppSettings Function(int value) apply,
  }) async {
    final values = await showFieldsDialog(
      context,
      title: title,
      action: 'Enregistrer',
      fields: [
        FieldSpec(label: 'De $min à $max', initial: '$value', number: true),
      ],
      validate: (values) {
        final parsed = int.tryParse(values.first.trim());
        if (parsed == null || parsed < min || parsed > max) {
          return 'Un nombre entier entre $min et $max.';
        }
        return null;
      },
    );
    if (values == null) return;
    await _save(apply(int.parse(values.first.trim())));
  }

  Future<void> _editSteps(
    BuildContext context, {
    required String title,
    required List<int> value,
    required AppSettings Function(List<int> steps) apply,
  }) async {
    final values = await showFieldsDialog(
      context,
      title: title,
      action: 'Enregistrer',
      fields: [
        FieldSpec(
          label: 'Séparées par des virgules',
          hint: 'ex. 1, 10',
          initial: formatSteps(value),
        ),
      ],
      validate: (values) => parseSteps(values.first) == null
          ? 'Des nombres entiers de 1 à ${SettingLimits.maxStepMinutes}, '
              '${SettingLimits.maxSteps} au maximum. Vide = aucune étape.'
          : null,
    );
    if (values == null) return;
    await _save(apply(parseSteps(values.first)!));
  }
}

/// Un bloc de réglages, séparés par un trait fin.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Un réglage qui s'ouvre : son nom à gauche, sa valeur à droite.
class _Value extends StatelessWidget {
  const _Value({
    required this.title,
    required this.value,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: TextStyle(color: scheme.onSurfaceVariant)),
      trailing: Text(
        value,
        style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
      ),
      onTap: onTap,
    );
  }
}

/// Un réglage oui / non.
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: TextStyle(color: scheme.onSurfaceVariant)),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Un réglage à curseur, avec sa valeur affichée à droite du nom.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.title,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text(title),
          subtitle: subtitle == null
              ? null
              : Text(subtitle!,
                  style: TextStyle(color: scheme.onSurfaceVariant)),
          trailing: Text(
            label,
            style: TextStyle(fontSize: 15, color: scheme.onSurface),
          ),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
