/// Le rappel quotidien : quand prévenir, et avec quel message.
///
/// Les notifications programmées à l'avance ont un texte figé. On calcule donc
/// ici, pour les prochains jours, combien de cartes seront à revoir à l'heure
/// du rappel. Le plan est recalculé à chaque changement dans l'appli : tant
/// qu'on ne révise pas, la prévision est exacte.
library;

import 'settings.dart';
import 'study_session.dart';

/// Nombre de jours programmés d'avance : si l'appli n'est pas ouverte
/// pendant ce temps, les rappels s'arrêtent.
const reminderDaysAhead = 7;

/// Un rappel à afficher à un moment donné.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  /// Numéro du rappel, de 1 à [reminderDaysAhead].
  final int id;

  /// Moment du rappel (UTC).
  final DateTime at;
  final String title;
  final String body;

  @override
  String toString() => 'PlannedReminder($id, $at, $title, $body)';
}

/// Ce que la programmation des rappels doit savoir faire. Seule couche qui
/// touche aux notifications du téléphone : data/notification_reminders.dart.
abstract interface class ReminderService {
  /// Demande l'autorisation d'afficher des notifications (Android 13 et
  /// plus). Renvoie `false` si elle est refusée.
  Future<bool> requestPermission();

  /// Remplace tous les rappels programmés par [reminders] (vide = aucun).
  Future<void> replaceAll(List<PlannedReminder> reminders);
}

/// Les rappels des [reminderDaysAhead] prochains jours.
///
/// - [dueTimes] : échéance de chaque carte déjà révisée.
/// - [freshTotal] : nombre de cartes jamais révisées.
/// - [newLeftToday] : nouvelles encore permises aujourd'hui.
///
/// Un jour sans rien à revoir n'a pas de rappel. Un rappel dont l'heure est
/// déjà passée aujourd'hui n'est pas programmé.
List<PlannedReminder> planReminders({
  required AppSettings settings,
  required DateTime now,
  required List<DateTime> dueTimes,
  required int freshTotal,
  required int newLeftToday,
}) {
  if (!settings.reminderEnabled) return const [];
  final local = now.toLocal();
  final todayStart = studyDayStart(now, settings.dayStartHour);
  final hour = settings.reminderMinutes ~/ 60;
  final minute = settings.reminderMinutes % 60;
  final plan = <PlannedReminder>[];

  for (var day = 0; day < reminderDaysAhead; day++) {
    final at = DateTime(local.year, local.month, local.day + day, hour, minute);
    if (!at.isAfter(local)) continue;

    // Même règle que les compteurs de l'appli : une carte compte pour toute
    // sa journée de révision (jusqu'à 4 h le lendemain par défaut).
    final dayEnd = studyDayEnd(at, settings.dayStartHour);
    var due = 0;
    for (final time in dueTimes) {
      if (time.isBefore(dayEnd)) due++;
    }
    // Nouvelles : la limite du jour s'applique ; un autre jour de révision
    // que celui en cours repart avec la limite pleine.
    final sameStudyDay = studyDayStart(at, settings.dayStartHour) == todayStart;
    final allowed = sameStudyDay ? newLeftToday : settings.newPerDay;
    final fresh = freshTotal < allowed ? freshTotal : allowed;

    final total = due + (fresh < 0 ? 0 : fresh);
    if (total == 0) continue;
    plan.add(PlannedReminder(
      id: day + 1,
      at: at.toUtc(),
      title: total == 1 ? '1 carte à réviser' : '$total cartes à réviser',
      body: _details(due: due, fresh: fresh),
    ));
  }
  return plan;
}

String _details({required int due, required int fresh}) {
  final parts = <String>[
    if (due > 0) due == 1 ? '1 à revoir' : '$due à revoir',
    if (fresh > 0) fresh == 1 ? '1 nouvelle' : '$fresh nouvelles',
  ];
  return parts.join(' · ');
}

/// « 19:00 » pour 1140 minutes après minuit.
String formatTimeOfDay(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}
