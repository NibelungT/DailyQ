import 'package:flutter/material.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../copy.dart';
import '../../data/store.dart';
import '../../domain/models.dart';
import '../../domain/period.dart';
import '../../domain/stats.dart';
import '../../ui/widgets.dart';
import '../event/event_detail_page.dart';

class _Cell {
  const _Cell(this.start, this.end, [this.label]);

  final DateTime start;
  final DateTime end;
  final String? label;
}

class _Range {
  const _Range({required this.label, required this.cells, required this.compact});

  final String label;
  final List<_Cell> cells;

  /// true = 小圆点密集模式（日/月/年）
  final bool compact;
}

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  static const _tabs = ['日', '周', '月', '年'];

  int _tab = 1;
  int _offset = 0;
  int _sort = 0;
  String _group = '全部';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(store),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Row(
                children: [
                  Expanded(child: _summary('${store.totalLogs}', Copy.statTotalCount)),
                  const SizedBox(width: 12),
                  Expanded(child: _summary('${store.totalDays}', Copy.statTotalDays)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppSegmented(
                labels: _tabs,
                index: _tab,
                onChanged: (i) => setState(() {
                  _tab = i;
                  _offset = 0;
                }),
              ),
            ),
            const SizedBox(height: 14),
            _periodBar(),
            Expanded(child: _list(store)),
          ],
        ),
      ),
    );
  }

  Widget _header(AppStore store) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
      child: Row(
        children: [
          RoundIconButton(icon: Icons.close_rounded, onTap: () => Navigator.of(context).pop()),
          const Expanded(
            child: Center(
              child: Text('统计', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
          ),
          RoundIconButton(icon: Icons.swap_vert_rounded, onTap: _pickSort),
          RoundIconButton(icon: Icons.filter_alt_outlined, onTap: _pickGroup),
          RoundIconButton(icon: Icons.delete_outline_rounded, onTap: () => _confirmClear(store)),
        ],
      ),
    );
  }

  Widget _summary(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.control + 4),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _periodBar() {
    final store = StoreScope.of(context);
    final range = _range(store.now, store.weekStart);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RoundIconButton(
            icon: Icons.chevron_left_rounded,
            onTap: () => setState(() => _offset--),
            size: 34,
            iconSize: 20,
            color: const Color(0xFFB7C0CE),
          ),
          Text(range.label, style: const TextStyle(fontSize: 14, color: Color(0xFFB7C0CE))),
          RoundIconButton(
            icon: Icons.chevron_right_rounded,
            onTap: () {
              if (_offset >= 0) {
                showToast(context, Copy.cannotFuture);
                return;
              }
              setState(() => _offset++);
            },
            size: 34,
            iconSize: 20,
            color: const Color(0xFFB7C0CE),
          ),
        ],
      ),
    );
  }

  Widget _list(AppStore store) {
    final range = _range(store.now, store.weekStart);
    var events = store.events.where((e) => !e.archived).toList();
    if (_group != '全部') {
      events = events.where((e) => e.groupId == _group).toList();
    }
    if (_sort == 1) {
      events.sort((a, b) => a.name.compareTo(b.name));
    } else if (_sort == 2) {
      events.sort((a, b) => _rowTotal(store, a, range).compareTo(_rowTotal(store, b, range)));
      events = events.reversed.toList();
    }

    if (events.isEmpty) {
      return const Center(
        child: Text(Copy.emptyStats, style: TextStyle(color: AppColors.muted, fontSize: 14)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
      itemCount: events.length,
      itemBuilder: (context, i) {
        final e = events[i];
        return _statRow(store, e, range);
      },
    );
  }

  double _rowTotal(AppStore store, HabitEvent e, _Range range) {
    var total = 0.0;
    for (final c in range.cells) {
      total += sumValue(store.logs, e.id, from: c.start, to: c.end);
    }
    return total;
  }

  Widget _statRow(AppStore store, HabitEvent e, _Range range) {
    final color = Color(e.colorValue);
    final total = _rowTotal(store, e, range);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => EventDetailPage(eventId: e.id)),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${e.emoji} ${e.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text('X${fullNumber(total)}',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _dots(store, e, range, color),
          ],
        ),
      ),
    );
  }

  Widget _dots(AppStore store, HabitEvent e, _Range range, Color color) {
    if (!range.compact) {
      return SizedBox(
        width: 155,
        child: Row(
          spacing: 6,
          mainAxisAlignment: MainAxisAlignment.end,
          children: range.cells.map((c) {
            final v = sumValue(store.logs, e.id, from: c.start, to: c.end);
            return Column(
              children: [
                _dot(v, e, color, 17),
                const SizedBox(height: 6),
                Text(
                  c.label ?? '',
                  style: const TextStyle(fontSize: 9, color: Color(0xFF525A68), height: 1),
                ),
              ],
            );
          }).toList(),
        ),
      );
    }

    return SizedBox(
      width: 132,
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        alignment: WrapAlignment.end,
        children: range.cells.map((c) {
          final v = sumValue(store.logs, e.id, from: c.start, to: c.end);
          return _dot(v, e, color, 8);
        }).toList(),
      ),
    );
  }

  Widget _dot(double value, HabitEvent e, Color color, double size) {
    Color fill;
    if (value <= 0) {
      fill = const Color(0xFF282C34);
    } else {
      final ratio = e.hasTarget ? (value / e.target!).clamp(0.0, 1.0) : 1.0;
      fill = color.withValues(alpha: 0.35 + 0.65 * ratio);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
    );
  }

  _Range _range(DateTime now, int weekStart) {
    final today = dateOnly(now);
    switch (_tab) {
      case 0:
        final day = DateTime(today.year, today.month, today.day + _offset);
        final cells = List.generate(24, (h) {
          final start = DateTime(day.year, day.month, day.day, h);
          return _Cell(start, start.add(const Duration(hours: 1)));
        });
        const names = ['一', '二', '三', '四', '五', '六', '日'];
        return _Range(
          label: '${day.month}-${day.day.toString().padLeft(2, '0')} 周${names[day.weekday - 1]}',
          cells: cells,
          compact: true,
        );
      case 1:
        final start = periodStart(ResetCycle.weekly, today, weekStart: weekStart)!;
        final weekStartDate = DateTime(start.year, start.month, start.day + _offset * 7);
        const names = ['日', '一', '二', '三', '四', '五', '六'];
        final cells = List.generate(7, (i) {
          final s = DateTime(weekStartDate.year, weekStartDate.month, weekStartDate.day + i);
          return _Cell(s, DateTime(s.year, s.month, s.day + 1), names[(weekStart + i) % 7]);
        });
        final end = DateTime(weekStartDate.year, weekStartDate.month, weekStartDate.day + 6);
        return _Range(
          label: '${_md(weekStartDate)} ~ ${_md(end)}',
          cells: cells,
          compact: false,
        );
      case 2:
        final first = DateTime(today.year, today.month + _offset, 1);
        final days = DateTime(first.year, first.month + 1, 0).day;
        final cells = List.generate(days, (i) {
          final s = DateTime(first.year, first.month, first.day + i);
          return _Cell(s, DateTime(s.year, s.month, s.day + 1));
        });
        return _Range(
          label: '${first.year}-${first.month.toString().padLeft(2, '0')}',
          cells: cells,
          compact: true,
        );
      default:
        final year = today.year + _offset;
        final cells = List.generate(12, (m) {
          return _Cell(DateTime(year, m + 1, 1), DateTime(year, m + 2, 1));
        });
        return _Range(label: '$year', cells: cells, compact: true);
    }
  }

  String _md(DateTime d) => '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickSort() async {
    const options = ['按默认顺序', '按名称', '按本期累计'];
    final v = await _pick('排序方式', options, options[_sort]);
    if (v == null) return;
    setState(() => _sort = options.indexOf(v));
  }

  Future<void> _pickGroup() async {
    final groups = <String>['全部'];
    for (final e in StoreScope.of(context).events) {
      final g = e.groupId;
      if (g != null && !groups.contains(g)) groups.add(g);
    }
    final v = await _pick('按分组筛选', groups, _group);
    if (v == null) return;
    setState(() => _group = v);
  }

  Future<String?> _pick(String title, List<String> options, String current) {
    return showModalBottomSheet<String>(
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
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              ...options.map((o) {
                return GestureDetector(
                  onTap: () => Navigator.of(sheetContext).pop(o),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.line)),
                    ),
                    child: Row(
                      children: [
                        Text(o, style: const TextStyle(fontSize: 15)),
                        const Spacer(),
                        if (o == current)
                          const Icon(Icons.check_rounded, size: 18, color: AppColors.accent),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClear(AppStore store) {
    if (store.totalLogs == 0) {
      showToast(context, Copy.clearedNoData);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空所有记录', style: TextStyle(fontSize: 16)),
        content: Text(
          Copy.clearConfirm(store.totalLogs),
          style: const TextStyle(fontSize: 13.5, color: AppColors.muted, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(Copy.cancel, style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              store.clearLogs();
              showToast(context, Copy.cleared);
            },
            child: const Text('清空', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}
