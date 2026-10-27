import 'models.dart';
import 'period.dart';
import 'rules.dart';

/// 指定事件在 [from, to) 区间内的有效记录之和。
double sumValue(
  List<LogEntry> logs,
  String eventId, {
  DateTime? from,
  DateTime? to,
}) {
  var sum = 0.0;
  for (final log in logs) {
    if (log.eventId != eventId || log.deletedAt != null) continue;
    if (from != null && log.occurredAt.isBefore(from)) continue;
    if (to != null && !log.occurredAt.isBefore(to)) continue;
    sum += log.value;
  }
  return sum;
}

/// 当前周期内的累计值（惰性计算，SYS-R-03）。
double currentValue(
  HabitEvent event,
  List<LogEntry> logs,
  DateTime now, {
  int weekStart = 1,
}) {
  final start = periodStart(event.resetCycle, now, weekStart: weekStart);
  return sumValue(logs, event.id, from: start);
}

/// 达成态（SYS-R-04）。
Achievement achievementOf(HabitEvent event, double current) {
  final target = event.target;
  if (target == null || target <= 0) return Achievement.none;
  if (current <= 0) return Achievement.none;
  if (current < target) return Achievement.partial;
  if (current == target) return Achievement.done;
  return Achievement.over;
}

/// 进度比例，封顶 1。
double progressRatio(HabitEvent event, double current) {
  final target = event.target;
  if (target == null || target <= 0) return 0;
  final ratio = current / target;
  return ratio.clamp(0.0, 1.0);
}

/// 按 id 去重，后写入的覆盖先写入的（幂等，SYS-R-06）。
List<LogEntry> dedupeLogs(Iterable<LogEntry> logs) {
  final byId = <String, LogEntry>{};
  for (final log in logs) {
    byId[log.id] = log;
  }
  return byId.values.toList();
}

/// 按归属日聚合，返回 dayKey -> 当日累计值（不含软删除）。
Map<String, double> dailySums(
  List<LogEntry> logs,
  String eventId, {
  DateTime? from,
  DateTime? to,
}) {
  final map = <String, double>{};
  for (final log in logs) {
    if (log.eventId != eventId || log.deletedAt != null) continue;
    if (from != null && log.occurredAt.isBefore(from)) continue;
    if (to != null && !log.occurredAt.isBefore(to)) continue;
    map[log.dayKey] = (map[log.dayKey] ?? 0) + log.value;
  }
  return map;
}

/// 某一天是否算「达成」：有目标看是否达标，无目标只要有记录即可。
bool reachedTargetOn(HabitEvent event, double value) {
  if (value <= 0) return false;
  if (!event.hasTarget) return true;
  return value >= event.target!;
}

/// 连续达成天数。今天还没达成时，从昨天开始往前数，不算断。
int streakOf(HabitEvent event, List<LogEntry> logs, DateTime now) {
  final sums = dailySums(logs, event.id);
  var cursor = dateOnly(now);
  bool doneOn(DateTime d) => reachedTargetOn(event, sums[toDayKey(d)] ?? 0);

  if (!doneOn(cursor)) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  var streak = 0;
  while (streak < 3650 && doneOn(cursor)) {
    streak++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return streak;
}

/// 该事件的全部有效记录，按时间倒序。
List<LogEntry> logsOf(List<LogEntry> logs, String eventId) {
  final list = logs
      .where((l) => l.eventId == eventId && l.deletedAt == null)
      .toList()
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  return list;
}

/// 数字展示：>=1000 用 k 缩写（圆圈内用），完整数字用于副标题。
String shortNumber(double v) {
  if (v >= 10000) return '${(v / 1000).round()}k';
  if (v >= 1000) {
    final s = (v / 1000).toStringAsFixed(1);
    return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}k';
  }
  return trimZero(v);
}

String fullNumber(double v) {
  final rounded = v.round();
  final s = rounded.toString();
  if (s.length <= 3) return s;
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
    buffer.write(s[i]);
  }
  return buffer.toString();
}

String trimZero(double v) {
  final rounded = (v * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) return rounded.round().toString();
  return rounded.toStringAsFixed(1);
}
