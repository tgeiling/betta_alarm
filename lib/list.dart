import 'package:flutter/material.dart';
import 'main.dart';
import 'event_detail.dart';
import 'add_event.dart';
import 'storage.dart';
import 'sleep.dart';
import 'notification.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  List<AppEvent> _events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final events = await StorageService.loadEvents();
    setState(() => _events = events);
  }

  Future<void> _addEvent(AppEvent event) async {
    final updated = [..._events, event];
    await StorageService.saveEvents(updated);
    setState(() => _events = updated);
    await NotificationService.scheduleForEvent(event);
    await _checkSleepConflict(event);
  }

  Future<void> _checkSleepConflict(AppEvent newEvent) async {
    final all = await StorageService.loadEvents();

    // Check if new event conflicts with any scheduled wake-up (sleep gap < 9h)
    // Find the latest event on the day before newEvent
    final dayBefore = DateTime(
      newEvent.dateTime.year,
      newEvent.dateTime.month,
      newEvent.dateTime.day - 1,
    );
    final prevDayEvents =
        all
            .where(
              (e) =>
                  e.dateTime.year == dayBefore.year &&
                  e.dateTime.month == dayBefore.month &&
                  e.dateTime.day == dayBefore.day,
            )
            .toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (prevDayEvents.isEmpty) return;

    final lastPrevEvent = prevDayEvents.last;
    final gapHours =
        newEvent.dateTime.difference(lastPrevEvent.dateTime).inMinutes / 60.0;
    final bool isAway =
        newEvent.place.toLowerCase().trim() != 'at home' &&
        newEvent.place.isNotEmpty;
    final double requiredSleep = isAway ? 9.0 + 1.5 : 9.0;

    if (gapHours < requiredSleep) {
      if (!mounted) return;
      final actualSleep = gapHours - (isAway ? 1.5 : 0);
      final warning = SleepWarning(
        type: isAway
            ? SleepWarningType.awayEvent
            : SleepWarningType.sleepConflict,
        conflictEvent: newEvent,
        actualSleepHours: actualSleep,
      );
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF143508),
          title: Text(
            isAway ? '⚠ away event — short sleep' : '⚠ short sleep',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'PixelifySans',
              fontSize: 13,
            ),
          ),
          content: Text(
            warning.message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontFamily: 'PixelifySans',
              fontSize: 12,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'ok',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'PixelifySans',
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Map<String, List<AppEvent>> _groupByDay() {
    final now = DateTime.now();
    final Map<String, List<AppEvent>> grouped = {};
    for (final e in _events) {
      if (e.dateTime.isBefore(now)) continue;
      final key = '${e.dateTime.year}-${e.dateTime.month}-${e.dateTime.day}';
      grouped.putIfAbsent(key, () => []).add(e);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    }
    return grouped;
  }

  String _dayLabel(String key) {
    final parts = key.split('-');
    final date = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    if (date.day == today.day && date.month == today.month) return 'today';
    if (date.day == tomorrow.day && date.month == tomorrow.month)
      return 'tomorrow';
    final months = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDay();
    final sortedKeys = grouped.keys.toList()..sort();

    return Scaffold(
      backgroundColor: AppColors.green,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'upcoming',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push<AppEvent>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddEventScreen(),
                        ),
                      );
                      if (result != null) await _addEvent(result);
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      color: Colors.white,
                      child: const Center(
                        child: Text(
                          '+',
                          style: TextStyle(
                            color: AppColors.green,
                            fontSize: 30,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _events.isEmpty
                  ? Center(
                      child: Text(
                        'no events',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.25),
                          fontSize: 16,
                          fontFamily: 'PixelifySans',
                        ),
                      ),
                    )
                  : ListView(
                      children: sortedKeys.map((key) {
                        final evs = grouped[key]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 3),
                              child: Text(
                                _dayLabel(key),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 20,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            ...evs.map(
                              (e) => GestureDetector(
                                onTap: () async {
                                  await Navigator.push<AppEvent?>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          EventDetailScreen(event: e),
                                    ),
                                  );
                                  await _loadEvents();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.white.withOpacity(0.1),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        width: 64,
                                        child: Text(
                                          _fmtTime(e.dateTime),
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.35,
                                            ),
                                            fontSize: 21,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          e.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 23,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        e.place,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.3),
                                          fontSize: 21,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
