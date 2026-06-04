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
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static const _recurringDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'betta_alarm_recurring',
      'Betta Recurring',
      channelDescription: 'Recurring event reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    tz.Location? match;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (tz.TZDateTime.now(loc).timeZoneOffset.inMinutes == offsetMinutes) {
        match = loc;
        break;
      }
    }
    _location = match ?? tz.UTC;
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
  }

  static tz.Location get _loc {
    if (_location != null) return _location!;
    tz_data.initializeTimeZones();
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (tz.TZDateTime.now(loc).timeZoneOffset.inMinutes == offsetMinutes) {
        _location = loc;
        return loc;
      }
    }
    _location = tz.UTC;
    return tz.UTC;
  }

  static Future<void> scheduleForEvent(AppEvent event) async {
    await cancelForEvent(event);

    if (event.alertMode == EventAlertMode.none) return;

    final eventDt = event.dateTime;
    final idBase = _idBase(event);

    if (event.alertMode == EventAlertMode.alarm) {
      await _scheduleAlarmForEvent(event, idBase);
      return;
    }

    // notification mode
    if (event.autoAlarm) {
      final notifyAt = eventDt.subtract(const Duration(minutes: 15));
      if (notifyAt.isAfter(DateTime.now())) {
        await _scheduleOnce(
          id: idBase,
          title: event.name,
          body: 'in 15 min${event.place.isNotEmpty ? ' · ${event.place}' : ''}',
          scheduledDate: notifyAt,
          details: _notifDetails,
        );
      }
    }

    if (event.customAlarm) {
      for (int i = 0; i < event.customAlarmOffsets.length; i++) {
        final offset = event.customAlarmOffsets[i];
        final notifyAt = eventDt.subtract(Duration(minutes: offset));
        if (notifyAt.isAfter(DateTime.now())) {
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

    if (event.autoAlarm) {
      final ringAt = eventDt.subtract(const Duration(minutes: 15));
      if (ringAt.isAfter(DateTime.now())) {
        await alarm_pkg.Alarm.set(
          alarmSettings: _buildAlarmSettings(
            id: idBase,
            title: event.name,
            body:
                'in 15 min${event.place.isNotEmpty ? ' · ${event.place}' : ''}',
            wakeAt: ringAt,
          ),
        );
      }
    }

    if (event.customAlarm) {
      for (int i = 0; i < event.customAlarmOffsets.length; i++) {
        final offset = event.customAlarmOffsets[i];
        final ringAt = eventDt.subtract(Duration(minutes: offset));
        if (ringAt.isAfter(DateTime.now())) {
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
      assetAudioPath: 'assets/alarm.mp3',
      loopAudio: true,
      vibrate: true,
      warningNotificationOnKill: true,
      androidFullScreenIntent: true,
      notificationSettings: alarm_pkg.NotificationSettings(
        title: title,
        body: body,
        stopButton: 'stop',
      ),
      volumeSettings: alarm_pkg.VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 10),
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

  static int _idBase(AppEvent event) =>
      (event.name.hashCode ^ event.dateTime.millisecondsSinceEpoch).abs() %
      0x7FFFF;
}
