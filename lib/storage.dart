import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'main.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();
  static const _eventsKey = 'betta_events';

  static Future<List<AppEvent>> loadEvents() async {
    final raw = await _storage.read(key: _eventsKey);
    if (raw == null) return [];
    final List<dynamic> decoded = jsonDecode(raw);
    return decoded
        .map((e) => AppEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveEvents(List<AppEvent> events) async {
    final encoded = jsonEncode(events.map((e) => e.toJson()).toList());
    await _storage.write(key: _eventsKey, value: encoded);
  }
}
