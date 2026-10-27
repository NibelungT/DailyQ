import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../copy.dart';
import '../../domain/models.dart';
import '../../ui/widgets.dart';

class RecordSheet extends StatefulWidget {
  const RecordSheet({super.key, required this.eventId});

  final String eventId;

  @override
  State<RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<RecordSheet> {
  late HabitEvent _event;
  late double _value;
  late DateTime _date;
  late TimeOfDay _time;
  late DateTime _today;

  final _noteCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();

  Timer? _timer;
  int _elapsed = 0;
  bool _timerRunning = false;
  bool _initialized = false;

  String? _hint;
  Timer? _hintTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final store = StoreScope.of(context);
    _event = store.eventById(widget.eventId)!;
    _value = _event.step <= 0 ? 1 : _event.step;
    final now = store.now;
    _today = DateTime(now.year, now.month, now.day);
    _date = _today;
    _time = TimeOfDay(hour: now.hour, minute: now.minute);
    _valueCtrl.text = _formatNumber(_value);
    _initialized = true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hintTimer?.cancel();
    _noteCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  String _formatNumber(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  String get _dateLabel =>
      '${_date.year}/${_date.month.toString().padLeft(2, '0')}/${_date.day.toString().padLeft(2, '0')}';

  String get _timeLabel =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  bool get _isBackdated => _date != _today;

  DateTime get _occurredAt =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  void _showHint(String message) {
    _hintTimer?.cancel();
    setState(() => _hint = message);
    _hintTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _hint = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(_event.colorValue);
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleClose();
      },
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(bottom: insets),
        child: SheetShell(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetGrabber(),
              _header(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SheetLabel(Copy.recordTime),
                      _timeRow(),
                      if (_isBackdated) _crossDayBar(),
                      _SheetLabel(switch (_event.metricType) {
                        MetricType.count => Copy.recordCount,
                        MetricType.duration => Copy.recordDuration,
                        MetricType.value => Copy.recordValue,
                      }),
                      _valueControl(),
                      if (_event.metricType == MetricType.duration) _timerRow(),
                      const _SheetLabel(Copy.note),
                      _noteField(),
                      const SizedBox(height: 12),
                      _attachRow(),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 160),
                child: _hint == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A1E1C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _hint!,
                            style: const TextStyle(fontSize: 13, color: AppColors.danger),
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 22 + (insets > 0 ? 8 : 0)),
                child: PrimaryButton(
                  label: Copy.submitRecord,
                  color: color,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          RoundIconButton(icon: Icons.close_rounded, onTap: _handleClose),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_event.emoji, style: const TextStyle(fontSize: 17)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _event.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          RoundIconButton(
            icon: Icons.check_rounded,
            iconSize: 24,
            onTap: _submit,
          ),
        ],
      ),
    );
  }

  Widget _crossDayBar() {
    final label = '${_date.month} 月 ${_date.day} 日';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2230),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF7FB2F0)),
          const SizedBox(width: 8),
          Text(
            Copy.crossDay(label),
            style: const TextStyle(fontSize: 12.5, color: Color(0xFFA8C8F0)),
          ),
        ],
      ),
    );
  }

  Widget _timeRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(child: _pill(_dateLabel, _pickDate)),
          const SizedBox(width: 10),
          Expanded(child: _pill(_timeLabel, _pickTime)),
        ],
      ),
    );
  }

  Widget _pill(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.cardHi,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.text)),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_today.year, _today.month, _today.day - 30),
      lastDate: _today,
      locale: const Locale('zh', 'CN'),
      helpText: '选择记录日期',
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: '选择记录时间',
    );
    if (picked == null || !mounted) return;
    setState(() => _time = picked);
  }

  Widget _valueControl() {
    switch (_event.metricType) {
      case MetricType.count:
      case MetricType.duration:
        return _stepper();
      case MetricType.value:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.cardAlt,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _valueCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      onChanged: (v) => _value = double.tryParse(v) ?? 0,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '0',
                        hintStyle: TextStyle(color: AppColors.dim, fontSize: 34),
                      ),
                    ),
                  ),
                  Text(_event.unit, style: const TextStyle(fontSize: 13, color: AppColors.dim)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [100, 250, 500, 1000].map((n) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _value += n;
                          _valueCtrl.text = _formatNumber(_value);
                        });
                      },
                      child: Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.cardAlt,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '+$n',
                          style: const TextStyle(fontSize: 13, color: Color(0xFFA9B2C0)),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
    }
  }

  Widget _stepper() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardAlt,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stepButton(Icons.remove_rounded, () {
            setState(() => _value = (_value - _event.step).clamp(0, double.infinity));
          }),
          Column(
            children: [
              Text(
                _formatNumber(_value),
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              Text(_event.unit, style: const TextStyle(fontSize: 12, color: AppColors.dim)),
            ],
          ),
          _stepButton(Icons.add_rounded, () {
            setState(() => _value += _event.step <= 0 ? 1 : _event.step);
          }),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(color: AppColors.cardHi, shape: BoxShape.circle),
        child: Icon(icon, color: AppColors.text, size: 22),
      ),
    );
  }

  Widget _timerRow() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${(_elapsed ~/ 60).toString().padLeft(2, '0')}:${(_elapsed % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          GestureDetector(
            onTap: _toggleTimer,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: _timerRunning ? AppColors.teal : AppColors.cardHi,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _timerRunning ? '停止并计入' : '开始计时',
                style: TextStyle(
                  fontSize: 13.5,
                  color: _timerRunning ? const Color(0xFF04150F) : AppColors.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleTimer() {
    if (_timerRunning) {
      _timer?.cancel();
      final minutes = (_elapsed / 60).ceil().clamp(1, 600);
      setState(() {
        _timerRunning = false;
        _value += minutes.toDouble();
        _elapsed = 0;
      });
      _showHint('计时 $minutes 分钟已计入');
      return;
    }
    setState(() {
      _timerRunning = true;
      _elapsed = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
    });
  }

  Widget _noteField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: _noteCtrl,
        maxLines: 4,
        maxLength: 500,
        style: const TextStyle(fontSize: 14, height: 1.6),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: Copy.noteHint,
          hintStyle: TextStyle(color: Color(0xFF5A6273)),
          counterText: '',
        ),
      ),
    );
  }

  Widget _attachRow() {
    return GestureDetector(
      onTap: () => _showHint(Copy.attachUnavailable),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.cardAlt,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.add_rounded, color: Color(0xFF7C8595), size: 24),
      ),
    );
  }

  void _handleClose() {
    if (_noteCtrl.text.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(Copy.discardRecord, style: TextStyle(fontSize: 16)),
        content: const Text(
          '已填写的备注不会保存。',
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

  Future<void> _submit() async {
    final store = StoreScope.of(context);
    if (_value <= 0) {
      _showHint('请填写大于 0 的数值');
      return;
    }
    final outcome = store.addLog(
      eventId: _event.id,
      at: _occurredAt,
      value: _value,
      note: _noteCtrl.text.trim(),
    );
    if (!outcome.ok) {
      _showHint(switch (outcome.block) {
        LogBlock.limit => Copy.limitReached(_event.dailyLimit),
        LogBlock.future => Copy.futureBlocked,
        LogBlock.tooOld => Copy.tooOldBlocked,
        null => '',
      });
      return;
    }
    HapticFeedback.lightImpact();
    // 等真正落盘再关闭弹层
    await store.flush();
    if (!mounted) return;
    Navigator.of(context).pop(outcome);
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
      ),
    );
  }
}
