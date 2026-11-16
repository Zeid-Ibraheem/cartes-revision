import 'package:cartes_revision/domain/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les réglages enregistrés se relisent à l’identique', () {
    const original = AppSettings(
      newPerDay: 35,
      desiredRetention: 0.85,
      learningStepsMinutes: [2, 15, 60],
      relearningStepsMinutes: [],
      maximumIntervalDays: 180,
      fuzz: false,
      dayStartHour: 3,
      fourButtons: false,
      showDelays: false,
      shuffle: false,
      textScale: 1.4,
      theme: AppTheme.black,
    );
    final read = AppSettings.fromMap(original.toMap());
    expect(read.newPerDay, 35);
    expect(read.desiredRetention, 0.85);
    expect(read.learningStepsMinutes, [2, 15, 60]);
    expect(read.relearningStepsMinutes, isEmpty);
    expect(read.maximumIntervalDays, 180);
    expect(read.fuzz, isFalse);
    expect(read.dayStartHour, 3);
    expect(read.fourButtons, isFalse);
    expect(read.showDelays, isFalse);
    expect(read.shuffle, isFalse);
    expect(read.textScale, 1.4);
    expect(read.theme, AppTheme.black);
  });

  test('valeur absente, illisible ou hors bornes : valeur par défaut', () {
    const defaults = AppSettings();
    final read = AppSettings.fromMap({
      'nouvelles_par_jour': 'beaucoup',
      'memorisation_visee': '1.5',
      'etapes_apprentissage': '0, 10',
      'intervalle_max_jours': '-3',
      'debut_journee_heure': '24',
      'theme': 'violet',
    });
    expect(read.newPerDay, defaults.newPerDay);
    expect(read.desiredRetention, defaults.desiredRetention);
    expect(read.learningStepsMinutes, defaults.learningStepsMinutes);
    expect(read.maximumIntervalDays, defaults.maximumIntervalDays);
    expect(read.dayStartHour, defaults.dayStartHour);
    expect(read.theme, defaults.theme);
  });

  test('première ouverture (rien d’enregistré) : valeurs par défaut', () {
    final read = AppSettings.fromMap(const {});
    expect(read.learningStepsMinutes, [1, 10]);
    expect(read.relearningStepsMinutes, [10]);
    expect(read.newPerDay, 20);
    expect(read.desiredRetention, 0.9);
  });

  test('lecture des étapes', () {
    expect(parseSteps('1, 10'), [1, 10]);
    expect(parseSteps(' 1 10;30 '), [1, 10, 30]);
    expect(parseSteps(''), isEmpty);
    expect(parseSteps('0'), isNull);
    expect(parseSteps('1, dix'), isNull);
    expect(parseSteps('1.5'), isNull);
    expect(parseSteps('1 2 3 4 5 6 7 8 9'), isNull);
    expect(formatSteps([1, 10]), '1, 10');
  });
}
