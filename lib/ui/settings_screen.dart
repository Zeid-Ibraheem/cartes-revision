import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import '../data/store.dart';
import '../domain/settings.dart';
import 'common.dart';

/// Tous les réglages. Chaque changement est enregistré tout de suite.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.settings;
        return Scaffold(
          appBar: AppBar(title: const Text('Réglages')),
          body: ListView(
            children: [
              const _Section('Révisions'),
              ListTile(
                title: const Text('Nouvelles cartes par jour'),
                subtitle: Text('${s.newPerDay}, tous paquets confondus'),
                onTap: () => _editInt(
                  context,
                  title: 'Nouvelles cartes par jour',
                  value: s.newPerDay,
                  min: SettingLimits.minNewPerDay,
                  max: SettingLimits.maxNewPerDay,
                  apply: (value) => s.copyWith(newPerDay: value),
                ),
              ),
              ListTile(
                title: const Text('Mémorisation visée'),
                subtitle: Text(
                  '${(s.desiredRetention * 100).round()} % de chances de se '
                  'souvenir quand la carte revient. Plus haut = plus de révisions.',
                ),
              ),
              Slider(
                value: s.desiredRetention,
                min: SettingLimits.minRetention,
                max: SettingLimits.maxRetention,
                divisions: 27,
                label: '${(s.desiredRetention * 100).round()} %',
                onChanged: (value) => _save(
                    s.copyWith(desiredRetention: (value * 100).round() / 100)),
              ),
              ListTile(
                title: const Text('Étapes d’apprentissage'),
                subtitle: Text(_stepsLabel(s.learningStepsMinutes)),
                onTap: () => _editSteps(
                  context,
                  title: 'Étapes d’apprentissage (minutes)',
                  value: s.learningStepsMinutes,
                  apply: (steps) => s.copyWith(learningStepsMinutes: steps),
                ),
              ),
              ListTile(
                title: const Text('Étapes après un oubli'),
                subtitle: Text(_stepsLabel(s.relearningStepsMinutes)),
                onTap: () => _editSteps(
                  context,
                  title: 'Étapes après un oubli (minutes)',
                  value: s.relearningStepsMinutes,
                  apply: (steps) => s.copyWith(relearningStepsMinutes: steps),
                ),
              ),
              ListTile(
                title: const Text('Intervalle maximum'),
                subtitle: Text('${s.maximumIntervalDays} jours'),
                onTap: () => _editInt(
                  context,
                  title: 'Intervalle maximum (jours)',
                  value: s.maximumIntervalDays,
                  min: SettingLimits.minIntervalDays,
                  max: SettingLimits.maxIntervalDays,
                  apply: (value) => s.copyWith(maximumIntervalDays: value),
                ),
              ),
              SwitchListTile(
                title: const Text('Variation des intervalles'),
                subtitle: const Text(
                    'Décale un peu au hasard les cartes apprises le même jour, '
                    'pour qu’elles ne reviennent pas toutes ensemble.'),
                value: s.fuzz,
                onChanged: (value) => _save(s.copyWith(fuzz: value)),
              ),
              ListTile(
                title: const Text('Début de la journée'),
                subtitle: Text('${s.dayStartHour} h : avant, une révision '
                    'compte pour la veille'),
                onTap: () => _editInt(
                  context,
                  title: 'Heure de début de la journée (0 à 23)',
                  value: s.dayStartHour,
                  min: 0,
                  max: 23,
                  apply: (value) => s.copyWith(dayStartHour: value),
                ),
              ),
              const _Section('Séance'),
              SwitchListTile(
                title: const Text('Quatre boutons'),
                subtitle: Text(s.fourButtons
                    ? 'À revoir · Difficile · Correct · Facile'
                    : 'À revoir · Correct'),
                value: s.fourButtons,
                onChanged: (value) => _save(s.copyWith(fourButtons: value)),
              ),
              SwitchListTile(
                title: const Text('Délais sous les boutons'),
                subtitle: const Text('Dans combien de temps la carte revient'),
                value: s.showDelays,
                onChanged: (value) => _save(s.copyWith(showDelays: value)),
              ),
              SwitchListTile(
                title: const Text('Ordre aléatoire'),
                value: s.shuffle,
                onChanged: (value) => _save(s.copyWith(shuffle: value)),
              ),
              const _Section('Affichage'),
              ListTile(
                title: const Text('Taille du texte des cartes'),
                subtitle: Text('${(s.textScale * 100).round()} %'),
              ),
              Slider(
                value: s.textScale,
                min: SettingLimits.minTextScale,
                max: SettingLimits.maxTextScale,
                divisions: 12,
                label: '${(s.textScale * 100).round()} %',
                onChanged: (value) =>
                    _save(s.copyWith(textScale: (value * 10).round() / 10)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SegmentedButton<AppTheme>(
                  segments: const [
                    ButtonSegment(value: AppTheme.system, label: Text('Auto')),
                    ButtonSegment(value: AppTheme.light, label: Text('Clair')),
                    ButtonSegment(value: AppTheme.dark, label: Text('Sombre')),
                    ButtonSegment(value: AppTheme.black, label: Text('Noir')),
                  ],
                  selected: {s.theme},
                  onSelectionChanged: (value) =>
                      _save(s.copyWith(theme: value.first)),
                ),
              ),
              const _Section('À propos'),
              const ListTile(
                title: Text('$appName $appVersion'),
                subtitle: Text(
                    'Répétition espacée avec FSRS. Tout reste sur ce téléphone : '
                    'l’appli n’a pas accès à Internet.'),
              ),
              ListTile(
                title: const Text('Remettre les réglages par défaut'),
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
            ],
          ),
        );
      },
    );
  }

  Future<void> _save(AppSettings settings) => store.updateSettings(settings);

  static String _stepsLabel(List<int> steps) => steps.isEmpty
      ? 'aucune : la carte passe directement aux intervalles en jours'
      : '${formatSteps(steps)} (minutes)';

  Future<void> _editInt(
    BuildContext context, {
    required String title,
    required int value,
    required int min,
    required int max,
    required AppSettings Function(int value) apply,
  }) async {
    final result = await showFieldsDialog(
      context,
      title: title,
      action: 'Enregistrer',
      fields: [FieldSpec(label: 'Valeur ($min à $max)', initial: '$value', number: true)],
      validate: (values) {
        final parsed = int.tryParse(values.first.trim());
        if (parsed == null || parsed < min || parsed > max) {
          return 'Un nombre entier entre $min et $max.';
        }
        return null;
      },
    );
    if (result == null) return;
    await _save(apply(int.parse(result.values.first.trim())));
  }

  Future<void> _editSteps(
    BuildContext context, {
    required String title,
    required List<int> value,
    required AppSettings Function(List<int> steps) apply,
  }) async {
    final result = await showFieldsDialog(
      context,
      title: title,
      action: 'Enregistrer',
      fields: [
        FieldSpec(
          label: 'Étapes, séparées par des virgules',
          hint: 'ex. 1, 10',
          initial: formatSteps(value),
        ),
      ],
      validate: (values) => parseSteps(values.first) == null
          ? 'Des nombres entiers de 1 à ${SettingLimits.maxStepMinutes}, '
              '${SettingLimits.maxSteps} au maximum. Vide = aucune étape.'
          : null,
    );
    if (result == null) return;
    await _save(apply(parseSteps(result.values.first)!));
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
