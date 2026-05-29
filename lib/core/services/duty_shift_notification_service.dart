import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/models/duty_shift.dart';

class DutyShiftNotificationService {
  DutyShiftNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

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

  Future<void> rescheduleAll(List<DutyShift> shifts) async {
    if (!_initialized || kIsWeb) {
      return;
    }
    await _cancelDutyShiftReminders();
    final now = DateTime.now();
    for (final shift in shifts) {
      if (shift.endsAt.isBefore(now)) {
        continue;
      }
      if (shift.remindDayBefore) {
        await _scheduleReminder(
          shift: shift,
          idSuffix: 24,
          scheduledAt: shift.startsAt.subtract(const Duration(hours: 24)),
          title: 'Plantao amanha',
          body:
              '${shift.displayTitle} - inicio ${_dateTimeLabel(shift.startsAt)}',
        );
      }
      if (shift.remindTwoHoursBefore) {
        await _scheduleReminder(
          shift: shift,
          idSuffix: 2,
          scheduledAt: shift.startsAt.subtract(const Duration(hours: 2)),
          title: 'Plantao em 2 horas',
          body: '${shift.displayTitle} - inicio ${_timeLabel(shift.startsAt)}',
        );
      }
    }
  }

  Future<void> _scheduleReminder({
    required DutyShift shift,
    required int idSuffix,
    required DateTime scheduledAt,
    required String title,
    required String body,
  }) async {
    if (!scheduledAt.isAfter(DateTime.now())) {
      return;
    }
    await _plugin.zonedSchedule(
      id: _notificationId(shift.id, idSuffix),
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'duty_shifts',
          'Plantoes',
          channelDescription:
              'Lembretes de plantoes cadastrados no SICRO Operacional',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: shift.id,
    );
  }

  Future<void> _cancelDutyShiftReminders() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      final payload = request.payload ?? '';
      if (payload.startsWith('plantao_')) {
        await _plugin.cancel(id: request.id);
      }
    }
  }
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

int _notificationId(String id, int suffix) {
  var hash = suffix;
  for (final code in id.codeUnits) {
    hash = 0x1fffffff & (hash + code);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    hash ^= hash >> 6;
  }
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash ^= hash >> 11;
  hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  return max(1, hash);
}

String _dateTimeLabel(DateTime date) {
  return '${_two(date.day)}/${_two(date.month)} ${_two(date.hour)}:${_two(date.minute)}';
}

String _timeLabel(DateTime date) {
  return '${_two(date.hour)}:${_two(date.minute)}';
}

String _two(int value) => value.toString().padLeft(2, '0');
