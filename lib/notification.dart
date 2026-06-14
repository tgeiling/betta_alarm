import 'dart:io';
import 'package:alarm/alarm.dart' as alarm_pkg;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'main.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static tz.Location? _location;

  static const _notifDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'betta_alarm',
      'Betta Alarm',
      channelDescription: 'Event reminders',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static const _recurringDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'betta_alarm_recurring',
      'Betta Recurring',
      channelDescription: 'Recurring event reminders',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    _location = _resolveLocalTimezone();
    tz.setLocalLocation(_location!);

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();
  }

  static tz.Location _resolveLocalTimezone() {
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (tz.TZDateTime.now(loc).timeZoneOffset.inMinutes == offsetMinutes) {
        return loc;
      }
    }
    return tz.UTC;
  }

  static tz.Location get _loc {
    if (_location != null) return _location!;
    _location = _resolveLocalTimezone();
    return _location!;
  }

  static Future<void> scheduleForEvent(AppEvent event) async {
    await cancelForEvent(event);
    if (event.alertMode == EventAlertMode.none) return;

    final idBase = _idBase(event);

    if (event.alertMode == EventAlertMode.alarm) {
      await _scheduleAlarmForEvent(event, idBase);
    } else {
      await _scheduleNotificationsForEvent(event, idBase);
    }
  }

  static Future<void> _scheduleNotificationsForEvent(
    AppEvent event,
    int idBase,
  ) async {
    final eventDt = event.dateTime;
    final now = DateTime.now();

    // Always fire at the event time (slot idBase)
    if (eventDt.isAfter(now)) {
      await _scheduleOnce(
        id: idBase,
        title: event.name,
        body: event.place.isNotEmpty ? event.place : 'now',
        scheduledDate: eventDt,
        details: _notifDetails,
      );
    }

    // Custom offsets (slots idBase+1 … idBase+6)
    if (event.customAlarm) {
      for (int i = 0; i < event.customAlarmOffsets.length; i++) {
        final offset = event.customAlarmOffsets[i];
        final notifyAt = eventDt.subtract(Duration(minutes: offset));
        if (notifyAt.isAfter(now)) {
          await _scheduleOnce(
            id: idBase + 1 + i,
            title: event.name,
            body: '${AlarmOffset.label(offset)} before',
            scheduledDate: notifyAt,
            details: _notifDetails,
          );
        }
      }
    }

    // Recurring weekly (slots idBase+100+weekday)
    if (event.recurring && event.recurringDays.isNotEmpty) {
      for (final day in event.recurringDays) {
        await _scheduleWeekly(
          id: idBase + 100 + day,
          title: event.name,
          body: event.place.isNotEmpty ? event.place : 'recurring',
          weekday: day,
          hour: eventDt.hour,
          minute: eventDt.minute,
        );
      }
    }
  }

  static Future<void> _scheduleAlarmForEvent(AppEvent event, int idBase) async {
    final eventDt = event.dateTime;
    final now = DateTime.now();

    // Always fire at the event time (slot idBase)
    if (eventDt.isAfter(now)) {
      await alarm_pkg.Alarm.set(
        alarmSettings: _buildAlarmSettings(
          id: idBase,
          title: event.name,
          body: event.place.isNotEmpty ? event.place : 'now',
          wakeAt: eventDt,
        ),
      );
    }

    // Custom offsets (slots idBase+1 … idBase+6)
    if (event.customAlarm) {
      for (int i = 0; i < event.customAlarmOffsets.length; i++) {
        final offset = event.customAlarmOffsets[i];
        final ringAt = eventDt.subtract(Duration(minutes: offset));
        if (ringAt.isAfter(now)) {
          await alarm_pkg.Alarm.set(
            alarmSettings: _buildAlarmSettings(
              id: idBase + 1 + i,
              title: event.name,
              body: '${AlarmOffset.label(offset)} before',
              wakeAt: ringAt,
            ),
          );
        }
      }
    }
  }

  static alarm_pkg.AlarmSettings _buildAlarmSettings({
    required int id,
    required String title,
    required String body,
    required DateTime wakeAt,
  }) {
    return alarm_pkg.AlarmSettings(
      id: id,
      dateTime: wakeAt,
      assetAudioPath: 'assets/indian_alarm.mp3',
      loopAudio: true,
      vibrate: true,
      warningNotificationOnKill: Platform.isIOS,
      androidFullScreenIntent: true,
      notificationSettings: alarm_pkg.NotificationSettings(
        title: title,
        body: body,
        stopButton: 'stop',
      ),
      volumeSettings: alarm_pkg.VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 10),
        volumeEnforced: true,
      ),
    );
  }

  static Future<void> cancelForEvent(AppEvent event) async {
    final idBase = _idBase(event);
    await _plugin.cancel(id: idBase);
    for (int i = 1; i <= 6; i++) {
      await _plugin.cancel(id: idBase + i);
    }
    for (int day = 1; day <= 7; day++) {
      await _plugin.cancel(id: idBase + 100 + day);
    }
    await alarm_pkg.Alarm.stop(idBase);
    for (int i = 1; i <= 6; i++) {
      await alarm_pkg.Alarm.stop(idBase + i);
    }
  }

  static Future<void> _scheduleOnce({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required NotificationDetails details,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledDate, _loc);
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  static Future<void> _scheduleWeekly({
    required int id,
    required String title,
    required String body,
    required int weekday,
    required int hour,
    required int minute,
  }) async {
    final loc = _loc;
    final now = tz.TZDateTime.now(loc);
    var scheduled = tz.TZDateTime(
      loc,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: _recurringDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: _recurringDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  static int _idBase(AppEvent event) {
    final nameHash = event.name.hashCode.abs() % 0xFFFF;
    final timeHash = (event.dateTime.millisecondsSinceEpoch ~/ 60000) % 0xFFFF;
    // Keep idBase small enough that idBase + 107 stays within int32
    // Max idBase = 0xFFFF = 65535; 65535 + 107 = 65642, well within range
    return (nameHash ^ timeHash) % 0xFFFF;
  }
}
