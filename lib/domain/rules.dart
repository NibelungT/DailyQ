import 'models.dart';
import 'period.dart';

String _two(int v) => v.toString().padLeft(2, '0');

/// 本地时区的 YYYY-MM-DD（SYS-R-01）。
String toDayKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// 某事件在某个归属日的有效记录条数（软删除不计）。
int countOnDay(List<LogEntry> logs, String eventId, String dayKey) {
  var count = 0;
  for (final log in logs) {
    if (log.eventId == eventId && log.dayKey == dayKey && log.deletedAt == null) {
      count++;
    }
  }
  return count;
}

/// 是否允许在 [at] 时刻记录（SYS-R-09 / LOG-R-07 / LOG-R-08）。
LogBlock? checkCanLog(
  HabitEvent event,
  List<LogEntry> logs,
  DateTime at,
  DateTime now, {
  int maxBackfillDays = 30,
}) {
  if (at.isAfter(now.add(const Duration(minutes: 1)))) {
    return LogBlock.future;
  }
  final dayDiff = dateOnly(now).difference(dateOnly(at)).inDays;
  if (dayDiff > maxBackfillDays) {
    return LogBlock.tooOld;
  }
  if (event.dailyLimit > 0 &&
      countOnDay(logs, event.id, toDayKey(at)) >= event.dailyLimit) {
    return LogBlock.limit;
  }
  return null;
}

/// 首页可见性（HOME 筛选 + SYS-R-07 / SYS-R-10）。
bool isVisibleOnHome(HabitEvent event, HomeFilter filter, DateTime now) {
  switch (filter) {
    case HomeFilter.archived:
      return event.archived;
    case HomeFilter.all:
      return !event.archived;
    case HomeFilter.today:
      if (event.archived) return false;
      if (dateOnly(event.startDate).isAfter(dateOnly(now))) return false;
      // 指定了星期的事件只在配置的日子出现在「今日」
      if (!event.isScheduledOn(now)) return false;
      return event.resetCycle == ResetCycle.daily ||
          event.resetCycle == ResetCycle.none;
  }
}
