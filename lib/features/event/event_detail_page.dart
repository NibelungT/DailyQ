import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../copy.dart';
import '../../data/store.dart';
import '../../domain/models.dart';
import '../../domain/period.dart';
import '../../domain/rules.dart';
import '../../domain/stats.dart';
import '../../ui/widgets.dart';
import '../record/record_sheet.dart';
import 'event_form_page.dart';

class EventDetailPage extends StatefulWidget {
  const EventDetailPage({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final event = store.eventById(widget.eventId);
    if (event == null) {
      return const Scaffold(
        body: Center(
          child: Text('事件已删除', style: TextStyle(color: AppColors.muted)),
        ),
      );
    }

    final current = store.currentOf(event);
    final streak = store.streakForEvent(event.id);
    final color = Color(event.colorValue);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(event),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                children: [
                  _hero(event, current, streak, color),
                  const SizedBox(height: 14),
                  _calendar(store, event, color),
                  const SizedBox(height: 14),
                  _rules(event),
                  const SizedBox(height: 14),
                  _logs(store, event, color),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomBar(event, store, color),
    );
  }

  Widget _header(HabitEvent event) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            iconSize: 18,
            onTap: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Center(
              child: Text('事件详情', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
          ),
          RoundIconButton(
            icon: Icons.edit_outlined,
            iconSize: 19,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => EventFormPage(event: event)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(HabitEvent event, double current, int streak, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(event.emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        event.metricType.label,
                        '重置：${event.resetCycle.label}'
                        '${event.resetCycle == ResetCycle.daily && event.weekdays.isNotEmpty ? ' · ${event.weekdayLabel}' : ''}',
                        event.hasTarget
                            ? '目标 ${fullNumber(event.target!)} ${event.unit}'
                            : '不设目标',
                      ].join(' · '),
                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _metric('连续', '$streak', '天'),
              const SizedBox(width: 12),
              _metric('本周期', fullNumber(current), event.unit),
            ],
          ),
          if (event.desc.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              event.desc,
              style: const TextStyle(fontSize: 12.5, color: AppColors.dim, height: 1.6),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(String label, String value, String unit) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardAlt,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 4),
                Text(unit, style: const TextStyle(fontSize: 11.5, color: AppColors.dim)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _calendar(AppStore store, HabitEvent event, Color color) {
    final now = store.now;
    final today = DateTime(now.year, now.month, now.day);
    final first = DateTime(_month.year, _month.month, 1);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = (first.weekday % 7 - store.weekStart) % 7;
    final sums = dailySums(store.logs, event.id);

    final canGoNext = DateTime(_month.year, _month.month + 1, 1).isBefore(
      DateTime(today.year, today.month + 1, 1),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('打卡日历', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
              const Spacer(),
              RoundIconButton(
                icon: Icons.chevron_left_rounded,
                size: 30,
                iconSize: 18,
                onTap: () => setState(() => _month = DateTime(_month.year, _month.month - 1, 1)),
              ),
              Text(
                '${_month.year}-${_month.month.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 13, color: Color(0xFFB7C0CE)),
              ),
              RoundIconButton(
                icon: Icons.chevron_right_rounded,
                size: 30,
                iconSize: 18,
                color: canGoNext ? const Color(0xFFB7C0CE) : AppColors.dim,
                onTap: canGoNext
                    ? () => setState(
                          () => _month = DateTime(_month.year, _month.month + 1, 1),
                        )
                    : () {},
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(7, (i) {
              final index = (store.weekStart + i) % 7;
              const names = ['日', '一', '二', '三', '四', '五', '六'];
              return Expanded(
                child: Center(
                  child: Text(
                    names[index],
                    style: const TextStyle(fontSize: 10, color: AppColors.dim),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (var i = 0; i < leading; i++) const SizedBox.shrink(),
              for (var d = 1; d <= days; d++)
                _dayCell(
                  day: d,
                  date: DateTime(first.year, first.month, d),
                  today: today,
                  value: sums[toDayKey(DateTime(first.year, first.month, d))] ?? 0,
                  event: event,
                  color: color,
                  disabled: DateTime(first.year, first.month, d).isAfter(today) ||
                      DateTime(first.year, first.month, d)
                          .isBefore(dateOnly(event.startDate)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('少', style: TextStyle(fontSize: 10, color: AppColors.dim)),
              const SizedBox(width: 6),
              ...[0.0, 0.4, 0.7, 1.0].map(
                (r) => Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: r == 0 ? const Color(0xFF24282F) : color.withValues(alpha: 0.25 + 0.75 * r),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              const Text('多', style: TextStyle(fontSize: 10, color: AppColors.dim)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCell({
    required int day,
    required DateTime date,
    required DateTime today,
    required double value,
    required HabitEvent event,
    required Color color,
    required bool disabled,
  }) {
    final reached = reachedTargetOn(event, value);
    final ratio = event.hasTarget ? (value / event.target!).clamp(0.0, 1.0) : (value > 0 ? 1.0 : 0.0);
    final isToday = date == today;

    Color bg;
    Color fg;
    if (value <= 0) {
      bg = const Color(0xFF1B1E24);
      fg = disabled ? const Color(0xFF3C434E) : const Color(0xFF6F7889);
    } else {
      bg = color.withValues(alpha: 0.28 + 0.72 * ratio);
      fg = inkFor(bg);
    }

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
        border: isToday ? Border.all(color: AppColors.accent, width: 1.4) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(fontSize: 12, color: fg, fontWeight: reached ? FontWeight.w700 : FontWeight.w400),
          ),
        ],
      ),
    );
  }

  Widget _rules(HabitEvent event) {
    final rows = <List<String>>[
      [Copy.fieldType, event.metricType.label],
      [Copy.fieldTarget, event.hasTarget ? '${fullNumber(event.target!)} ${event.unit}' : Copy.noLimit],
      [Copy.fieldStep, '${trimZero(event.step)} ${event.unit}'],
      [Copy.fieldCycle, event.resetCycle.label],
      if (event.resetCycle == ResetCycle.daily)
        ['重复星期', event.weekdayLabel],
      [Copy.fieldStart, '${event.startDate.year}-${event.startDate.month.toString().padLeft(2, '0')}-${event.startDate.day.toString().padLeft(2, '0')}'],
      [Copy.fieldEnd, event.endDate == null ? Copy.noEndDate : '${event.endDate!.year}-${event.endDate!.month.toString().padLeft(2, '0')}-${event.endDate!.day.toString().padLeft(2, '0')}'],
      [Copy.fieldLimit, event.dailyLimit == 0 ? Copy.noLimit : '${event.dailyLimit} 次'],
      ['快速记录', event.quickLog ? '已开启' : '关闭'],
      ['分组', event.groupId ?? '无'],
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: i == rows.length - 1
                    ? null
                    : const Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  Text(rows[i][0], style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                  const Spacer(),
                  Text(rows[i][1], style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _logs(AppStore store, HabitEvent event, Color color) {
    final list = store.logsForEvent(event.id);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('记录流水', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text('${list.length} 条', style: const TextStyle(fontSize: 12, color: AppColors.dim)),
            ],
          ),
          const SizedBox(height: 8),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('还没有记录', style: TextStyle(fontSize: 13, color: AppColors.dim)),
            )
          else
            for (final log in list.take(30))
              Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.line)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _logTime(log),
                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        log.note.isEmpty ? '—' : log.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.text),
                      ),
                    ),
                    Text(
                      '${trimZero(log.value)} ${event.unit}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    GestureDetector(
                      key: ValueKey('del_${log.id}'),
                      onTap: () => _deleteLog(store, log),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 12, top: 4, bottom: 4),
                        child: Icon(Icons.close_rounded, size: 16, color: AppColors.dim),
                      ),
                    ),
                  ],
                ),
              ),
          if (list.length > 30)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '仅显示最近 30 条',
                style: const TextStyle(fontSize: 11.5, color: AppColors.dim),
              ),
            ),
        ],
      ),
    );
  }

  String _logTime(LogEntry log) {
    final d = log.occurredAt;
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _deleteLog(AppStore store, LogEntry log) {
    store.softDeleteLog(log.id);
    HapticFeedback.lightImpact();
    showUndoSnack(context, '已删除一条记录', () => store.restoreLog(log.id));
  }

  Widget _bottomBar(HabitEvent event, AppStore store, Color color) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        color: AppColors.bg,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  store.setArchived(event.id, !event.archived);
                  Navigator.of(context).pop();
                },
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.cardAlt,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    event.archived ? '恢复' : '归档',
                    style: const TextStyle(fontSize: 15, color: AppColors.muted),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: '记录一次',
                height: 48,
                color: color,
                onPressed: () => _openRecord(event),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRecord(HabitEvent event) async {
    final store = StoreScope.of(context);
    final result = await showModalBottomSheet<LogOutcome>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => RecordSheet(eventId: event.id),
    );
    if (result == null || !result.ok || !mounted) return;
    final current = store.currentOf(event);
    final state = achievementOf(event, current);
    final message = (state == Achievement.done || state == Achievement.over)
        ? Copy.completed(event.name)
        : Copy.recorded(
            event.hasTarget
                ? '${fullNumber(current)}/${fullNumber(event.target!)}'
                : '${fullNumber(current)} ${event.unit}',
          );
    showUndoSnack(context, message, () => store.undoLog(result.logId!));
  }
}
