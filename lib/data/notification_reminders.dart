import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../app_info.dart';
import '../domain/reminder_plan.dart';

/// Les rappels, affichés par le système Android (paquet
/// flutter_local_notifications). C'est le SEUL fichier qui connaît ce paquet.
///
/// Les notifications sont programmées dans le téléphone : elles s'affichent
/// même appli fermée, et après un redémarrage. Aucun accès à Internet.
class NotificationReminders implements ReminderService {
  NotificationReminders();

  static const _channelId = 'rappel_quotidien';
  static const _channelName = 'Rappel quotidien';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  void Function()? _onOpen;

  static const _settings = InitializationSettings(
    android: AndroidInitializationSettings('ic_notification'),
  );

  Future<AndroidFlutterLocalNotificationsPlugin?> _android() async {
    if (!_ready) {
      await _plugin.initialize(
        settings: _settings,
        // Appui sur un rappel pendant que l'appli tourne (même en arrière-plan).
        onDidReceiveNotificationResponse: (_) => _onOpen?.call(),
      );
      _ready = true;
    }
    return _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
  }

  @override
  Future<bool> start({required void Function() onOpen}) async {
    _onOpen = onOpen;
    await _android();
    // Appli fermée, puis lancée par un appui sur le rappel.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    final android = await _android();
    if (android == null) return false;
    return await android.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    await _android();
    await _plugin.cancelAll();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Une fois par jour, s’il y a des cartes à réviser',
      ),
    );
    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        id: reminder.id,
        // L'heure est déjà calculée dans le fuseau du téléphone : on transmet
        // l'instant exact, exprimé en UTC.
        scheduledDate: tz.TZDateTime.from(reminder.at.toUtc(), tz.UTC),
        notificationDetails: details,
        // À quelques minutes près : pas besoin de l'autorisation spéciale des
        // « alarmes exactes », et plus économe en batterie.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: '$appName : ${reminder.title}',
        body: reminder.body,
      );
    }
  }
}
