import 'package:cartes_revision/domain/reminder_plan.dart';
import 'package:cartes_revision/domain/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Lundi 16 nov. 2026, 12 h (heure du téléphone). Rappel à 19 h.
  final now = DateTime(2026, 11, 16, 12);
  const settings = AppSettings(newPerDay: 20, reminderMinutes: 19 * 60);

  List<PlannedReminder> plan({
    AppSettings s = settings,
    DateTime? at,
    List<DateTime> dueTimes = const [],
    int fresh = 0,
    int newLeftToday = 20,
  }) =>
      planReminders(
        settings: s,
        now: at ?? now,
        dueTimes: dueTimes,
        freshTotal: fresh,
        newLeftToday: newLeftToday,
      );

  test('rappel désactivé : rien de programmé', () {
    expect(
      plan(s: settings.copyWith(reminderEnabled: false), fresh: 50),
      isEmpty,
    );
  });

  test('rien à réviser : aucun rappel', () {
    expect(plan(), isEmpty);
  });

  test('un rappel par jour pendant 7 jours, à l’heure choisie', () {
    final reminders = plan(fresh: 100);
    expect(reminders, hasLength(reminderDaysAhead));
    expect(reminders.map((r) => r.id), [1, 2, 3, 4, 5, 6, 7]);
    for (var i = 0; i < reminders.length; i++) {
      final local = reminders[i].at.toLocal();
      expect(local, DateTime(2026, 11, 16 + i, 19));
      expect(reminders[i].at.isUtc, isTrue);
    }
  });

  test('heure du jour déjà passée : on commence demain', () {
    final reminders = plan(at: DateTime(2026, 11, 16, 20), fresh: 5);
    expect(reminders.first.at.toLocal(), DateTime(2026, 11, 17, 19));
    expect(reminders, hasLength(reminderDaysAhead - 1));
  });

  test('même compte que l’appli : toute la journée de révision', () {
    final reminders = plan(dueTimes: [
      DateTime(2026, 11, 16, 9).toUtc(), // déjà en retard
      DateTime(2026, 11, 16, 18).toUtc(), // avant 19 h aujourd'hui
      DateTime(2026, 11, 16, 21).toUtc(), // après 19 h, même journée
      DateTime(2026, 11, 17, 3).toUtc(), // 3 h : encore la journée de lundi
      DateTime(2026, 11, 17, 5).toUtc(), // 5 h : journée de mardi
      DateTime(2026, 11, 20, 10).toUtc(), // vendredi
    ]);
    expect(reminders.map((r) => r.title).take(5), [
      '4 cartes à réviser', // lundi
      '5 cartes à réviser', // mardi
      '5 cartes à réviser', // mercredi
      '5 cartes à réviser', // jeudi
      '6 cartes à réviser', // vendredi
    ]);
    expect(reminders.first.body, '4 à revoir');
  });

  test('nouvelles : reste du jour aujourd’hui, limite pleine ensuite', () {
    final reminders = plan(fresh: 100, newLeftToday: 3);
    expect(reminders[0].title, '3 cartes à réviser');
    expect(reminders[0].body, '3 nouvelles');
    expect(reminders[1].title, '20 cartes à réviser');
  });

  test('limite du jour atteinte et rien à revoir : pas de rappel ce soir', () {
    final reminders = plan(fresh: 100, newLeftToday: 0);
    expect(reminders.first.at.toLocal(), DateTime(2026, 11, 17, 19));
  });

  test('texte au singulier et détail combiné', () {
    expect(plan(fresh: 1).first.title, '1 carte à réviser');
    expect(plan(fresh: 1).first.body, '1 nouvelle');
    final mixed = plan(dueTimes: [DateTime(2026, 11, 16, 8).toUtc()], fresh: 2);
    expect(mixed.first.body, '1 à revoir · 2 nouvelles');
  });

  test('rappel à 2 h du matin (avant le début de journée à 4 h)', () {
    // À 2 h, la journée de révision est encore la veille : les nouvelles
    // restantes de la veille s'appliquent au rappel de la nuit qui suit.
    final s = settings.copyWith(reminderMinutes: 2 * 60);
    final reminders = plan(s: s, fresh: 100, newLeftToday: 4);
    expect(reminders.first.at.toLocal(), DateTime(2026, 11, 17, 2));
    expect(reminders.first.title, '4 cartes à réviser');
    expect(reminders[1].title, '20 cartes à réviser');
  });

  test('heure affichée', () {
    expect(formatTimeOfDay(19 * 60), '19:00');
    expect(formatTimeOfDay(7 * 60 + 5), '07:05');
    expect(formatTimeOfDay(0), '00:00');
  });
}
