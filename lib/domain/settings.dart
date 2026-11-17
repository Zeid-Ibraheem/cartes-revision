/// Les réglages de l'appli et leurs valeurs par défaut : le seul endroit où
/// elles sont écrites.
library;

enum AppTheme { system, light, dark, black }

/// Bornes acceptées pour chaque réglage (interface et lecture de la base).
class SettingLimits {
  SettingLimits._();

  static const minNewPerDay = 0;
  static const maxNewPerDay = 9999;
  static const minRetention = 0.70;
  static const maxRetention = 0.97;
  static const minIntervalDays = 1;
  static const maxIntervalDays = 36500;
  static const minTextScale = 0.8;
  static const maxTextScale = 2.0;
  static const maxStepMinutes = 14400; // 10 jours
  static const maxSteps = 8;
  static const maxReminderMinutes = 24 * 60 - 1;
}

class AppSettings {
  const AppSettings({
    this.newPerDay = 20,
    this.desiredRetention = 0.90,
    this.learningStepsMinutes = const [1, 10],
    this.relearningStepsMinutes = const [10],
    this.maximumIntervalDays = SettingLimits.maxIntervalDays,
    this.fuzz = true,
    this.dayStartHour = 4,
    this.fourButtons = true,
    this.showDelays = true,
    this.shuffle = true,
    this.textScale = 1.0,
    this.theme = AppTheme.black,
    this.reminderEnabled = true,
    this.reminderMinutes = 19 * 60,
  });

  /// Nombre maximum de cartes nouvelles montrées par jour, tous paquets
  /// confondus.
  final int newPerDay;

  /// Probabilité visée de se souvenir d'une carte au moment où elle revient
  /// (0,90 = 90 %). Plus haut : moins d'oublis, mais plus de révisions.
  final double desiredRetention;

  /// Étapes courtes d'une carte nouvelle, en minutes.
  final List<int> learningStepsMinutes;

  /// Étapes courtes d'une carte oubliée, en minutes.
  final List<int> relearningStepsMinutes;

  /// Une carte ne sera jamais repoussée de plus de ce nombre de jours.
  final int maximumIntervalDays;

  /// Petite variation aléatoire des intervalles, pour que des cartes apprises
  /// le même jour ne reviennent pas toutes le même jour.
  final bool fuzz;

  /// Heure à laquelle une nouvelle journée de révision commence (4 = 4 h du
  /// matin : réviser à 1 h compte encore pour la veille).
  final int dayStartHour;

  /// Quatre boutons (À revoir, Difficile, Correct, Facile) ou deux
  /// (À revoir, Correct).
  final bool fourButtons;

  /// Afficher sous chaque bouton dans combien de temps la carte reviendra.
  final bool showDelays;

  /// Mélanger les cartes d'une séance.
  final bool shuffle;

  /// Taille du texte des cartes (1,0 = normale).
  final double textScale;

  final AppTheme theme;

  /// Une notification par jour s'il y a des cartes à réviser.
  final bool reminderEnabled;

  /// Heure du rappel, en minutes après minuit (19 * 60 = 19 h 00).
  final int reminderMinutes;

  AppSettings copyWith({
    int? newPerDay,
    double? desiredRetention,
    List<int>? learningStepsMinutes,
    List<int>? relearningStepsMinutes,
    int? maximumIntervalDays,
    bool? fuzz,
    int? dayStartHour,
    bool? fourButtons,
    bool? showDelays,
    bool? shuffle,
    double? textScale,
    AppTheme? theme,
    bool? reminderEnabled,
    int? reminderMinutes,
  }) {
    return AppSettings(
      newPerDay: newPerDay ?? this.newPerDay,
      desiredRetention: desiredRetention ?? this.desiredRetention,
      learningStepsMinutes: learningStepsMinutes ?? this.learningStepsMinutes,
      relearningStepsMinutes:
          relearningStepsMinutes ?? this.relearningStepsMinutes,
      maximumIntervalDays: maximumIntervalDays ?? this.maximumIntervalDays,
      fuzz: fuzz ?? this.fuzz,
      dayStartHour: dayStartHour ?? this.dayStartHour,
      fourButtons: fourButtons ?? this.fourButtons,
      showDelays: showDelays ?? this.showDelays,
      shuffle: shuffle ?? this.shuffle,
      textScale: textScale ?? this.textScale,
      theme: theme ?? this.theme,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    );
  }

  // Clés enregistrées dans la base. Ne jamais renommer une clé existante :
  // le réglage déjà enregistré sur les téléphones serait perdu.
  static const _kNewPerDay = 'nouvelles_par_jour';
  static const _kRetention = 'memorisation_visee';
  static const _kLearningSteps = 'etapes_apprentissage';
  static const _kRelearningSteps = 'etapes_oubli';
  static const _kMaxInterval = 'intervalle_max_jours';
  static const _kFuzz = 'variation_intervalles';
  static const _kDayStart = 'debut_journee_heure';
  static const _kFourButtons = 'quatre_boutons';
  static const _kShowDelays = 'delais_affiches';
  static const _kShuffle = 'ordre_aleatoire';
  static const _kTextScale = 'taille_texte';
  static const _kTheme = 'theme';
  static const _kReminder = 'rappel_actif';
  static const _kReminderMinutes = 'rappel_heure_minutes';

  Map<String, String> toMap() {
    return {
      _kNewPerDay: '$newPerDay',
      _kRetention: '$desiredRetention',
      _kLearningSteps: formatSteps(learningStepsMinutes),
      _kRelearningSteps: formatSteps(relearningStepsMinutes),
      _kMaxInterval: '$maximumIntervalDays',
      _kFuzz: '$fuzz',
      _kDayStart: '$dayStartHour',
      _kFourButtons: '$fourButtons',
      _kShowDelays: '$showDelays',
      _kShuffle: '$shuffle',
      _kTextScale: '$textScale',
      _kTheme: theme.name,
      _kReminder: '$reminderEnabled',
      _kReminderMinutes: '$reminderMinutes',
    };
  }

  /// Relit des réglages enregistrés. Une valeur absente, illisible ou hors
  /// bornes est remplacée par la valeur par défaut : l'appli démarre toujours.
  factory AppSettings.fromMap(Map<String, String> map) {
    const d = AppSettings();
    return AppSettings(
      newPerDay: _int(map[_kNewPerDay], SettingLimits.minNewPerDay,
          SettingLimits.maxNewPerDay, d.newPerDay),
      desiredRetention: _double(map[_kRetention], SettingLimits.minRetention,
          SettingLimits.maxRetention, d.desiredRetention),
      learningStepsMinutes:
          _steps(map[_kLearningSteps], d.learningStepsMinutes),
      relearningStepsMinutes:
          _steps(map[_kRelearningSteps], d.relearningStepsMinutes),
      maximumIntervalDays: _int(map[_kMaxInterval],
          SettingLimits.minIntervalDays, SettingLimits.maxIntervalDays,
          d.maximumIntervalDays),
      fuzz: _bool(map[_kFuzz], d.fuzz),
      dayStartHour: _int(map[_kDayStart], 0, 23, d.dayStartHour),
      fourButtons: _bool(map[_kFourButtons], d.fourButtons),
      showDelays: _bool(map[_kShowDelays], d.showDelays),
      shuffle: _bool(map[_kShuffle], d.shuffle),
      textScale: _double(map[_kTextScale], SettingLimits.minTextScale,
          SettingLimits.maxTextScale, d.textScale),
      theme: _theme(map[_kTheme], d.theme),
      reminderEnabled: _bool(map[_kReminder], d.reminderEnabled),
      reminderMinutes: _int(map[_kReminderMinutes], 0,
          SettingLimits.maxReminderMinutes, d.reminderMinutes),
    );
  }

  static int _int(String? text, int min, int max, int fallback) {
    final value = int.tryParse(text ?? '');
    if (value == null || value < min || value > max) return fallback;
    return value;
  }

  static double _double(String? text, double min, double max, double fallback) {
    final value = double.tryParse(text ?? '');
    if (value == null || value.isNaN || value < min || value > max) {
      return fallback;
    }
    return value;
  }

  /// Réglage jamais enregistré ou illisible : valeur par défaut. Un texte
  /// vide enregistré exprès veut dire « aucune étape ».
  static List<int> _steps(String? text, List<int> fallback) {
    if (text == null) return fallback;
    return parseSteps(text) ?? fallback;
  }

  static bool _bool(String? text, bool fallback) {
    if (text == 'true') return true;
    if (text == 'false') return false;
    return fallback;
  }

  static AppTheme _theme(String? text, AppTheme fallback) {
    for (final theme in AppTheme.values) {
      if (theme.name == text) return theme;
    }
    return fallback;
  }
}

/// « 1, 10 » pour les étapes [1, 10]. Une liste vide donne un texte vide.
String formatSteps(List<int> minutes) => minutes.join(', ');

/// Lit des étapes écrites « 1, 10 » ou « 1 10 » (en minutes).
///
/// Un texte vide donne une liste vide : aucune étape courte, la carte passe
/// directement aux intervalles en jours. Renvoie `null` si le texte n'est pas
/// valable (autre chose que des nombres entiers de 1 à 14 400, ou plus de
/// 8 étapes).
List<int>? parseSteps(String text) {
  final parts =
      text.split(RegExp(r'[,;\s]+')).where((part) => part.isNotEmpty).toList();
  if (parts.length > SettingLimits.maxSteps) return null;
  final steps = <int>[];
  for (final part in parts) {
    final value = int.tryParse(part);
    if (value == null || value < 1 || value > SettingLimits.maxStepMinutes) {
      return null;
    }
    steps.add(value);
  }
  return steps;
}
