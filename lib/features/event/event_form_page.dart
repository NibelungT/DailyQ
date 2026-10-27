import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../copy.dart';
import '../../data/store.dart';
import '../../domain/models.dart';
import '../../ui/widgets.dart';

const _emojis = [
  '🍀', '📝', '📖', '💧', '🏃', '🧘', '🎧', '✍️', '💡', '🌱', '☕️', '🎯',
  '🧠', '💪', '🌙', '🍎', '🖥️', '📚', '🏋️', '🚶', '🧹', '💊', '🎹', '🗂️',
];

const _groups = ['无', '学习', '习惯', '健康', '工作'];

class EventFormPage extends StatefulWidget {
  const EventFormPage({super.key, this.event});

  final HabitEvent? event;

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _stepCtrl;

  late String _emoji;
  late int _colorValue;
  late String _group;
  late MetricType _type;
  late String _unit;
  late ResetCycle _cycle;

  /// 每天周期下要触发的星期（1=周一…7=周日），空集合=每天
  late Set<int> _weekdays;
  late bool _quickLog;
  late bool _showCheck;
  late bool _remind;
  late bool _follow;
  late int _dailyLimit;
  late DateTime _startDate;
  DateTime? _endDate;

  bool _dirty = false;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _descCtrl = TextEditingController(text: e?.desc ?? '');
    _targetCtrl = TextEditingController(
      text: e?.target == null ? '' : _trim(e!.target!),
    );
    _stepCtrl = TextEditingController(text: _trim(e?.step ?? 1));
    _emoji = e?.emoji ?? '💪';
    _colorValue = e?.colorValue ?? AppColors.palette[1].toARGB32();
    _group = e?.groupId ?? '无';
    _type = e?.metricType ?? MetricType.count;
    _unit = e?.unit ?? _type.defaultUnit;
    _cycle = e?.resetCycle ?? ResetCycle.daily;
    _weekdays = {...?e?.weekdays};
    _quickLog = e?.quickLog ?? false;
    _showCheck = e?.showCheck ?? true;
    _remind = e?.remind ?? false;
    _follow = e?.follow ?? false;
    _dailyLimit = e?.dailyLimit ?? 0;
    _startDate = e?.startDate ?? DateTime.now();
    _endDate = e?.endDate;
  }

  String _trim(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _targetCtrl.dispose();
    _stepCtrl.dispose();
    super.dispose();
  }

  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                children: [
                  _identityGroup(),
                  const SizedBox(height: 12),
                  _typeGroup(),
                  const SizedBox(height: 12),
                  _metricGroup(),
                  if (_cycle == ResetCycle.daily) ...[
                    const SizedBox(height: 12),
                    _weekdayGroup(),
                  ],
                  const SizedBox(height: 12),
                  _advancedGroup(),
                  const SizedBox(height: 16),
                  _dateGroup(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
      child: Row(
        children: [
          RoundIconButton(icon: Icons.close_rounded, onTap: _handleClose),
          Expanded(
            child: Center(
              child: Text(
                _isEditing ? Copy.editEvent : Copy.newEvent,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          GestureDetector(
            onTap: _save,
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 4),
              decoration: const BoxDecoration(color: AppColors.cyan, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Color(0xFF06131A), size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.control + 4),
      ),
      child: child,
    );
  }

  Widget _row(String label, Widget trailing, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }

  Widget _pickerValue(String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: const TextStyle(fontSize: 15, color: AppColors.muted)),
          const Icon(Icons.chevron_right_rounded, size: 17, color: AppColors.dim),
        ],
      );

  /// 可点的单位胶囊：点开可以选预设或直接输入。
  Widget _unitPill() {
    return GestureDetector(
      onTap: _pickUnit,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 5, 5, 5),
        decoration: BoxDecoration(
          color: AppColors.cardHi,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_unit, style: const TextStyle(fontSize: 12.5, color: Color(0xFFC2CAD6))),
            const Icon(Icons.expand_more_rounded, size: 15, color: AppColors.dim),
          ],
        ),
      ),
    );
  }

  static List<String> _unitPresets(MetricType type) {
    switch (type) {
      case MetricType.count:
        return const ['次', '组', '个', '题', '页', '道', '遍'];
      case MetricType.duration:
        return const ['分钟', '小时', '秒'];
      case MetricType.value:
        return const ['毫升', '杯', '页', '公里', '步', '千卡', '克', '次'];
    }
  }

  Future<void> _pickUnit() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _UnitSheet(initial: _unit, presets: _unitPresets(_type)),
    );
    if (result == null) return;
    setState(() {
      _unit = result.isEmpty ? _type.defaultUnit : result;
      _dirty = true;
    });
  }

  Widget _identityGroup() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _pickEmoji,
                  child: Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF20242C),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(_emoji, style: const TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        onChanged: (_) => _touch(),
                        maxLength: 20,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: Copy.fieldName,
                          hintStyle: TextStyle(color: Color(0xFF596273), fontSize: 17),
                          counterText: '',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                      TextField(
                        controller: _descCtrl,
                        onChanged: (_) => _touch(),
                        maxLength: 40,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF9AA3B2)),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: Copy.fieldDesc,
                          hintStyle: TextStyle(color: Color(0xFF6F7889), fontSize: 13),
                          counterText: '',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: AppColors.palette.map((c) {
              final selected = c.toARGB32() == _colorValue;
              return Padding(
                padding: const EdgeInsets.only(right: 9, bottom: 12, top: 2),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _colorValue = c.toARGB32());
                    _touch();
                  },
                  child: Container(
                    width: 31,
                    height: 31,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                    child: selected
                        ? const Icon(Icons.check_rounded, size: 16, color: Color(0xFF0A1006))
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          Container(height: 1, color: AppColors.line),
          _row(
            Copy.fieldGroup,
            GestureDetector(
              onTap: _pickGroup,
              child: _pickerValue(_group),
            ),
            last: true,
          ),
        ],
      ),
    );
  }

  Widget _typeGroup() {
    return _card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(Copy.fieldType, style: TextStyle(fontSize: 15)),
                const Spacer(),
                Text(
                  _isEditing ? Copy.typeLocked : '决定记录方式与统计口径',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF5F6878)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppSegmented(
              labels: MetricType.values.map((t) => t.label).toList(),
              index: _type.index,
              enabled: !_isEditing,
              onChanged: (i) {
                final next = MetricType.values[i];
                if (next == _type) return;
                setState(() {
                  _type = next;
                  _unit = next.defaultUnit;
                  _stepCtrl.text = _trim(next.defaultStep);
                  _targetCtrl.clear();
                  _dirty = true;
                });
              },
            ),
            if (_isEditing) ...[
              const SizedBox(height: 10),
              Text(
                Copy.typeLocked,
                style: const TextStyle(fontSize: 11.5, color: AppColors.dim),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricGroup() {
    return _card(
      child: Column(
        children: [
          _row(
            Copy.fieldTarget,
            SizedBox(
              width: 190,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _targetCtrl,
                      onChanged: (_) => _touch(),
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 15),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: Copy.optional,
                        hintStyle: TextStyle(color: Color(0xFF596273), fontSize: 15),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _unitPill(),
                ],
              ),
            ),
          ),
          _row(
            Copy.fieldStep,
            SizedBox(
              width: 190,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _stepCtrl,
                      onChanged: (_) => _touch(),
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 15),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _unitPill(),
                ],
              ),
            ),
          ),
          _row(
            Copy.fieldCycle,
            GestureDetector(onTap: _pickCycle, child: _pickerValue(_cycle.label)),
            last: true,
          ),
        ],
      ),
    );
  }

  Widget _advancedGroup() {
    return _card(
      child: Column(
        children: [
          _row(Copy.swRemind, AppSwitch(value: _remind, onChanged: (v) { setState(() => _remind = v); _touch(); })),
          _row(Copy.swFollow, AppSwitch(value: _follow, onChanged: (v) { setState(() => _follow = v); _touch(); })),
          _row(Copy.swQuick, AppSwitch(value: _quickLog, onChanged: (v) { setState(() => _quickLog = v); _touch(); })),
          _row(
            Copy.fieldLimit,
            GestureDetector(
              onTap: _pickLimit,
              child: _pickerValue(_dailyLimit == 0 ? Copy.noLimit : '$_dailyLimit 次'),
            ),
          ),
          _row(
            Copy.swCheck,
            AppSwitch(value: _showCheck, onChanged: (v) { setState(() => _showCheck = v); _touch(); }),
            last: true,
          ),
        ],
      ),
    );
  }

  /// 「每天」周期下选择触发的星期；不选＝每天。
  Widget _weekdayGroup() {
    const names = ['一', '二', '三', '四', '五', '六', '日'];
    return _card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('重复星期', style: TextStyle(fontSize: 15)),
                const Spacer(),
                Text(
                  _weekdays.isEmpty ? '每天' : '每周 ${_weekdays.length} 天',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF5F6878)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 1; i <= 7; i++)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (!_weekdays.add(i)) _weekdays.remove(i);
                        _dirty = true;
                      });
                      _touch();
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _weekdays.contains(i)
                            ? AppColors.accent
                            : const Color(0xFF20242C),
                      ),
                      child: Text(
                        names[i - 1],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _weekdays.contains(i)
                              ? const Color(0xFF0B0D11)
                              : AppColors.muted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              '不选任何一天＝每天；选中后只在选中的星期出现在「今日」',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF5F6878), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateGroup() {    return _card(
      child: Column(
        children: [
          _row(
            Copy.fieldStart,
            GestureDetector(
              onTap: _pickStart,
              child: _pickerValue(_dateLabel(_startDate)),
            ),
          ),
          _row(
            Copy.fieldEnd,
            GestureDetector(
              onTap: _pickEnd,
              child: _pickerValue(_endDate == null ? Copy.noEndDate : _dateLabel(_endDate!)),
            ),
            last: true,
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickEmoji() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (sheetContext) => SheetShell(
        maxHeightFactor: 0.7,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetGrabber(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('选择图标', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: _emojis.map((e) {
                      return GestureDetector(
                        onTap: () {
                          setState(() => _emoji = e);
                          _touch();
                          Navigator.of(sheetContext).pop();
                        },
                        child: Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: e == _emoji ? const Color(0xFF2A2F39) : AppColors.cardAlt,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(e, style: const TextStyle(fontSize: 24)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickGroup() async {
    final v = await _pickFromList('分组', _groups, _group);
    if (v == null) return;
    setState(() => _group = v);
    _touch();
  }

  Future<void> _pickCycle() async {
    final labels = ResetCycle.values.map((c) => c.label).toList();
    final v = await _pickFromList('重置周期', labels, _cycle.label);
    if (v == null) return;
    setState(() => _cycle = ResetCycle.values[labels.indexOf(v)]);
    _touch();
  }

  Future<void> _pickLimit() async {
    const options = ['不限', '1 次', '3 次', '5 次'];
    final current = _dailyLimit == 0 ? '不限' : '$_dailyLimit 次';
    final v = await _pickFromList('日打卡次数上限', options, current);
    if (v == null) return;
    setState(() => _dailyLimit = v == '不限' ? 0 : int.parse(v.split(' ').first));
    _touch();
  }

  Future<String?> _pickFromList(String title, List<String> options, String current) {
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
                final selected = o == current;
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
                        if (selected)
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

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('zh', 'CN'),
    );
    if (picked == null || !mounted) return;
    setState(() => _startDate = picked);
    _touch();
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime(2100),
      locale: const Locale('zh', 'CN'),
    );
    if (picked == null || !mounted) return;
    setState(() => _endDate = picked);
    _touch();
  }

  void _handleClose() {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(Copy.discardEdit, style: TextStyle(fontSize: 16)),
        content: const Text(
          '本次修改不会保存。',
          style: TextStyle(fontSize: 13.5, color: AppColors.muted, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('继续编辑', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: const Text('放弃', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showToast(context, Copy.nameRequired);
      return;
    }
    final targetText = _targetCtrl.text.trim();
    final target = targetText.isEmpty ? null : double.tryParse(targetText);
    if (target != null && target <= 0) {
      showToast(context, Copy.targetPositive);
      return;
    }
    if (_endDate != null && _endDate!.isBefore(_startDate)) {
      showToast(context, Copy.endBeforeStart);
      return;
    }
    final step = double.tryParse(_stepCtrl.text.trim()) ?? _type.defaultStep;

    final store = StoreScope.of(context);
    final existing = widget.event;
    final event = HabitEvent(
      id: existing?.id ?? newId('e'),
      name: name,
      emoji: _emoji,
      colorValue: _colorValue,
      desc: _descCtrl.text.trim(),
      groupId: _group == '无' ? null : _group,
      metricType: _type,
      resetCycle: _cycle,
      weekdays: (_weekdays.toList()..sort()),
      target: target,
      step: step <= 0 ? 1 : step,
      unit: _unit,
      startDate: _startDate,
      endDate: _endDate,
      quickLog: _quickLog,
      dailyLimit: _dailyLimit,
      showCheck: _showCheck,
      archived: existing?.archived ?? false,
      remind: _remind,
      follow: _follow,
      createdAt: existing?.createdAt ?? store.now,
    );
    store.upsertEvent(event);
    // 等真正落盘再退出页面，避免“刚保存就杀进程”导致丢改动
    await store.flush();
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

/// 单位选择：预设 + 自由输入。自带 controller，避免在弹层退场动画中被提前释放。
class _UnitSheet extends StatefulWidget {
  const _UnitSheet({required this.initial, required this.presets});

  final String initial;
  final List<String> presets;

  @override
  State<_UnitSheet> createState() => _UnitSheetState();
}

class _UnitSheetState extends State<_UnitSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      padding: EdgeInsets.only(bottom: insets),
      child: SheetShell(
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetGrabber(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('单位', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.cardAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    maxLength: 6,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '自定义单位，如 组 / 页 / 杯',
                      hintStyle: TextStyle(color: Color(0xFF5A6273), fontSize: 14),
                      counterText: '',
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.presets.map((u) {
                      final active = _ctrl.text.trim() == u;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _ctrl.text = u;
                            _ctrl.selection = TextSelection.collapsed(offset: u.length);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: active ? const Color(0xFF2A2F39) : AppColors.cardAlt,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            u,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: active ? Colors.white : AppColors.muted,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: PrimaryButton(
                  label: '确定',
                  height: 48,
                  onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
