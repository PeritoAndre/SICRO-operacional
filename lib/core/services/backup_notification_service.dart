import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/models/app_settings.dart';

class BackupNotificationService {
  BackupNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _notificationId = 430004;
  static const _payload = 'sicro_backup';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }
    await _configureTimezone();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  Future<void> requestPermission() async {
    if (!_initialized || kIsWeb) {
      return;
    }
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> reschedule(BackupSettings backup) async {
    if (!_initialized || kIsWeb) {
      return;
    }
    await _plugin.cancel(id: _notificationId);
    if (!backup.reminderEnabled) {
      return;
    }
    final scheduledAt = _nextReminderAt(backup, DateTime.now());
    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'Backup do SICRO',
      body:
          'Seu ultimo backup ja merece atencao. Gere um .sicrobackup e salve na sua nuvem.',
      scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'sicro_backup',
          'Backup do SICRO',
          channelDescription:
              'Lembretes mensais para gerar backup completo do SICRO Operacional',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: _payload,
    );
  }
}

DateTime _nextReminderAt(BackupSettings backup, DateTime now) {
  final preferredHour = backup.preferredHour.clamp(0, 23);
  final lastBackupAt = backup.lastBackupAt;
  if (lastBackupAt != null) {
    final due = lastBackupAt.add(Duration(days: backup.reminderIntervalDays));
    final dueAtPreferredHour = DateTime(
      due.year,
      due.month,
      due.day,
      preferredHour,
    );
    if (dueAtPreferredHour.isAfter(now)) {
      return dueAtPreferredHour;
    }
  }

  var next = DateTime(now.year, now.month, now.day, preferredHour);
  if (!next.isAfter(now)) {
    next = next.add(const Duration(days: 1));
  }
  return next;
}

Future<void> _configureTimezone() async {
  tz.initializeTimeZones();
  try {
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));
  } catch (_) {
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
  }
}
