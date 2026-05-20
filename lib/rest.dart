import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'main.dart';
import 'alarm.dart';
import 'sleep.dart';
import 'storage.dart';

class RestScreen extends StatefulWidget {
  const RestScreen({super.key});

  @override
  State<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<RestScreen> {
  late Timer _timer;
  late DateTime _now;
  bool _colonVisible = true;
  bool _napActive = false;
  DateTime? _napWakeAt;
  bool _sleepActive = false;
  DateTime? _sleepWakeAt;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() {
        _now = DateTime.now();
        _colonVisible = !_colonVisible;
        if (_napWakeAt != null && _now.isAfter(_napWakeAt!)) {
          _napActive = false;
          _napWakeAt = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _fmtTime() {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    return '$h${_colonVisible ? ':' : ' '}$m';
  }

  String _fmtDate() {
    final days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return '${days[_now.weekday - 1]} · ${_now.day.toString().padLeft(2, '0')}.${_now.month.toString().padLeft(2, '0')}.${_now.year}';
  }

  String _countdown(DateTime target) {
    final diff = target.difference(_now);
    if (diff.isNegative) return '00:00';
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    if (diff.inHours > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  Future<void> _onNap() async {
    // Default 45 min, editable via Cupertino duration picker
    Duration napDuration = const Duration(minutes: 45);

    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (_) => _NapDialog(
        initialDuration: napDuration,
        onChanged: (d) => napDuration = d,
      ),
    );

    if (confirmed != true) return;

    final wakeAt = DateTime.now().add(napDuration);
    await AlarmService.scheduleNap(wakeAt);
    setState(() {
      _napActive = true;
      _napWakeAt = wakeAt;
      _sleepActive = false;
      _sleepWakeAt = null;
    });
  }

  Future<void> _onCancelNap() async {
    await AlarmService.cancelNap();
    setState(() {
      _napActive = false;
      _napWakeAt = null;
    });
  }

  Future<void> _onSleep() async {
    final result = await SleepService.scheduleSleep(DateTime.now());

    if (!mounted) return;

    // Show warning if any before confirming sleep
    if (result.warning != null) {
      final proceed = await _showSleepWarning(result.warning!);
      if (proceed != true) {
        // Cancel the scheduled alarm and remove wake event
        await AlarmService.cancelSleepAlarm();
        final all = await StorageService.loadEvents();
        all.removeWhere(
          (e) =>
              e.name == result.wakeEvent.name &&
              e.dateTime == result.wakeEvent.dateTime,
        );
        await StorageService.saveEvents(all);
        return;
      }
    }

    setState(() {
      _sleepActive = true;
      _sleepWakeAt = result.wakeAt;
      _napActive = false;
      _napWakeAt = null;
    });
  }

  Future<void> _onCancelSleep() async {
    await AlarmService.cancelSleepAlarm();
    // Remove the auto-created wake event
    if (_sleepWakeAt != null) {
      final all = await StorageService.loadEvents();
      all.removeWhere((e) => e.name == 'wake up' && e.dateTime == _sleepWakeAt);
      await StorageService.saveEvents(all);
    }
    setState(() {
      _sleepActive = false;
      _sleepWakeAt = null;
    });
  }

  Future<bool?> _showSleepWarning(SleepWarning warning) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.purple,
        title: Text(
          warning.type == SleepWarningType.awayEvent
              ? '⚠ away event'
              : '⚠ short sleep',
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
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'edit schedule',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontFamily: 'PixelifySans',
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'sleep anyway',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'PixelifySans',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.purple,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Text(
                    _fmtTime(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _fmtDate(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  if (_napActive && _napWakeAt != null) ...[
                    Text(
                      _countdown(_napWakeAt!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'nap · wake at ${_napWakeAt!.hour.toString().padLeft(2, '0')}:${_napWakeAt!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                        fontFamily: 'PixelifySans',
                      ),
                    ),
                  ] else if (_sleepActive && _sleepWakeAt != null) ...[
                    Icon(
                      Icons.bedtime_outlined,
                      size: 52,
                      color: Colors.white.withOpacity(0.15),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'alarm at ${_sleepWakeAt!.hour.toString().padLeft(2, '0')}:${_sleepWakeAt!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                        fontFamily: 'PixelifySans',
                      ),
                    ),
                  ] else ...[
                    Icon(
                      Icons.bedtime_outlined,
                      size: 52,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'alarms on · dnd active',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      children: [
                        if (_napActive)
                          _RestButton(
                            label: 'cancel nap',
                            icon: Icons.cancel_outlined,
                            filled: false,
                            onTap: _onCancelNap,
                          )
                        else
                          _RestButton(
                            label: 'nap',
                            icon: Icons.snooze,
                            filled: false,
                            onTap: _onNap,
                          ),
                        const SizedBox(height: 8),
                        if (_sleepActive)
                          _RestButton(
                            label: 'cancel sleep',
                            icon: Icons.cancel_outlined,
                            filled: true,
                            onTap: _onCancelSleep,
                          )
                        else
                          _RestButton(
                            label: 'sleep',
                            icon: Icons.bedtime_outlined,
                            filled: true,
                            onTap: _onSleep,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NapDialog extends StatefulWidget {
  final Duration initialDuration;
  final ValueChanged<Duration> onChanged;
  const _NapDialog({required this.initialDuration, required this.onChanged});

  @override
  State<_NapDialog> createState() => _NapDialogState();
}

class _NapDialogState extends State<_NapDialog> {
  late Duration _duration;

  @override
  void initState() {
    super.initState();
    _duration = widget.initialDuration;
  }

  @override
  Widget build(BuildContext context) {
    final wakeAt = DateTime.now().add(_duration);
    final wakeStr =
        '${wakeAt.hour.toString().padLeft(2, '0')}:${wakeAt.minute.toString().padLeft(2, '0')}';

    return Container(
      color: const Color(0xFF1A0035),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Text(
                    'cancel',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontFamily: 'PixelifySans',
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                ),
                Column(
                  children: [
                    const Text(
                      'nap',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'PixelifySans',
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'wake at $wakeStr',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontFamily: 'PixelifySans',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text(
                    'start',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'PixelifySans',
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            child: CupertinoTimerPicker(
              mode: CupertinoTimerPickerMode.hm,
              initialTimerDuration: _duration,
              onTimerDurationChanged: (d) {
                setState(() => _duration = d);
                widget.onChanged(d);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _RestButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _RestButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.transparent,
          border: filled
              ? null
              : Border.all(color: Colors.white.withOpacity(0.4), width: 2),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: filled ? AppColors.purple : Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: filled ? AppColors.purple : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                fontFamily: 'PixelifySans',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
