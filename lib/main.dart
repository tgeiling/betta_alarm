import 'package:alarm/alarm.dart';
import 'package:bettas_alarm/notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'kalender.dart';
import 'list.dart';
import 'rest.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  await Alarm.init();
  await NotificationService.init();
  runApp(const BettaAlarmApp());
}

class BettaAlarmApp extends StatelessWidget {
  const BettaAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'betta alarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Minecraft',
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    KalenderScreen(),
    EventListScreen(),
    RestScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        color: Colors.black,
        child: Row(
          children: [
            _NavItem(
              icon: Icons.calendar_today,
              label: 'calendar',
              selected: _currentIndex == 0,
              color: AppColors.orange,
              onTap: () => setState(() => _currentIndex = 0),
            ),
            _NavItem(
              icon: Icons.list,
              label: 'upcoming',
              selected: _currentIndex == 1,
              color: AppColors.green,
              onTap: () => setState(() => _currentIndex = 1),
            ),
            _NavItem(
              icon: Icons.bedtime_outlined,
              label: 'rest',
              selected: _currentIndex == 2,
              color: AppColors.purple,
              onTap: () => setState(() => _currentIndex = 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: selected ? color : Colors.black,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppColors {
  static const orange = Color(0xFF8A3800);
  static const brown = Color(0xFF502808);
  static const green = Color(0xFF143508);
  static const purple = Color(0xFF2A0050);
}

/// How a calendar event should alert the user.
enum EventAlertMode { none, notification, alarm }

extension EventAlertModeLabel on EventAlertMode {
  String get label {
    switch (this) {
      case EventAlertMode.none:
        return 'off';
      case EventAlertMode.notification:
        return 'notification';
      case EventAlertMode.alarm:
        return 'alarm';
    }
  }

  String toJson() => name;

  static EventAlertMode fromJson(String? value) {
    switch (value) {
      case 'notification':
        return EventAlertMode.notification;
      case 'alarm':
        return EventAlertMode.alarm;
      default:
        return EventAlertMode.notification;
    }
  }
}

/// Predefined custom alarm offsets in minutes.
class AlarmOffset {
  static const int min15 = 15;
  static const int min30 = 30;
  static const int hour1 = 60;
  static const int day1 = 1440;
  static const int week1 = 10080;
  static const int month1 = 43200;

  static const List<int> all = [min15, min30, hour1, day1, week1, month1];

  static String label(int minutes) {
    if (minutes == min15) return '15 min';
    if (minutes == min30) return '30 min';
    if (minutes == hour1) return '1 hour';
    if (minutes == day1) return '1 day';
    if (minutes == week1) return '1 week';
    if (minutes == month1) return '1 month';
    return '$minutes min';
  }
}

class AppEvent {
  final String name;
  final String place;
  final String note;
  final DateTime dateTime;

  /// Whether the 15-min-before auto-reminder is enabled.
  final bool autoAlarm;

  /// Whether custom offset reminders are enabled.
  final bool customAlarm;
  final List<int> customAlarmOffsets;

  final bool recurring;
  final List<int> recurringDays;

  /// Controls how event reminders alert: none / notification / alarm.
  final EventAlertMode alertMode;

  const AppEvent({
    required this.name,
    required this.place,
    required this.note,
    required this.dateTime,
    this.autoAlarm = true,
    this.customAlarm = false,
    this.customAlarmOffsets = const [],
    this.recurring = false,
    this.recurringDays = const [],
    this.alertMode = EventAlertMode.notification,
  });

  AppEvent copyWith({
    String? name,
    String? place,
    String? note,
    DateTime? dateTime,
    bool? autoAlarm,
    bool? customAlarm,
    List<int>? customAlarmOffsets,
    bool? recurring,
    List<int>? recurringDays,
    EventAlertMode? alertMode,
  }) {
    return AppEvent(
      name: name ?? this.name,
      place: place ?? this.place,
      note: note ?? this.note,
      dateTime: dateTime ?? this.dateTime,
      autoAlarm: autoAlarm ?? this.autoAlarm,
      customAlarm: customAlarm ?? this.customAlarm,
      customAlarmOffsets: customAlarmOffsets ?? this.customAlarmOffsets,
      recurring: recurring ?? this.recurring,
      recurringDays: recurringDays ?? this.recurringDays,
      alertMode: alertMode ?? this.alertMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'place': place,
    'note': note,
    'dateTime': dateTime.toIso8601String(),
    'autoAlarm': autoAlarm,
    'customAlarm': customAlarm,
    'customAlarmOffsets': customAlarmOffsets,
    'recurring': recurring,
    'recurringDays': recurringDays,
    'alertMode': alertMode.toJson(),
  };

  factory AppEvent.fromJson(Map<String, dynamic> json) => AppEvent(
    name: json['name'] as String,
    place: json['place'] as String,
    note: json['note'] as String,
    dateTime: DateTime.parse(json['dateTime'] as String),
    autoAlarm: json['autoAlarm'] as bool? ?? true,
    customAlarm: json['customAlarm'] as bool? ?? false,
    customAlarmOffsets:
        (json['customAlarmOffsets'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        [],
    recurring: json['recurring'] as bool? ?? false,
    recurringDays:
        (json['recurringDays'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        [],
    alertMode: EventAlertModeLabel.fromJson(json['alertMode'] as String?),
  );
}
