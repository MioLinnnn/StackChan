/*
SPDX-FileCopyrightText: 2026 M5Stack Technology CO LTD
SPDX-License-Identifier: MIT
*/

import 'package:get/get.dart';

enum DebugLogLevel { info, warn, error }

class DebugLogEntry {
  DebugLogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
  });

  final DateTime timestamp;
  final DebugLogLevel level;
  final String tag;
  final String message;

  String get timeLabel {
    final t = timestamp;
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get line => '$timeLabel [$tag] $message';
}

class DebugLogService {
  DebugLogService._();

  static final DebugLogService shared = DebugLogService._();

  static const int maxEntries = 500;

  final RxList<DebugLogEntry> logs = <DebugLogEntry>[].obs;

  void info(String tag, String message) => _add(DebugLogLevel.info, tag, message);

  void warn(String tag, String message) => _add(DebugLogLevel.warn, tag, message);

  void error(String tag, String message) => _add(DebugLogLevel.error, tag, message);

  void clear() => logs.clear();

  String exportAll() => logs.map((e) => e.line).join('\n');

  void _add(DebugLogLevel level, String tag, String message) {
    logs.add(
      DebugLogEntry(
        timestamp: DateTime.now(),
        level: level,
        tag: tag,
        message: message,
      ),
    );
    while (logs.length > maxEntries) {
      logs.removeAt(0);
    }
  }
}
