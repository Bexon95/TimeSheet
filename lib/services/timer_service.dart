import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../database/models.dart';

class TimerService {
  static const _key = 'active_timer';

  Future<ActiveTimer?> getActiveTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    return ActiveTimer.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> startTimer({
    required int workplaceId,
    int? projectId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final timer = ActiveTimer(
      workplaceId: workplaceId,
      startedAt: DateTime.now(),
      projectId: projectId,
    );
    await prefs.setString(_key, jsonEncode(timer.toJson()));
  }

  Future<void> clearTimer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
