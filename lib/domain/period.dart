import 'models.dart';

/// 只保留年月日，去掉时分秒。
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 当前周期的起点（SYS-R-02）。返回 null 表示「不重置」。
///
/// [weekStart] 0 = 周日起，1 = 周一起（默认）。
DateTime? periodStart(ResetCycle cycle, DateTime now, {int weekStart = 1}) {
  final day = dateOnly(now);
  switch (cycle) {
    case ResetCycle.none:
      return null;
    case ResetCycle.daily:
      return day;
    case ResetCycle.weekly:
      // DateTime.weekday: 周一=1 ... 周日=7；转成 周日=0 ... 周六=6
      final index = day.weekday % 7;
      final diff = (index - weekStart) % 7;
      return DateTime(day.year, day.month, day.day - diff);
    case ResetCycle.monthly:
      return DateTime(day.year, day.month, 1);
  }
}

/// 周期终点（不含），用于按区间统计。
DateTime periodEnd(ResetCycle cycle, DateTime now, {int weekStart = 1}) {
  final day = dateOnly(now);
  switch (cycle) {
    case ResetCycle.none:
      return DateTime(day.year + 100);
    case ResetCycle.daily:
      return DateTime(day.year, day.month, day.day + 1);
    case ResetCycle.weekly:
      final start = periodStart(cycle, now, weekStart: weekStart)!;
      return DateTime(start.year, start.month, start.day + 7);
    case ResetCycle.monthly:
      return DateTime(day.year, day.month + 1, 1);
  }
}
