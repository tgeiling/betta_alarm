import 'main.dart';
import 'storage.dart';
import 'alarm.dart';
import 'notification.dart';

const double _defaultSleepHours = 9.0;
const double _awayTravelBufferHours = 1.5;
const String _homePlace = 'at home';

class SleepResult {
  final DateTime wakeAt;
  final AppEvent wakeEvent;
  final SleepWarning? warning;

  const SleepResult({
    required this.wakeAt,
    required this.wakeEvent,
    this.warning,
  });
}

enum SleepWarningType {
  sleepConflict, // next day first event too soon (< 9h gap)
  awayEvent, // first event of next day is not at home, need 1.5h buffer
}

class SleepWarning {
  final SleepWarningType type;
  final AppEvent? conflictEvent;
  final double actualSleepHours;

  const SleepWarning({
    required this.type,
    this.conflictEvent,
    this.actualSleepHours = _defaultSleepHours,
  });

  String get message {
    switch (type) {
      case SleepWarningType.sleepConflict:
        final h = actualSleepHours.toStringAsFixed(1);
        return 'only ${h}h sleep before "${conflictEvent?.name ?? 'next event'}". edit?';
      case SleepWarningType.awayEvent:
        final h = actualSleepHours.toStringAsFixed(1);
        return '"${conflictEvent?.name ?? 'next event'}" is not at home. waking 1.5h early — only ${h}h sleep. edit?';
    }
  }
}

class SleepService {
  /// Calculates wake time, creates a wake event, schedules alarm.
  /// Returns a [SleepResult] with optional warning for the UI to display.
  static Future<SleepResult> scheduleSleep(DateTime sleepAt) async {
    final all = await StorageService.loadEvents();
    final now = DateTime.now();

    // Find last event of today (same calendar day as sleepAt)
    final todayEvents = all.where(
      (e) =>
          e.dateTime.year == sleepAt.year &&
          e.dateTime.month == sleepAt.month &&
          e.dateTime.day == sleepAt.day &&
          e.dateTime.isAfter(now),
    );

    DateTime lastEventEnd = sleepAt;
    if (todayEvents.isNotEmpty) {
      final sorted = todayEvents.toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      lastEventEnd = sorted.last.dateTime;
    }

    // Default wake = lastEventEnd + 9h
    DateTime wakeAt = lastEventEnd.add(
      Duration(hours: _defaultSleepHours.toInt()),
    );

    // Find first event of next day
    final nextDayStart = DateTime(
      lastEventEnd.year,
      lastEventEnd.month,
      lastEventEnd.day + 1,
    );
    final nextDayEvents =
        all
            .where(
              (e) =>
                  e.dateTime.isAfter(lastEventEnd) &&
                  e.dateTime.isBefore(
                    nextDayStart.add(const Duration(days: 1)),
                  ),
            )
            .toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    SleepWarning? warning;

    if (nextDayEvents.isNotEmpty) {
      final firstNext = nextDayEvents.first;
      final bool isAwayEvent =
          firstNext.place.toLowerCase().trim() != _homePlace &&
          firstNext.place.isNotEmpty;

      if (isAwayEvent) {
        // Need to wake 1.5h before the event
        final requiredWake = firstNext.dateTime.subtract(
          Duration(minutes: (_awayTravelBufferHours * 60).toInt()),
        );
        final actualSleep =
            requiredWake.difference(lastEventEnd).inMinutes / 60.0;
        wakeAt = requiredWake;
        warning = SleepWarning(
          type: SleepWarningType.awayEvent,
          conflictEvent: firstNext,
          actualSleepHours: actualSleep,
        );
      } else {
        // Check if gap < 9h
        final gapHours =
            firstNext.dateTime.difference(lastEventEnd).inMinutes / 60.0;
        if (gapHours < _defaultSleepHours) {
          // Wake up just before the first next event (no buffer needed — it's at home)
          wakeAt = firstNext.dateTime;
          warning = SleepWarning(
            type: SleepWarningType.sleepConflict,
            conflictEvent: firstNext,
            actualSleepHours: gapHours,
          );
        }
      }
    }

    // Create wake event
    final wakeEvent = AppEvent(
      name: 'wake up',
      place: _homePlace,
      note: 'scheduled by sleep mode',
      dateTime: wakeAt,
      autoAlarm: true,
    );

    // Save wake event
    final updated = [...all, wakeEvent];
    await StorageService.saveEvents(updated);

    // Schedule alarm
    final nextEventName = nextDayEvents.isNotEmpty
        ? nextDayEvents.first.name
        : '';
    await AlarmService.scheduleSleepAlarm(wakeAt, nextEventName);
    await NotificationService.scheduleForEvent(wakeEvent);

    return SleepResult(wakeAt: wakeAt, wakeEvent: wakeEvent, warning: warning);
  }
}
