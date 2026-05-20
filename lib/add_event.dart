import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'main.dart';

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _nameCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _autoAlarm = true;
  bool _customAlarm = false;
  Set<int> _customAlarmOffsets = {};
  bool _recurring = false;
  Set<int> _recurringDays = {};

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.brown),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    DateTime temp = DateTime(2000, 1, 1, _time.hour, _time.minute);
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => Container(
        color: const Color(0xFF1C0A00),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: Text(
                    'cancel',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontFamily: 'PixelifySans',
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton(
                  child: const Text(
                    'done',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'PixelifySans',
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () {
                    setState(
                      () => _time = TimeOfDay(
                        hour: temp.hour,
                        minute: temp.minute,
                      ),
                    );
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            SizedBox(
              height: 180,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: temp,
                use24hFormat: true,
                onDateTimeChanged: (dt) => temp = dt,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) return;
    final dt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    final event = AppEvent(
      name: _nameCtrl.text.trim().toLowerCase(),
      place: _placeCtrl.text.trim().toLowerCase(),
      note: _noteCtrl.text.trim().toLowerCase(),
      dateTime: dt,
      autoAlarm: _autoAlarm,
      customAlarm: _customAlarm,
      customAlarmOffsets: _customAlarmOffsets.toList(),
      recurring: _recurring,
      recurringDays: _recurringDays.toList()..sort(),
    );
    Navigator.pop(context, event);
  }

  String _fmtDate() =>
      '${_date.day.toString().padLeft(2, '0')}.${_date.month.toString().padLeft(2, '0')}.${_date.year}';

  String _fmtTime() =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  Widget _field(TextEditingController ctrl, String hint, {bool big = false}) {
    return TextField(
      controller: ctrl,
      style: TextStyle(
        color: Colors.white,
        fontSize: big ? 17 : 13,
        fontWeight: big ? FontWeight.w500 : FontWeight.w400,
        fontFamily: 'PixelifySans',
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.22),
          fontSize: big ? 17 : 13,
          fontFamily: 'PixelifySans',
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.25)),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.6)),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'PixelifySans',
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: Container(
              width: 30,
              height: 16,
              decoration: BoxDecoration(
                color: value ? Colors.white : Colors.transparent,
                border: value
                    ? null
                    : Border.all(
                        color: Colors.white.withOpacity(0.35),
                        width: 2,
                      ),
              ),
              child: Align(
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.all(1),
                  color: value
                      ? AppColors.brown
                      : Colors.white.withOpacity(0.35),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Divider(color: Colors.white.withOpacity(0.12), thickness: 1);

  Widget _customAlarmPanel() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: _customAlarm
          ? Container(
              margin: const EdgeInsets.only(top: 6, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'notify before event',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontFamily: 'PixelifySans',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: AlarmOffset.all.map((offset) {
                      final selected = _customAlarmOffsets.contains(offset);
                      return GestureDetector(
                        onTap: () => setState(() {
                          selected
                              ? _customAlarmOffsets.remove(offset)
                              : _customAlarmOffsets.add(offset);
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? Colors.white : Colors.transparent,
                            border: Border.all(
                              color: selected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            AlarmOffset.label(offset),
                            style: TextStyle(
                              color: selected ? AppColors.brown : Colors.white,
                              fontSize: 11,
                              fontFamily: 'PixelifySans',
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _recurringPanel() {
    final days = ['mo', 'tu', 'we', 'th', 'fr', 'sa', 'su'];
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: _recurring
          ? Container(
              margin: const EdgeInsets.only(top: 6, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'repeat on',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontFamily: 'PixelifySans',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (i) {
                      final dayNum = i + 1;
                      final selected = _recurringDays.contains(dayNum);
                      return GestureDetector(
                        onTap: () => setState(() {
                          selected
                              ? _recurringDays.remove(dayNum)
                              : _recurringDays.add(dayNum);
                        }),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: selected ? Colors.white : Colors.transparent,
                            border: Border.all(
                              color: selected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              days[i],
                              style: TextStyle(
                                color: selected
                                    ? AppColors.brown
                                    : Colors.white,
                                fontSize: 10,
                                fontFamily: 'PixelifySans',
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brown,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      '<',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'PixelifySans',
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      color: Colors.white,
                      child: const Text(
                        'save',
                        style: TextStyle(
                          color: AppColors.brown,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'PixelifySans',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _field(_nameCtrl, 'event name...', big: true),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickDate,
                            child: AbsorbPointer(
                              child: TextField(
                                controller: TextEditingController(
                                  text: _fmtDate(),
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontFamily: 'PixelifySans',
                                ),
                                decoration: InputDecoration(
                                  hintText: 'date',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.22),
                                    fontFamily: 'PixelifySans',
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.25),
                                    ),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickTime,
                            child: AbsorbPointer(
                              child: TextField(
                                controller: TextEditingController(
                                  text: _fmtTime(),
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontFamily: 'PixelifySans',
                                ),
                                decoration: InputDecoration(
                                  hintText: 'time',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.22),
                                    fontFamily: 'PixelifySans',
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.25),
                                    ),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _field(_placeCtrl, 'place...'),
                    const SizedBox(height: 12),
                    _field(_noteCtrl, 'note...'),
                    const SizedBox(height: 16),
                    _divider(),
                    _toggle(
                      'auto alarm',
                      _autoAlarm,
                      (v) => setState(() => _autoAlarm = v),
                    ),
                    _divider(),
                    _toggle(
                      'custom alarm',
                      _customAlarm,
                      (v) => setState(() => _customAlarm = v),
                    ),
                    _customAlarmPanel(),
                    _divider(),
                    _toggle(
                      'recurring',
                      _recurring,
                      (v) => setState(() => _recurring = v),
                    ),
                    _recurringPanel(),
                    _divider(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
