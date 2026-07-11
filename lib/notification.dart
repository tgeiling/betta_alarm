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
    print(
      '[NotificationService] init: timezone resolved to ${_location!.name}',
    );

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
    print('[NotificationService] init: plugin initialized');

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

    print('[NotificationService] init: permissions requested');
  }

  static tz.Location _resolveLocalTimezone() {
    return tz.getLocation('Europe/Berlin');
  }

  static tz.Location get _loc {
    if (_location != null) return _location!;
    _location = _resolveLocalTimezone();
    return _location!;
  }

  static Future<void> scheduleForEvent(AppEvent event) async {
    final idBase = _idBase(event);
    print('@[NotificationService] scheduleForEvent: "${event.name}"');
    print('@  alertMode=${event.alertMode}, idBase=$idBase');
    print('@  eventDateTime=${event.dateTime.toIso8601String()}');
    print('@  now=${DateTime.now().toIso8601String()}');
    print(
      '@  minutesUntilEvent=${event.dateTime.difference(DateTime.now()).inMinutes}',
    );

    await cancelForEvent(event);
    if (event.alertMode == EventAlertMode.none) {
      print('@  -> alertMode is none, skipping scheduling');
      return;
    }

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

    print(
      '@[NotificationService] _scheduleNotificationsForEvent: "${event.name}"',
    );
    print('@  eventDt=$eventDt, now=$now');
    print(
      '@  customAlarm=${event.customAlarm}, offsets=${event.customAlarm ? event.customAlarmOffsets : []}',
    );
    print(
      '@  recurring=${event.recurring}, days=${event.recurring ? event.recurringDays : []}',
    );

    if (eventDt.isAfter(now)) {
      print('@  -> scheduling main notification at $eventDt (id=$idBase)');
      await _scheduleOnce(
        id: idBase,
        title: event.name,
        body: event.place.isNotEmpty ? event.note : '',
        scheduledDate: eventDt,
        details: _notifDetails,
      );
    } else {
      print(
        '@  -> SKIPPED main notification: eventDt ($eventDt) is NOT after now ($now)',
      );
    }

    if (event.customAlarm) {
      for (int i = 0; i < event.customAlarmOffsets.length; i++) {
        final offset = event.customAlarmOffsets[i];
        final notifyAt = eventDt.subtract(Duration(minutes: offset));
        if (notifyAt.isAfter(now)) {
          print(
            '@  -> scheduling offset notification: -${offset}min at $notifyAt (id=${idBase + 1 + i})',
          );
          await _scheduleOnce(
            id: idBase + 1 + i,
            title: event.name,
            body: '${AlarmOffset.label(offset)} before',
            scheduledDate: notifyAt,
            details: _notifDetails,
          );
        } else {
          print(
            '@  -> SKIPPED offset notification: -${offset}min notifyAt ($notifyAt) is NOT after now ($now)',
          );
        }
      }
    }

    if (event.recurring && event.recurringDays.isNotEmpty) {
      for (final day in event.recurringDays) {
        print(
          '@  -> scheduling weekly recurring on weekday=$day at ${eventDt.hour}:${eventDt.minute} (id=${idBase + 100 + day})',
        );
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

    print('@[NotificationService] _scheduleAlarmForEvent: "${event.name}"');
    print('@  eventDt=$eventDt, now=$now');
    print(
      '@  customAlarm=${event.customAlarm}, offsets=${event.customAlarm ? event.customAlarmOffsets : []}',
    );

    if (eventDt.isAfter(now)) {
      print('@  -> setting alarm at $eventDt (id=$idBase)');
      await alarm_pkg.Alarm.set(
        alarmSettings: _buildAlarmSettings(
          id: idBase,
          title: event.name,
          body: event.place.isNotEmpty ? event.note : '',
          wakeAt: eventDt,
        ),
      );
    } else {
      print(
        '@  -> SKIPPED main alarm: eventDt ($eventDt) is NOT after now ($now)',
      );
    }

    if (event.customAlarm) {
      for (int i = 0; i < event.customAlarmOffsets.length; i++) {
        final offset = event.customAlarmOffsets[i];
        final ringAt = eventDt.subtract(Duration(minutes: offset));
        if (ringAt.isAfter(now)) {
          print(
            '@  -> setting offset alarm: -${offset}min at $ringAt (id=${idBase + 1 + i})',
          );
          await alarm_pkg.Alarm.set(
            alarmSettings: _buildAlarmSettings(
              id: idBase + 1 + i,
              title: event.name,
              body: '${AlarmOffset.label(offset)} before',
              wakeAt: ringAt,
            ),
          );
        } else {
          print(
            '@  -> SKIPPED offset alarm: -${offset}min ringAt ($ringAt) is NOT after now ($now)',
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
    print(
      '@[NotificationService] cancelForEvent: "${event.name}" (idBase=$idBase)',
    );
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
    print('@[NotificationService] _scheduleOnce: id=$id, title="$title"');
    print(
      '@  scheduledDate=$scheduledDate -> tzDate=$tzDate (tz=${_loc.name})',
    );
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      print('@  -> zonedSchedule SUCCESS (exact)');
    } catch (e) {
      print('@  -> zonedSchedule FAILED (exact): $e — retrying with inexact');
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      print('@  -> zonedSchedule SUCCESS (inexact)');
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
    print(
      '@[NotificationService] _scheduleWeekly: id=$id, weekday=$weekday, time=$hour:$minute',
    );
    print('@  first occurrence scheduled for: $scheduled');
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
      print('@  -> weekly zonedSchedule SUCCESS (exact)');
    } catch (e) {
      print(
        '@  -> weekly zonedSchedule FAILED (exact): $e — retrying with inexact',
      );
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: _recurringDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
      print('@  -> weekly zonedSchedule SUCCESS (inexact)');
    }
  }

  static int _idBase(AppEvent event) {
    final nameHash = event.name.hashCode.abs() % 0xFFFF;
    final timeHash = (event.dateTime.millisecondsSinceEpoch ~/ 60000) % 0xFFFF;
    final id = (nameHash ^ timeHash) % 0xFFFF;
    print(
      '@[NotificationService] _idBase: name="${event.name}", nameHash=$nameHash, timeHash=$timeHash -> idBase=$id',
    );
    return id;
  }
}
