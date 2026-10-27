import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'disk_store_stub.dart' if (dart.library.io) 'disk_store_io.dart' as disk;
import '../domain/models.dart';
import '../domain/period.dart';
import '../domain/rules.dart';
import '../domain/stats.dart';

final _rand = Random();

String newId(String prefix) {
  final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final salt = _rand.nextInt(1 << 20).toRadixString(36);
  return '${prefix}_$stamp$salt';
}

/// 全局状态 + 持久化 + 用例。UI 只读它、只调它的方法。
class AppStore extends ChangeNotifier {
  AppStore({this.useDisk = true});

  /// 文件兜底开关：测试里关掉，避免读到上一条用例留下的文件。
  final bool useDisk;

  static const storageKey = 'dailyq.state.v1';

  /// 改名前的存储键，只用于一次性迁移，读到后会立刻写回新键。
  static const legacyStorageKey = 'fastlog.state.v1';

  /// 数据格式版本。加字段不用升版本（fromJson 都有默认值），
  /// 改字段含义/类型、需要搬数据时才 +1，并在 _migrate 里补分支。
  static const currentSchema = 1;

  final List<HabitEvent> events = [];
  final List<LogEntry> logs = [];
  int weekStart = 1;
  bool ready = false;

  /// 首页提醒条（v1 是应用内提示，不做系统推送）
  bool reminderOn = true;
  int reminderMinute = 20 * 60;
  String? reminderDismissedDay;

  /// 存储诊断：最近一次失败原因（正常为 null）。设置页会展示。
  String? storageError;
  String? storageLoadedAt;
  int persistedCount = 0;

  /// 写入串行化：避免多次变更的写入互相覆盖。
  Future<void> _writeQueue = Future<void>.value();

  /// 等待所有待写内容真正落盘。
  Future<void> flush() => _writeQueue;


  /// 测试可注入固定时间。
  DateTime Function() clock = DateTime.now;

  DateTime get now => clock();

  // ---------------------------------------------------------------- 生命周期

  Future<void> init() async {
    // 两路读取：插件存储优先，读不到就用文件兜底（文件不经过 platform channel）
    String? raw;
    String source = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(storageKey);
      if (v != null && v.isNotEmpty) {
        raw = v;
        source = 'prefs';
      } else {
        final legacy = prefs.getString(legacyStorageKey);
        if (legacy != null && legacy.isNotEmpty) {
          raw = legacy;
          source = 'prefs(旧键迁移)';
        }
      }
    } catch (e) {
      storageError = '插件存储不可用：$e';
    }
    if (raw == null && useDisk) {
      var fromDisk = await disk.readStateRaw();
      if (fromDisk == null || fromDisk.isEmpty) {
        final legacy = await disk.readLegacyStateRaw();
        if (legacy != null && legacy.isNotEmpty) {
          fromDisk = legacy;
          source = 'file(旧文件迁移)';
        }
      } else {
        source = 'file';
      }
      if (fromDisk != null && fromDisk.isNotEmpty) raw = fromDisk;
    }

    if (raw == null) {
      // 首次启动：种下演示数据，并立刻落盘
      seed();
      storageLoadedAt = '首次启动（已写入种子数据）';
      _writeQueue = _writeQueue.then((_) => _persist());
    } else {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final version = (map['schemaVersion'] as num?)?.toInt() ?? 0;
        if (version > currentSchema) {
          // 用旧版本 App 打开新版本写的数据：不覆盖，避免把新格式写坏
          storageError = '数据版本 $version 高于当前应用 $currentSchema，请先升级应用';
        }
        _migrate(map, version);
        _restore(map);
        storageLoadedAt = '从 $source 恢复 ${raw.length} 字符（schema v$version）';
        if (source == 'file' || source.contains('旧')) storageError = null;
        // 从旧键/旧文件读到的数据，立刻按新名字写一份，下次不再依赖旧位置
        if (source.contains('旧')) {
          _writeQueue = _writeQueue.then((_) => _persist());
        }
      } catch (e) {
        storageError = '存储内容无法解析：$e';
        storageLoadedAt = '读取失败，已按演示数据启动（原数据未删除）';
      }
    }
    ready = true;
    notifyListeners();
  }

  void _restore(Map<String, dynamic> map) {
    events
      ..clear()
      ..addAll((map['events'] as List)
          .map((e) => HabitEvent.fromJson(e as Map<String, dynamic>)));
    logs
      ..clear()
      ..addAll(dedupeLogs((map['logs'] as List)
          .map((e) => LogEntry.fromJson(e as Map<String, dynamic>))));
    weekStart = (map['weekStart'] as num?)?.toInt() ?? 1;
    reminderOn = map['reminderOn'] as bool? ?? true;
    reminderMinute = (map['reminderMinute'] as num?)?.toInt() ?? 20 * 60;
    reminderDismissedDay = map['reminderDismissedDay'] as String?;
  }

  /// 结构迁移入口。当前只有 v1，暂无迁移分支；
  /// 以后改结构时在这里按 fromVersion 逐级搬数据，并同步提升 [currentSchema]。
  void _migrate(Map<String, dynamic> map, int fromVersion) {
    if (fromVersion >= currentSchema) return;
    // 示例：if (fromVersion < 2) { map['新字段'] = 默认值; }
  }

  /// 从备份 JSON 恢复（设置页「导入 JSON」用）。成功后会立即落盘。
  Future<ImportResult> importJson(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const ImportResult(false, '内容为空');
    try {
      final map = jsonDecode(trimmed) as Map<String, dynamic>;
      if (!map.containsKey('events') || !map.containsKey('logs')) {
        return const ImportResult(false, '不是有效备份：缺少 events 或 logs');
      }
      _migrate(map, (map['schemaVersion'] as num?)?.toInt() ?? 0);
      _restore(map);
      _commit();
      await flush();
      return ImportResult(true, '已导入 ${events.length} 个事件、${logs.length} 条记录');
    } catch (e) {
      return ImportResult(false, '解析失败：$e');
    }
  }

  Future<void> _persist() async {
    final payload = jsonEncode({
      'schemaVersion': 1,
      'weekStart': weekStart,
      'reminderOn': reminderOn,
      'reminderMinute': reminderMinute,
      'reminderDismissedDay': reminderDismissedDay,
      'events': events.map((e) => e.toJson()).toList(),
      'logs': logs.map((e) => e.toJson()).toList(),
    });

    // 两路都写：任一路成功就算存住了
    var prefsOk = false;
    String? prefsError;
    try {
      final prefs = await SharedPreferences.getInstance();
      prefsOk = await prefs.setString(storageKey, payload);
      if (!prefsOk) prefsError = 'setString 返回 false';
    } catch (e) {
      prefsError = '$e';
    }

    final fileOk = useDisk ? await disk.writeStateRaw(payload) : false;

    if (prefsOk || fileOk) {
      storageError = prefsOk ? null : '插件存储写入失败，已用文件兜底（${disk.backendName}）';
      persistedCount = events.length + logs.length;
    } else {
      storageError = '两路写入都失败：prefs($prefsError) / file';
    }
  }

  void _commit() {
    notifyListeners();
    _writeQueue = _writeQueue.then((_) => _persist()).then((_) {
      if (storageError != null) notifyListeners();
    });
  }

  /// 设置页“存储自检”：把真实存储状态读出来，用于定位“改了又变回去”。
  Future<String> storageDiagnostics() async {
    final lines = <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      lines.add('存储键：$storageKey');
      lines.add('当前存储：${raw == null ? "空（从未写入）" : "${raw.length} 字符"}');
      lines.add('内存中：${events.length} 个事件 / ${logs.length} 条记录');

      final probeKey = 'dailyq.probe';
      final wrote = await prefs.setString(probeKey, 'ok');
      await prefs.reload();
      final back = prefs.getString(probeKey);
      lines.add('写读自检：${wrote && back == "ok" ? "通过 ✓" : "失败 ✗（写入后读不回）"}');
      await prefs.remove(probeKey);

      if (raw != null && raw.isNotEmpty) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          final e = (map['events'] as List?)?.length ?? 0;
          final l = (map['logs'] as List?)?.length ?? 0;
          lines.add('存储内：$e 个事件 / $l 条记录');
        } catch (err) {
          lines.add('存储内容解析失败：$err');
        }
      }
    } catch (err) {
      lines.add('访问存储异常：$err');
    }
    if (storageLoadedAt != null) lines.add('启动来源：$storageLoadedAt');
    if (storageError != null) lines.add('最近错误：$storageError');
    return lines.join('\n');
  }

  // ---------------------------------------------------------------- 查询

  HabitEvent? eventById(String id) {
    for (final e in events) {
      if (e.id == id) return e;
    }
    return null;
  }

  List<HabitEvent> visible(HomeFilter filter) =>
      events.where((e) => isVisibleOnHome(e, filter, now)).toList();

  /// 首页筛选用的分组名（跳过归档事件与空分组，按名称排序）。
  List<String> get groups {
    final names = <String>{};
    for (final e in events) {
      final g = e.groupId?.trim();
      if (g != null && g.isNotEmpty && !e.archived) names.add(g);
    }
    return names.toList()..sort();
  }

  double currentOf(HabitEvent e) => currentValue(e, logs, now, weekStart: weekStart);

  int get totalLogs => logs.where((l) => l.deletedAt == null).length;

  int get totalDays =>
      logs.where((l) => l.deletedAt == null).map((l) => l.dayKey).toSet().length;

  // ---------------------------------------------------------------- 写记录

  LogOutcome addLog({
    required String eventId,
    required DateTime at,
    required double value,
    String note = '',
  }) {
    final event = eventById(eventId);
    if (event == null) return const LogOutcome.blocked(LogBlock.limit);
    final block = checkCanLog(event, logs, at, now);
    if (block != null) return LogOutcome.blocked(block);
    if (value <= 0) return const LogOutcome.blocked(LogBlock.limit);

    final log = LogEntry(
      id: newId('log'),
      eventId: eventId,
      occurredAt: at,
      dayKey: toDayKey(at),
      value: value,
      note: note,
    );
    logs.add(log);
    _commit();
    return LogOutcome.ok(log.id);
  }

  /// 快速记录：值取事件的 step。
  LogOutcome quickLog(String eventId) {
    final event = eventById(eventId);
    if (event == null) return const LogOutcome.blocked(LogBlock.limit);
    return addLog(
      eventId: eventId,
      at: now,
      value: event.step <= 0 ? 1 : event.step,
    );
  }

  /// 撤销：直接从列表移除（刚写入的记录，不留痕迹）。
  void undoLog(String logId) {
    logs.removeWhere((l) => l.id == logId);
    _commit();
  }

  void clearLogs() {
    logs.clear();
    _commit();
  }

  /// 详情页删除单条记录（软删除，可撤销）。
  void softDeleteLog(String logId) {
    final i = logs.indexWhere((l) => l.id == logId);
    if (i < 0) return;
    logs[i] = logs[i].copyWith(deletedAt: now);
    _commit();
  }

  void restoreLog(String logId) {
    final i = logs.indexWhere((l) => l.id == logId);
    if (i < 0) return;
    logs[i] = logs[i].copyWith(clearDeleted: true);
    _commit();
  }

  // ---------------------------------------------------------------- 详情与设置

  List<LogEntry> logsForEvent(String eventId) => logsOf(logs, eventId);

  double totalForEvent(String eventId) => sumValue(logs, eventId);

  int streakForEvent(String eventId) {
    final e = eventById(eventId);
    if (e == null) return 0;
    return streakOf(e, logs, now);
  }

  void setWeekStart(int value) {
    weekStart = value;
    _commit();
  }

  void setReminderEnabled(bool value) {
    reminderOn = value;
    _commit();
  }

  void setReminderMinute(int minute) {
    reminderMinute = minute;
    _commit();
  }

  void dismissReminderToday() {
    reminderDismissedDay = toDayKey(now);
    _commit();
  }

  bool get reminderVisible =>
      reminderOn && reminderDismissedDay != toDayKey(now);

  /// 今天还没达成的事件数量（用于提醒条）。
  int get pendingTodayCount {
    var count = 0;
    for (final e in events) {
      if (!isVisibleOnHome(e, HomeFilter.today, now)) continue;
      final state = achievementOf(e, currentOf(e));
      if (state != Achievement.done && state != Achievement.over) count++;
    }
    return count;
  }

  String exportCsv() {
    final rows = <String>['日期,时间,事件,类型,数值,单位,备注'];
    final list = logs.where((l) => l.deletedAt == null).toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    for (final log in list) {
      final e = eventById(log.eventId);
      if (e == null) continue;
      final d = log.occurredAt;
      rows.add([
        toDayKey(d),
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
        _csv(e.name),
        e.metricType.name,
        trimZero(log.value),
        e.unit,
        _csv(log.note),
      ].join(','));
    }
    return rows.join('\n');
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 1,
        'exportedAt': now.toIso8601String(),
        'events': events.map((e) => e.toJson()).toList(),
        'logs': logs.map((e) => e.toJson()).toList(),
      });

  String _csv(String s) =>
      s.contains(',') || s.contains('"') || s.contains('\n')
          ? '"${s.replaceAll('"', '""')}"'
          : s;

  // ---------------------------------------------------------------- 写事件

  void upsertEvent(HabitEvent event) {
    final i = events.indexWhere((e) => e.id == event.id);
    if (i >= 0) {
      final old = events[i];
      // 类型不可变（CREATE-R-02）：即使上游传了不同类型也强制保留旧类型
      events[i] = old.metricType == event.metricType
          ? event
          : _withMetricType(event, old.metricType);
    } else {
      events.insert(0, event);
    }
    _commit();
  }

  void setArchived(String id, bool archived) {
    final i = events.indexWhere((e) => e.id == id);
    if (i < 0) return;
    events[i] = events[i].copyWith(archived: archived);
    _commit();
  }

  void pin(String id) {
    final i = events.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final e = events.removeAt(i);
    events.insert(0, e);
    _commit();
  }

  void removeEvent(String id) {
    events.removeWhere((e) => e.id == id);
    logs.removeWhere((l) => l.eventId == id);
    _commit();
  }

  Future<void> resetDemo() async {
    seed();
    _commit();
  }

  // ---------------------------------------------------------------- 种子

  void seed() {
    final today = dateOnly(now);
    final start = DateTime(today.year, today.month, today.day - 20);
    final createdAt = now;

    events
      ..clear()
      ..addAll([
        HabitEvent(
          id: 'e1',
          name: '读十页书',
          emoji: '📚',
          colorValue: 0xFFA3C644,
          metricType: MetricType.count,
          resetCycle: ResetCycle.none,
          target: 1,
          step: 1,
          unit: '次',
          groupId: '学习',
          startDate: start,
          showCheck: true,
          createdAt: createdAt,
        ),
        HabitEvent(
          id: 'e2',
          name: '做一组拉伸',
          emoji: '🧘',
          colorValue: 0xFF4FB286,
          metricType: MetricType.count,
          resetCycle: ResetCycle.daily,
          target: 1,
          step: 1,
          unit: '次',
          groupId: '健康',
          startDate: start,
          quickLog: true,
          showCheck: true,
          remind: true,
          createdAt: createdAt,
        ),
        HabitEvent(
          id: 'e3',
          name: '阅读三十分钟',
          emoji: '📖',
          colorValue: 0xFF5C93E8,
          desc: '每天睡前读一点',
          metricType: MetricType.duration,
          resetCycle: ResetCycle.daily,
          target: 30,
          step: 5,
          unit: '分钟',
          groupId: '习惯',
          startDate: start,
          showCheck: true,
          remind: true,
          follow: true,
          createdAt: createdAt,
        ),
        HabitEvent(
          id: 'e4',
          name: '喝水',
          emoji: '💧',
          colorValue: 0xFF9B7BE0,
          metricType: MetricType.value,
          resetCycle: ResetCycle.daily,
          target: 2000,
          step: 250,
          unit: '毫升',
          groupId: '健康',
          startDate: start,
          quickLog: true,
          showCheck: false,
          createdAt: createdAt,
        ),
      ]);

    logs.clear();
    const plan = <String, List<int>>{
      'e2': [1, 2, 4, 5],
      'e3': [1, 2, 4, 5],
      'e4': [1, 2, 3, 4, 5, 6],
    };
    const e3Values = [30.0, 25.0, 35.0, 30.0];
    const e4Values = [2000.0, 1500.0, 2250.0, 2000.0, 750.0, 1750.0];

    plan.forEach((eventId, days) {
      for (final back in days) {
        final at = DateTime(today.year, today.month, today.day - back, 9 + back % 8);
        var value = 1.0;
        if (eventId == 'e3') value = e3Values[back % e3Values.length];
        if (eventId == 'e4') value = e4Values[back % e4Values.length];
        logs.add(LogEntry(
          id: 'seed_${eventId}_$back',
          eventId: eventId,
          occurredAt: at,
          dayKey: toDayKey(at),
          value: value,
        ));
      }
    });
  }
}

HabitEvent _withMetricType(HabitEvent e, MetricType type) => HabitEvent(      id: e.id,
      name: e.name,
      emoji: e.emoji,
      colorValue: e.colorValue,
      desc: e.desc,
      groupId: e.groupId,
      metricType: type,
      resetCycle: e.resetCycle,
      target: e.target,
      step: e.step,
      unit: e.unit,
      startDate: e.startDate,
      endDate: e.endDate,
      quickLog: e.quickLog,
      dailyLimit: e.dailyLimit,
      showCheck: e.showCheck,
      archived: e.archived,
      remind: e.remind,
      follow: e.follow,
      createdAt: e.createdAt,
    );

/// 导入结果：给设置页直接展示，不需要再解析异常。
class ImportResult {
  const ImportResult(this.ok, this.message);

  final bool ok;
  final String message;
}
