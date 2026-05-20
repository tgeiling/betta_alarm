import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'main.dart';

class AlarmService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _alarmChannel = AndroidNotificationDetails(
    'betta_alarms',
    'Betta Alarms',
    channelDescription: 'Wake-up alarms',
    importance: Importance.max,
    priority: Priority.max,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.alarm,
    visibility: NotificationVisibility.public,
    playSound: true,
    enableVibration: true,
  );

  static const _alarmDetails = NotificationDetails(
    android: _alarmChannel,
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );

  static const int _napAlarmId = 900001;
  static const int _sleepAlarmId = 900002;

  static tz.Location get _loc {
    tz_data.initializeTimeZones();
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (tz.TZDateTime.now(loc).timeZoneOffset.inMinutes == offsetMinutes) {
        return loc;
      }
    }
    return tz.UTC;
  }

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime wakeAt,
  }) async {
    await _plugin.cancel(id: id);
    // Always schedule inexact first (never throws), then try to upgrade to exact
    Future<void> scheduleInexact() => _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(wakeAt, _loc),
      notificationDetails: _alarmDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(wakeAt, _loc),
        notificationDetails: _alarmDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      await scheduleInexact();
    }
  }

  static Future<void> scheduleNap(DateTime wakeAt) async {
    await _schedule(
      id: _napAlarmId,
      title: 'nap over',
      body: 'time to wake up',
      wakeAt: wakeAt,
    );
  }

  static Future<void> cancelNap() async {
    await _plugin.cancel(id: _napAlarmId);
  }

  static Future<void> scheduleSleepAlarm(
    DateTime wakeAt,
    String eventName,
  ) async {
    await _schedule(
      id: _sleepAlarmId,
      title: 'wake up',
      body: eventName.isNotEmpty ? 'next: $eventName' : 'good morning',
      wakeAt: wakeAt,
    );
  }

  static Future<void> cancelSleepAlarm() async {
    await _plugin.cancel(id: _sleepAlarmId);
  }
}
