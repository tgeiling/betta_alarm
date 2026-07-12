import 'dart:io';
import 'package:alarm/alarm.dart';

class AlarmService {
  static const int _napAlarmId = 900001;
  static const int _sleepAlarmId = 900002;

  static AlarmSettings _buildSettings({
    required int id,
    required String title,
    required String body,
    required DateTime wakeAt,
  }) {
    return AlarmSettings(
      id: id,
      dateTime: wakeAt,
      assetAudioPath: 'assets/indian_alarm.mp3',
      loopAudio: false,
      vibrate: true,
      warningNotificationOnKill: Platform.isIOS,
      androidFullScreenIntent: true,
      notificationSettings: NotificationSettings(
        title: title,
        body: body,
        stopButton: 'stop',
      ),
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 10),
        volumeEnforced: true,
      ),
    );
  }

  static Future<void> scheduleNap(DateTime wakeAt) async {
    await Alarm.stop(_napAlarmId);
    await Alarm.set(
      alarmSettings: _buildSettings(
        id: _napAlarmId,
        title: 'nap over',
        body: 'time to wake up',
        wakeAt: wakeAt,
      ),
    );
  }

  static Future<void> cancelNap() async {
    await Alarm.stop(_napAlarmId);
  }

  static Future<void> scheduleSleepAlarm(
    DateTime wakeAt,
    String eventName,
  ) async {
    await Alarm.stop(_sleepAlarmId);
    await Alarm.set(
      alarmSettings: _buildSettings(
        id: _sleepAlarmId,
        title: 'wake up',
        body: eventName.isNotEmpty ? 'next: $eventName' : 'good morning',
        wakeAt: wakeAt,
      ),
    );
  }

  static Future<void> cancelSleepAlarm() async {
    await Alarm.stop(_sleepAlarmId);
  }
}
