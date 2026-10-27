import 'package:flutter_test/flutter_test.dart';
import 'package:dailyq/domain/models.dart';
import 'package:dailyq/domain/period.dart';
import 'package:dailyq/domain/rules.dart';
import 'package:dailyq/domain/stats.dart';

HabitEvent makeEvent({
  String id = 'e1',
  MetricType type = MetricType.count,
  ResetCycle cycle = ResetCycle.daily,
  double? target = 1,
  double step = 1,
  int dailyLimit = 0,
  DateTime? startDate,
  bool archived = false,
}) {
  return HabitEvent(
    id: id,
    name: '测试事件',
    emoji: '🍀',
    colorValue: 0xFF4FB286,
    metricType: type,
    resetCycle: cycle,
    target: target,
    step: step,
    dailyLimit: dailyLimit,
    startDate: startDate ?? DateTime(2026, 1, 1),
    archived: archived,
  );
}

LogEntry makeLog({
  String id = 'l1',
  String eventId = 'e1',
  required DateTime at,
  double value = 1,
  DateTime? deletedAt,
}) {
  return LogEntry(
    id: id,
    eventId: eventId,
    occurredAt: at,
    dayKey: toDayKey(at),
    value: value,
    deletedAt: deletedAt,
  );
}

void main() {
  group('periodStart · SYS-R-02', () {
    test('daily 从当天 00:00 开始', () {
      final now = DateTime(2026, 10, 21, 13, 0);
      expect(periodStart(ResetCycle.daily, now), DateTime(2026, 10, 21));
    });

    test('weekly 周三回落到本周一', () {
      final now = DateTime(2026, 10, 21, 13, 0);
      expect(periodStart(ResetCycle.weekly, now), DateTime(2026, 10, 19));
    });

    test('weekly 周一零点仍是本周一', () {
      final now = DateTime(2026, 10, 19);
      expect(periodStart(ResetCycle.weekly, now), DateTime(2026, 10, 19));
    });

    test('weekly 周日夜里属于上一周（周一为起点）', () {
      final now = DateTime(2026, 10, 18, 23, 59);
      expect(periodStart(ResetCycle.weekly, now), DateTime(2026, 10, 12));
    });

    test('weekly 周日起点配置生效', () {
      final now = DateTime(2026, 10, 21);
      expect(periodStart(ResetCycle.weekly, now, weekStart: 0), DateTime(2026, 10, 18));
    });

    test('monthly 从当月 1 日 00:00 开始', () {
      final now = DateTime(2026, 10, 21);
      expect(periodStart(ResetCycle.monthly, now), DateTime(2026, 10, 1));
    });

    test('none 返回 null', () {
      expect(periodStart(ResetCycle.none, DateTime(2026, 10, 21)), isNull);
    });

    test('cross-month：3 月 1 日不会回到 2 月', () {
      final now = DateTime(2026, 3, 1, 8, 0);
      expect(periodStart(ResetCycle.daily, now), DateTime(2026, 3, 1));
      expect(periodStart(ResetCycle.monthly, now), DateTime(2026, 3, 1));
    });
  });

  group('归属与聚合 · SYS-R-01 / SYS-R-03', () {
    test('23:50 的记录归属前一天，不计入次日 daily', () {
      final now = DateTime(2026, 10, 21, 0, 10);
      final log = makeLog(at: DateTime(2026, 10, 20, 23, 50));
      expect(log.dayKey, '2026-10-20');
      expect(currentValue(makeEvent(), [log], now), 0);
    });

    test('daily 周期内三条记录累加为 4', () {
      final now = DateTime(2026, 10, 21, 18);
      final logs = [
        makeLog(id: 'a', at: DateTime(2026, 10, 21, 9), value: 1),
        makeLog(id: 'b', at: DateTime(2026, 10, 21, 12), value: 1),
        makeLog(id: 'c', at: DateTime(2026, 10, 21, 15), value: 2),
      ];
      expect(currentValue(makeEvent(), logs, now), 4);
    });

    test('周期起点前 1 分钟的记录不计入', () {
      final now = DateTime(2026, 10, 21, 9);
      final logs = [makeLog(at: DateTime(2026, 10, 20, 23, 59), value: 5)];
      expect(currentValue(makeEvent(), logs, now), 0);
    });

    test('软删除的记录不计入', () {
      final now = DateTime(2026, 10, 21, 12);
      final logs = [
        makeLog(id: 'a', at: DateTime(2026, 10, 21, 9), value: 3),
        makeLog(id: 'b', at: DateTime(2026, 10, 21, 10), value: 2, deletedAt: DateTime(2026, 10, 21, 11)),
      ];
      expect(currentValue(makeEvent(), logs, now), 3);
    });

    test('重复 id 的记录只保留一条', () {
      final at = DateTime(2026, 10, 21, 9);
      final logs = [
        makeLog(id: 'same', at: at, value: 1),
        makeLog(id: 'same', at: at, value: 1),
      ];
      expect(dedupeLogs(logs).length, 1);
    });
  });

  group('达成态 · SYS-R-04', () {
    test('无记录时不算达成', () {
      expect(achievementOf(makeEvent(target: 1), 0), Achievement.none);
    });

    test('部分达成', () {
      expect(achievementOf(makeEvent(type: MetricType.duration, target: 30), 25), Achievement.partial);
      expect(progressRatio(makeEvent(target: 30), 25), closeTo(0.8333, 0.001));
    });

    test('刚好达成', () {
      expect(achievementOf(makeEvent(target: 1), 1), Achievement.done);
      expect(progressRatio(makeEvent(target: 1), 1), 1);
    });

    test('超额时比例为 1', () {
      expect(achievementOf(makeEvent(target: 1), 3), Achievement.over);
      expect(progressRatio(makeEvent(target: 1), 3), 1);
    });

    test('无目标时不判定达成', () {
      expect(achievementOf(makeEvent(target: null), 7), Achievement.none);
      expect(progressRatio(makeEvent(target: null), 7), 0);
    });
  });

  group('记录拦截 · SYS-R-09 / LOG-R-07 / LOG-R-08', () {
    final now = DateTime(2026, 10, 21, 12);

    test('达到日上限后拦截', () {
      final event = makeEvent(dailyLimit: 1);
      final logs = [makeLog(at: DateTime(2026, 10, 21, 9))];
      expect(checkCanLog(event, logs, now, now), LogBlock.limit);
    });

    test('上限为 0 表示不限', () {
      final event = makeEvent(dailyLimit: 0);
      final logs = List.generate(5, (i) => makeLog(id: 'l$i', at: DateTime(2026, 10, 21, 9)));
      expect(checkCanLog(event, logs, now, now), isNull);
    });

    test('未来时间被拦截', () {
      final event = makeEvent();
      expect(checkCanLog(event, const [], now.add(const Duration(minutes: 2)), now), LogBlock.future);
    });

    test('超过 30 天补记窗口被拦截', () {
      final event = makeEvent();
      expect(checkCanLog(event, const [], now.subtract(const Duration(days: 31)), now), LogBlock.tooOld);
    });

    test('昨天已有记录不影响今天（按归属日计）', () {
      final event = makeEvent(dailyLimit: 1);
      final logs = [makeLog(at: DateTime(2026, 10, 20, 9))];
      expect(checkCanLog(event, logs, DateTime(2026, 10, 21, 10), now), isNull);
    });
  });

  group('首页可见性 · HOME / SYS-R-10', () {
    final now = DateTime(2026, 10, 21, 12);

    test('普通事件：所有可见、今日可见、归档不可见', () {
      final e = makeEvent(cycle: ResetCycle.daily);
      expect(isVisibleOnHome(e, HomeFilter.all, now), isTrue);
      expect(isVisibleOnHome(e, HomeFilter.today, now), isTrue);
      expect(isVisibleOnHome(e, HomeFilter.archived, now), isFalse);
    });

    test('归档事件只在已归档出现', () {
      final e = makeEvent(archived: true);
      expect(isVisibleOnHome(e, HomeFilter.all, now), isFalse);
      expect(isVisibleOnHome(e, HomeFilter.archived, now), isTrue);
    });

    test('明天才开始的事件不出现在今日', () {
      final e = makeEvent(cycle: ResetCycle.daily, startDate: DateTime(2026, 10, 22));
      expect(isVisibleOnHome(e, HomeFilter.all, now), isTrue);
      expect(isVisibleOnHome(e, HomeFilter.today, now), isFalse);
    });

    test('每月重置的事件不出现在今日', () {
      final e = makeEvent(cycle: ResetCycle.monthly);
      expect(isVisibleOnHome(e, HomeFilter.today, now), isFalse);
    });
  });

  group('展示格式', () {
    test('圆圈数字缩写', () {
      expect(shortNumber(0), '0');
      expect(shortNumber(250), '250');
      expect(shortNumber(2000), '2k');
      expect(shortNumber(12000), '12k');
    });

    test('完整数字带千分位', () {
      expect(fullNumber(2000), '2,000');
      expect(fullNumber(999), '999');
    });
  });

  group('按日聚合与连续天数 · 详情页', () {
    final now = DateTime(2026, 10, 21, 10);

    test('同一天多条记录累加', () {
      final logs = [
        makeLog(id: 'a', at: DateTime(2026, 10, 21, 9), value: 2),
        makeLog(id: 'b', at: DateTime(2026, 10, 21, 15), value: 3),
        makeLog(id: 'c', at: DateTime(2026, 10, 20, 9), value: 1),
      ];
      final sums = dailySums(logs, 'e1');
      expect(sums['2026-10-21'], 5);
      expect(sums['2026-10-20'], 1);
    });

    test('连续三天达成', () {
      final logs = [
        makeLog(id: 'a', at: DateTime(2026, 10, 21, 9)),
        makeLog(id: 'b', at: DateTime(2026, 10, 20, 9)),
        makeLog(id: 'c', at: DateTime(2026, 10, 19, 9)),
      ];
      expect(streakOf(makeEvent(), logs, now), 3);
    });

    test('今天还没记录时，从昨天开始数', () {
      final logs = [
        makeLog(id: 'a', at: DateTime(2026, 10, 20, 9)),
        makeLog(id: 'b', at: DateTime(2026, 10, 19, 9)),
      ];
      expect(streakOf(makeEvent(), logs, now), 2);
    });

    test('昨天断档则连续归零', () {
      final logs = [makeLog(id: 'a', at: DateTime(2026, 10, 19, 9))];
      expect(streakOf(makeEvent(), logs, now), 0);
    });

    test('无目标事件按「有记录」计连续', () {
      final event = makeEvent(target: null);
      final logs = [
        makeLog(id: 'a', at: DateTime(2026, 10, 21, 9)),
        makeLog(id: 'b', at: DateTime(2026, 10, 20, 9)),
      ];
      expect(streakOf(event, logs, now), 2);
    });

    test('软删除的记录不参与连续计算', () {
      final logs = [
        makeLog(id: 'a', at: DateTime(2026, 10, 21, 9)),
        makeLog(id: 'b', at: DateTime(2026, 10, 20, 9), deletedAt: DateTime(2026, 10, 20, 10)),
      ];
      expect(streakOf(makeEvent(), logs, now), 1);
    });

    test('达标判定：无目标有记录即算，有目标需达标', () {
      expect(reachedTargetOn(makeEvent(target: null), 1), isTrue);
      expect(reachedTargetOn(makeEvent(target: 5), 4), isFalse);
      expect(reachedTargetOn(makeEvent(target: 5), 5), isTrue);
      expect(reachedTargetOn(makeEvent(target: 5), 0), isFalse);
    });

    test('记录流水按时间倒序且排除软删除', () {
      final logs = [
        makeLog(id: 'a', at: DateTime(2026, 10, 19, 9)),
        makeLog(id: 'b', at: DateTime(2026, 10, 21, 9)),
        makeLog(id: 'c', at: DateTime(2026, 10, 20, 9), deletedAt: DateTime(2026, 10, 21)),
      ];
      final list = logsOf(logs, 'e1');
      expect(list.length, 2);
      expect(list.first.id, 'b');
    });
  });

  test('WK-01 指定星期的事件只在该星期进入今日', () {
    final e = HabitEvent(
      id: 'wk',
      name: '晨跑',
      emoji: '🏃',
      colorValue: 0xFF5C93E8,
      metricType: MetricType.count,
      resetCycle: ResetCycle.daily,
      startDate: DateTime(2026, 10, 1),
      weekdays: const [DateTime.monday, DateTime.wednesday],
    );
    expect(isVisibleOnHome(e, HomeFilter.today, DateTime(2026, 10, 19)), isTrue); // 周一
    expect(isVisibleOnHome(e, HomeFilter.today, DateTime(2026, 10, 21)), isTrue); // 周三
    expect(isVisibleOnHome(e, HomeFilter.today, DateTime(2026, 10, 20)), isFalse); // 周二
    // 「所有」不受星期限制，避免事件看起来消失了
    expect(isVisibleOnHome(e, HomeFilter.all, DateTime(2026, 10, 20)), isTrue);
  });

  test('WK-02 未指定星期视为每天', () {
    final e = HabitEvent(
      id: 'wk2',
      name: '喝水',
      emoji: '💧',
      colorValue: 0xFF9B7BE0,
      metricType: MetricType.value,
      resetCycle: ResetCycle.daily,
      startDate: DateTime(2026, 10, 1),
    );
    for (var d = 19; d <= 25; d++) {
      expect(isVisibleOnHome(e, HomeFilter.today, DateTime(2026, 10, d)), isTrue);
    }
    expect(e.weekdayLabel, '每天');
  });
}
