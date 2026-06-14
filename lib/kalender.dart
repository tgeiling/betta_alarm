import 'package:alarm/alarm.dart' as alarm_pkg;
import 'package:flutter/material.dart';
import 'main.dart';
import 'event_detail.dart';
import 'notification.dart';
import 'storage.dart';

class KalenderScreen extends StatefulWidget {
  const KalenderScreen({super.key});

  @override
  State<KalenderScreen> createState() => _KalenderScreenState();
}

class _KalenderScreenState extends State<KalenderScreen> {
  DateTime _focused = DateTime.now();
  final DateTime _today = DateTime.now();
  DateTime? _selectedDay;
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

  void _prevMonth() =>
      setState(() => _focused = DateTime(_focused.year, _focused.month - 1));
  void _nextMonth() =>
      setState(() => _focused = DateTime(_focused.year, _focused.month + 1));

  bool _hasEvent(DateTime day) => _events.any(
    (e) =>
        e.dateTime.year == day.year &&
        e.dateTime.month == day.month &&
        e.dateTime.day == day.day,
  );

  List<AppEvent> _eventsForDay(DateTime day) =>
      (_events
          .where(
            (e) =>
                e.dateTime.year == day.year &&
                e.dateTime.month == day.month &&
                e.dateTime.day == day.day,
          )
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime)));

  AppEvent? _nextEvent() {
    final now = DateTime.now();
    final upcoming = _events.where((e) => e.dateTime.isAfter(now)).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  String _dayHeaderLabel(DateTime day) {
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final isTomorrow =
        day.year == now.year &&
        day.month == now.month &&
        day.day == now.day + 1;
    final weekdays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
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
    if (isToday) return 'today · ${day.day} ${months[day.month - 1]}';
    if (isTomorrow) return 'tomorrow · ${day.day} ${months[day.month - 1]}';
    return '${weekdays[day.weekday - 1]} · ${day.day} ${months[day.month - 1]} ${day.year}';
  }

  List<DateTime?> _buildCalendarDays() {
    final first = DateTime(_focused.year, _focused.month, 1);
    final last = DateTime(_focused.year, _focused.month + 1, 0);
    final startOffset = (first.weekday - 1) % 7;
    final List<DateTime?> days = [];
    for (int i = 0; i < startOffset; i++) {
      days.add(first.subtract(Duration(days: startOffset - i)));
    }
    for (int d = 1; d <= last.day; d++) {
      days.add(DateTime(_focused.year, _focused.month, d));
    }
    while (days.length % 7 != 0) days.add(null);
    return days;
  }

  String _monthName(int m) => [
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
  ][m - 1];

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _fmtDateLong(DateTime dt) {
    final days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
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
    return '${days[dt.weekday - 1]} ${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} · ${_fmtTime(dt)}';
  }

  void _onDayTap(DateTime day) {
    if (day.month != _focused.month) return;
    setState(() => _selectedDay = day);
  }

  void _showEventDialog(AppEvent e) {
    // Build alarm description
    final List<String> alarmLines = [];
    alarmLines.add('at event · ${_fmtTime(e.dateTime)}');
    if (e.customAlarm && e.customAlarmOffsets.isNotEmpty) {
      for (final offset in e.customAlarmOffsets) {
        final t = e.dateTime.subtract(Duration(minutes: offset));
        alarmLines.add(
          'custom · ${_fmtTime(t)} (${_offsetLabel(offset)} before)',
        );
      }
    }
    final alarmText = alarmLines.isEmpty ? 'none' : alarmLines.join('\n');

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.brown,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'PixelifySans',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _fmtDateLong(e.dateTime),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 11,
                  fontFamily: 'PixelifySans',
                ),
              ),
              const SizedBox(height: 14),
              if (e.place.isNotEmpty) _dialogRow(Icons.place_outlined, e.place),
              if (e.note.isNotEmpty) _dialogRow(Icons.notes, e.note),
              if (e.recurring) ...[
                _dialogRow(
                  Icons.repeat,
                  e.recurringDays.isEmpty
                      ? 'recurring'
                      : 'every ${_recurringLabel(e.recurringDays)}',
                ),
              ],
              _dialogRow(Icons.notifications_outlined, alarmText),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push<AppEvent?>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventDetailScreen(event: e),
                      ),
                    ).then((_) => _loadEvents());
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.edit_outlined,
                      color: Colors.white.withOpacity(0.7),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _offsetLabel(int minutes) {
    if (minutes == 15) return '15 min';
    if (minutes == 30) return '30 min';
    if (minutes == 60) return '1 hour';
    if (minutes == 1440) return '1 day';
    if (minutes == 10080) return '1 week';
    if (minutes == 43200) return '1 month';
    return '$minutes min';
  }

  String _recurringLabel(List<int> days) {
    const names = ['mo', 'tu', 'we', 'th', 'fr', 'sa', 'su'];
    final sorted = [...days]..sort();
    return sorted.map((d) => names[d - 1]).join(', ');
  }

  Widget _dialogRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.28), size: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontFamily: 'PixelifySans',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testNotification() async {
    Navigator.pop(context);
    final fireAt = DateTime.now().add(const Duration(seconds: 5));
    final event = AppEvent(
      name: 'test notification',
      place: 'debug',
      note: '',
      dateTime: fireAt,
      alertMode: EventAlertMode.notification,
    );
    await NotificationService.scheduleForEvent(event);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'notification in 5s',
          style: TextStyle(fontFamily: 'PixelifySans', fontSize: 12),
        ),
        duration: Duration(seconds: 3),
        backgroundColor: AppColors.brown,
      ),
    );
  }

  Future<void> _testAlarm() async {
    Navigator.pop(context);
    final fireAt = DateTime.now().add(const Duration(seconds: 5));
    await alarm_pkg.Alarm.set(
      alarmSettings: alarm_pkg.AlarmSettings(
        id: 999999,
        dateTime: fireAt,
        assetAudioPath: 'assets/alarm.mp3',
        loopAudio: false,
        vibrate: true,
        warningNotificationOnKill: false,
        androidFullScreenIntent: true,
        notificationSettings: const alarm_pkg.NotificationSettings(
          title: 'test alarm',
          body: 'debug — alarm fired',
          stopButton: 'stop',
        ),
        volumeSettings: alarm_pkg.VolumeSettings.fixed(volume: 0.8),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'alarm in 5s',
          style: TextStyle(fontFamily: 'PixelifySans', fontSize: 12),
        ),
        duration: Duration(seconds: 3),
        backgroundColor: AppColors.brown,
      ),
    );
  }

  void _showDebugDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.brown,
        title: const Text(
          'debug',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'PixelifySans',
            fontSize: 13,
          ),
        ),
        content: const Text(
          'fire a test in 5 seconds',
          style: TextStyle(
            color: Colors.white54,
            fontFamily: 'PixelifySans',
            fontSize: 11,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _testNotification,
            child: const Text(
              'notification',
              style: TextStyle(color: Colors.white, fontFamily: 'PixelifySans'),
            ),
          ),
          TextButton(
            onPressed: _testAlarm,
            child: const Text(
              'alarm',
              style: TextStyle(color: Colors.white, fontFamily: 'PixelifySans'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _buildCalendarDays();
    final selectedEvs = _selectedDay != null
        ? _eventsForDay(_selectedDay!)
        : <AppEvent>[];
    final next = _nextEvent();
    final shownDay = _selectedDay;

    return Scaffold(
      backgroundColor: AppColors.orange,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavButton(label: '<', onTap: _prevMonth),
                  Text(
                    '${_monthName(_focused.month)} ${_focused.year}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 31,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _showDebugDialog,
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withOpacity(0.35),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'test',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 10,
                              fontFamily: 'PixelifySans',
                            ),
                          ),
                        ),
                      ),
                      _NavButton(label: '>', onTap: _nextMonth),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: ['m', 't', 'w', 't', 'f', 's', 's']
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 4),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                itemCount: days.length,
                itemBuilder: (_, i) {
                  final day = days[i];
                  if (day == null) return const SizedBox();
                  final isThisMonth = day.month == _focused.month;
                  final isToday =
                      day.year == _today.year &&
                      day.month == _today.month &&
                      day.day == _today.day;
                  final isSelected =
                      _selectedDay != null &&
                      day.year == _selectedDay!.year &&
                      day.month == _selectedDay!.month &&
                      day.day == _selectedDay!.day;
                  final hasEv = _hasEvent(day);

                  return GestureDetector(
                    onTap: () => _onDayTap(day),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isToday
                            ? Colors.white
                            : isSelected && isThisMonth
                            ? Colors.white.withOpacity(0.2)
                            : hasEv && isThisMonth
                            ? Colors.white.withOpacity(0.12)
                            : Colors.transparent,
                        border: isThisMonth && !isToday
                            ? Border.all(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.8)
                                    : Colors.white.withOpacity(
                                        hasEv ? 0.45 : 0.25,
                                      ),
                                width: isSelected ? 2 : 1,
                              )
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: !isThisMonth
                                ? Colors.white.withOpacity(0.15)
                                : isToday
                                ? AppColors.orange
                                : Colors.white.withOpacity(hasEv ? 1.0 : 0.7),
                            fontSize: 23,
                            fontWeight: isToday || isSelected
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.white24, thickness: 1),
              if (shownDay != null) ...[
                const SizedBox(height: 6),
                Text(
                  _dayHeaderLabel(shownDay),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 20,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              // Bottom section: selected day events or next event
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: selectedEvs.isNotEmpty
                      ? ListView(
                          padding: const EdgeInsets.only(top: 6),
                          children: selectedEvs
                              .map(
                                (e) => GestureDetector(
                                  onTap: () => _showEventDialog(e),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.white.withOpacity(0.1),
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
                                          width: 52,
                                          child: Text(
                                            _fmtTime(e.dateTime),
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.35,
                                              ),
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            e.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          e.place,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.3,
                                            ),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        )
                      : next != null
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                next.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _fmtTime(next.dateTime),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.45),
                                  fontSize: 24,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 30),
          ),
        ),
      ),
    );
  }
}
