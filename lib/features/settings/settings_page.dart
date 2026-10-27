import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../copy.dart';
import '../../data/store.dart';
import '../../ui/widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
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
                      child: Text('设置', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  _sectionTitle('周期'),
                  _card([
                    _row(
                      '每周从',
                      value: store.weekStart == 1 ? '周一开始' : '周日开始',
                      onTap: () => _pickWeekStart(context, store),
                    ),
                    _row(
                      '周起始日影响',
                      value: '统计的周视图与每周重置',
                      chevron: false,
                      muted: true,
                    ),
                  ]),
                  _sectionTitle('提醒'),
                  _card([
                    _switchRow(
                      '每日提醒',
                      subtitle: '当天还有未完成事项时，首页顶部会提示',
                      value: store.reminderOn,
                      onChanged: (v) {
                        store.setReminderEnabled(v);
                        showToast(context, v ? '已开启提醒' : '已关闭提醒');
                      },
                    ),
                    _row(
                      '提醒时间',
                      value: _timeLabel(store.reminderMinute),
                      onTap: store.reminderOn ? () => _pickReminderTime(context, store) : null,
                    ),
                  ]),
                  _sectionTitle('数据'),
                  _card([
                    _row('导出 CSV', value: '复制到剪贴板', onTap: () => _copy(context, store.exportCsv(), 'CSV')),
                    _row('导出 JSON', value: '完整备份', onTap: () => _copy(context, store.exportJson(), 'JSON')),
                    _row('从 JSON 导入', value: '覆盖当前数据', onTap: () => _import(context, store)),
                    _row(
                      '存储自检',
                      value: store.storageError == null ? '检查本地保存' : '有异常，点开看',
                      danger: store.storageError != null,
                      onTap: () => _diagnose(context, store),
                    ),
                    _row(
                      '清空所有记录',
                      value: '${store.totalLogs} 条',
                      danger: true,
                      onTap: () => _confirmClear(context, store),
                    ),
                    _row(
                      '重置演示数据',
                      value: '恢复初始 4 个事件',
                      onTap: () => _confirmReset(context, store),
                      last: true,
                    ),
                  ]),
                  _sectionTitle('关于'),
                  _card([
                    _row('版本', value: '1.0.0', chevron: false),
                    _row(
                      '数据存储',
                      value: '仅保存在本机',
                      chevron: false,
                      muted: true,
                      last: true,
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppColors.dim, letterSpacing: 0.5),
        ),
      );

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.control + 4),
        ),
        child: Column(children: children),
      );

  Widget _row(
    String label, {
    required String value,
    VoidCallback? onTap,
    bool chevron = true,
    bool danger = false,
    bool muted = false,
    bool last = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 15, color: danger ? AppColors.danger : AppColors.text),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, color: muted ? AppColors.dim : AppColors.muted),
              ),
            ),
            if (chevron && onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 17, color: AppColors.dim),
            ],
          ],
        ),
      ),
    );
  }

  Widget _switchRow(
    String label, {
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.dim, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Future<void> _pickWeekStart(BuildContext context, AppStore store) async {
    final v = await _pick(context, '每周从哪天开始', const ['周一开始', '周日开始'],
        store.weekStart == 1 ? '周一开始' : '周日开始');
    if (v == null) return;
    store.setWeekStart(v == '周一开始' ? 1 : 0);
    if (context.mounted) showToast(context, '已改为$v');
  }

  Future<void> _pickReminderTime(BuildContext context, AppStore store) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: store.reminderMinute ~/ 60, minute: store.reminderMinute % 60),
      helpText: '每日提醒时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null) return;
    store.setReminderMinute(picked.hour * 60 + picked.minute);
  }

  Future<String?> _pick(BuildContext context, String title, List<String> options, String current) {
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
              ...options.map(
                (o) => GestureDetector(
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
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// 导入备份：粘贴 JSON 后整份替换当前数据。
  Future<void> _import(BuildContext context, AppStore store) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _ImportDialog(),
    );
    if (text == null) return;
    final result = await store.importJson(text);
    if (!context.mounted) return;
    showToast(context, result.message);
  }

  /// 把真实存储状态摊开给用户看，用于定位“改完重启又变回去”。
  Future<void> _diagnose(BuildContext context, AppStore store) async {
    final report = await store.storageDiagnostics();
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('存储自检', style: TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: SelectableText(
            report,
            style: const TextStyle(fontSize: 12.5, height: 1.7, color: AppColors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(Copy.cancel, style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _copy(context, report, '自检结果');
            },
            child: const Text('复制'),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, String content, String label) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!context.mounted) return;
    final lines = content.split('\n').length;
    showToast(context, '$label 已复制（$lines 行）');
  }

  void _confirmClear(BuildContext context, AppStore store) {
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

  void _confirmReset(BuildContext context, AppStore store) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重置演示数据', style: TextStyle(fontSize: 16)),
        content: const Text(
          '将恢复到初始的四个事件与示例记录，当前数据全部丢弃。',
          style: TextStyle(fontSize: 13.5, color: AppColors.muted, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(Copy.cancel, style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await store.resetDemo();
              if (context.mounted) showToast(context, Copy.resetDone);
            },
            child: const Text('重置', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

/// 导入弹层：自带 controller，避免在退场动画中提前 dispose。
class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canImport = _ctrl.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('导入备份', style: TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '把导出的 JSON 全文粘贴进来。导入会覆盖当前所有事件与记录，建议先导出一次做备份。',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.6),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.cardAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _ctrl,
                maxLines: 5,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 12, height: 1.5),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '{"schemaVersion":1,"events":[...],"logs":[...]}',
                  hintStyle: TextStyle(fontSize: 12, color: AppColors.dim),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Copy.cancel, style: TextStyle(color: AppColors.muted)),
        ),
        TextButton(
          onPressed: canImport ? () => Navigator.of(context).pop(_ctrl.text) : null,
          child: const Text('导入'),
        ),
      ],
    );
  }
}
