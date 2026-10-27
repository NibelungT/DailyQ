import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../copy.dart';
import '../../data/store.dart';
import '../../domain/models.dart';
import '../../domain/stats.dart';
import '../../ui/widgets.dart';
import '../event/event_detail_page.dart';
import '../event/event_form_page.dart';
import '../record/record_sheet.dart';
import '../settings/settings_page.dart';
import '../stats/stats_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// 进入首页默认看「今日」。
  HomeFilter _filter = HomeFilter.today;

  /// 当前选中的分组；null 表示不按分组过滤。
  String? _group;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final groups = store.groups;
    final events = store
        .visible(_filter)
        .where((e) => _group == null || e.groupId?.trim() == _group)
        .toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      Copy.appName,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
                _FilterBar(
                  filter: _filter,
                  group: _group,
                  groups: groups,
                  onChanged: (f) => setState(() {
                    _filter = f;
                    _group = null;
                  }),
                  onGroup: (g) => setState(() {
                    _group = g;
                    _filter = HomeFilter.all;
                  }),
                  onNew: () => _openForm(context),
                ),
                if (store.reminderVisible && store.pendingTodayCount > 0)
                  _ReminderBar(
                    count: store.pendingTodayCount,
                    onDismiss: store.dismissReminderToday,
                  ),
                Expanded(
                  child: events.isEmpty
                      ? _EmptyState(
                          filter: _filter,
                          group: _group,
                          onCreate: () => _openForm(context),
                          onClearGroup: () => setState(() => _group = null),
                          onShowAll: () => setState(() {
                            _filter = HomeFilter.all;
                            _group = null;
                          }),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
                          itemCount: events.length,
                          itemBuilder: (context, i) {
                            final e = events[i];
                            return EventCard(
                              event: e,
                              current: store.currentOf(e),
                              onTap: () => _openRecord(context, e),
                              onCircleTap: () => _onCircleTap(context, e),
                              onLongPress: () => _openActions(context, e),
                            );
                          },
                        ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomBar(
                onStats: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const StatsPage()),
                ),
                onNew: () => _openForm(context),
                onMore: () => _openMore(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openForm(BuildContext context, {HabitEvent? event}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => EventFormPage(event: event)),
    );
  }

  Future<void> _openRecord(BuildContext context, HabitEvent event) async {
    final store = StoreScope.of(context);
    final result = await showModalBottomSheet<LogOutcome>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => RecordSheet(eventId: event.id),
    );
    if (result == null || !result.ok || !context.mounted) return;
    showUndoSnack(context, _messageFor(event, store.currentOf(event)),
        () => store.undoLog(result.logId!));
  }

  String _messageFor(HabitEvent event, double current) {
    final state = achievementOf(event, current);
    if (state == Achievement.done || state == Achievement.over) {
      return Copy.completed(event.name);
    }
    return Copy.recorded(
      event.hasTarget
          ? '${fullNumber(current)}/${fullNumber(event.target!)}'
          : '${fullNumber(current)} ${event.unit}',
    );
  }

  void _onCircleTap(BuildContext context, HabitEvent event) {
    final store = StoreScope.of(context);
    if (!event.quickLog) {
      _openRecord(context, event);
      return;
    }
    final outcome = store.quickLog(event.id);
    if (!outcome.ok) {
      showToast(context, _blockMessage(outcome.block, event));
      return;
    }
    HapticFeedback.lightImpact();
    showUndoSnack(context, _messageFor(event, store.currentOf(event)),
        () => store.undoLog(outcome.logId!));
  }

  void _openActions(BuildContext context, HabitEvent event) {
    final store = StoreScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (sheetContext) => SheetShell(
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetGrabber(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    Text(event.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              _ActionTile(
                label: '查看详情',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EventDetailPage(eventId: event.id),
                    ),
                  );
                },
              ),
              _ActionTile(
                label: '编辑事件',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openForm(context, event: event);
                },
              ),
              _ActionTile(
                label: event.archived ? '恢复到首页' : '归档到「已归档」',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  store.setArchived(event.id, !event.archived);
                  showToast(
                    context,
                    event.archived ? Copy.restored(event.name) : Copy.movedToArchive(event.name),
                  );
                },
              ),
              _ActionTile(
                label: '置顶',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  store.pin(event.id);
                  showToast(context, Copy.pinned);
                },
              ),
              _ActionTile(
                label: '删除事件',
                danger: true,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmDelete(context, event, store);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, HabitEvent event, AppStore store) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除事件', style: TextStyle(fontSize: 16)),
        content: Text(
          '将同时删除「${event.name}」下的所有记录，此操作不可恢复。',
          style: const TextStyle(fontSize: 13.5, color: AppColors.muted, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(Copy.cancel, style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              store.removeEvent(event.id);
              await store.flush();
              if (!context.mounted) return;
              showToast(context, Copy.deletedEvent(event.name));
            },
            child: const Text(Copy.delete, style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _openMore(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
    );
  }

  String _blockMessage(LogBlock? block, HabitEvent event) => switch (block) {
        LogBlock.limit => Copy.limitReached(event.dailyLimit),
        LogBlock.future => Copy.futureBlocked,
        LogBlock.tooOld => Copy.tooOldBlocked,
        null => '',
      };
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.group,
    required this.groups,
    required this.onChanged,
    required this.onGroup,
    required this.onNew,
  });

  final HomeFilter filter;
  final String? group;
  final List<String> groups;
  final ValueChanged<HomeFilter> onChanged;
  final ValueChanged<String> onGroup;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          AppChip(
            label: Copy.filterAll,
            selected: filter == HomeFilter.all && group == null,
            onTap: () => onChanged(HomeFilter.all),
          ),
          const SizedBox(width: 8),
          AppChip(
            label: Copy.filterToday,
            selected: filter == HomeFilter.today && group == null,
            onTap: () => onChanged(HomeFilter.today),
          ),
          const SizedBox(width: 8),
          AppChip(
            label: Copy.filterArchived,
            selected: filter == HomeFilter.archived && group == null,
            onTap: () => onChanged(HomeFilter.archived),
          ),
          if (groups.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Container(width: 1, height: 18, color: const Color(0xFF2A2F39)),
              ),
            ),
            for (final name in groups) ...[
              AppChip(
                label: name,
                selected: group == name,
                ghost: group != name,
                onTap: () => onGroup(name),
              ),
              const SizedBox(width: 8),
            ],
          ],
          const SizedBox(width: 8),
          AppChip(label: Copy.filterNew, selected: false, ghost: true, onTap: onNew),
        ],
      ),
    );
  }
}

class _ReminderBar extends StatelessWidget {
  const _ReminderBar({required this.count, required this.onDismiss});

  final int count;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1A2113),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        border: Border(left: BorderSide(color: AppColors.accent, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '还有 $count 件事没完成，别断了',
              style: const TextStyle(fontSize: 13, color: Color(0xFFC9D8A8)),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF7E8C63)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onStats, required this.onNew, required this.onMore});

  final VoidCallback onStats;
  final VoidCallback onNew;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.fromLTRB(34, 0, 34, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00090A0D), Color(0xEB090A0D), Color(0xFF090A0D)],
          stops: [0, 0.42, 1],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RoundIconButton(
            icon: Icons.bar_chart_rounded,
            onTap: onStats,
            size: 46,
            background: const Color(0xFF1B1E24),
            color: const Color(0xFFAEB7C5),
          ),
          GestureDetector(
            onTap: onNew,
            child: Container(
              width: 62,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E24),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 20, offset: Offset(0, 6))],
              ),
              child: const Icon(Icons.add_rounded, color: Color(0xFFE8ECF2), size: 24),
            ),
          ),
          RoundIconButton(
            icon: Icons.grid_view_rounded,
            onTap: onMore,
            size: 46,
            background: const Color(0xFF1B1E24),
            color: const Color(0xFFAEB7C5),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.filter,
    required this.group,
    required this.onCreate,
    required this.onClearGroup,
    required this.onShowAll,
  });

  final HomeFilter filter;
  final String? group;
  final VoidCallback onCreate;
  final VoidCallback onClearGroup;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final archived = filter == HomeFilter.archived;
    final today = filter == HomeFilter.today;
    final inGroup = group != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              inGroup ? '🏷️' : (archived ? '🗂️' : (today ? '☀️' : '🌱')),
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(height: 12),
            Text(
              inGroup
                  ? '「$group」下还没有事件'
                  : (archived
                      ? Copy.emptyArchived
                      : (today ? Copy.emptyToday : Copy.emptyHomeTitle)),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            if (!archived) ...[
              const SizedBox(height: 20),
              PrimaryButton(
                label: inGroup ? '查看全部分组' : (today ? '查看全部' : Copy.emptyHomeAction),
                height: 46,
                onPressed: inGroup
                    ? onClearGroup
                    : (today ? onShowAll : onCreate),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EventCard extends StatefulWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.current,
    required this.onTap,
    required this.onCircleTap,
    required this.onLongPress,
  });

  final HabitEvent event;
  final double current;
  final VoidCallback onTap;
  final VoidCallback onCircleTap;
  final VoidCallback onLongPress;

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final current = widget.current;
    final done = achievementOf(e, current) == Achievement.done ||
        achievementOf(e, current) == Achievement.over;
    final ratio = progressRatio(e, current);
    final color = Color(e.colorValue);

    final subtitle = <String>[
      e.metricType.label,
      if (e.resetCycle != ResetCycle.none) '重置：${e.resetCycle.label}',
      if (e.hasTarget)
        '${fullNumber(current)}/${fullNumber(e.target!)}'
      else
        '${fullNumber(current)} ${e.unit}',
    ];

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          decoration: BoxDecoration(
            color: _pressed ? const Color(0xFF171A20) : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(e.emoji, style: const TextStyle(fontSize: 17)),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            e.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subtitle.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                    if (e.hasTarget) ...[
                      const SizedBox(height: 13),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 5,
                          child: Stack(
                            children: [
                              Container(color: AppColors.track),
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0, end: ratio),
                                duration: AppDuration.progress,
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) => FractionallySizedBox(
                                  widthFactor: value,
                                  child: Container(color: color),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _CountCircle(
                key: ValueKey('circle_${e.id}'),
                color: color,
                value: current,
                done: done,
                showCheck: e.showCheck && done,
                onTap: widget.onCircleTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountCircle extends StatelessWidget {
  const _CountCircle({
    super.key,
    required this.color,
    required this.value,
    required this.done,
    required this.showCheck,
    required this.onTap,
  });

  final Color color;
  final double value;
  final bool done;
  final bool showCheck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = shortNumber(value);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(value),
        tween: Tween<double>(begin: 1.12, end: 1),
        duration: AppDuration.pop,
        curve: Curves.easeOutBack,
        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
        child: SizedBox(
          width: 62,
          height: 62,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? color : color.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: inkFor(color),
                    fontSize: text.length >= 3 ? 24 : 29,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
              ),
              if (showCheck)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(color: Color(0xFF0B0D10), shape: BoxShape.circle),
                    child: Icon(Icons.check_rounded, size: 13, color: color),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.label, required this.onTap, this.danger = false});

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 17),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: danger ? AppColors.danger : AppColors.text,
          ),
        ),
      ),
    );
  }
}
