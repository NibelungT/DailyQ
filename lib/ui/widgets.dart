import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme.dart';

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.ghost = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool ghost;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? const Color(0xFFEDEFF3)
        : (ghost ? const Color(0xFF15181E) : const Color(0xFF1B1E24));
    final fg = selected
        ? const Color(0xFF0B0D11)
        : (ghost ? const Color(0xFF9AA3B2) : const Color(0xFFC7CFDB));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 14.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class AppSegmented extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.enabled = true,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0F13),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: List.generate(labels.length, (i) {
            final active = i == index;
            return Expanded(
              child: GestureDetector(
                onTap: enabled ? () => onChanged(i) : null,
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF2A2F39)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 13.5,
                      color: active ? Colors.white : AppColors.muted,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? AppColors.teal : const Color(0xFF2A2F39),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.accent,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: inkFor(color),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.iconSize = 21,
    this.color = const Color(0xFFD7DEE9),
    this.background,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: background == null
            ? null
            : BoxDecoration(color: background, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, size: iconSize, color: color),
      ),
    );
  }
}

/// 底部弹层统一外壳：圆角、拖拽条、最大高度。
class SheetShell extends StatelessWidget {
  const SheetShell({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.93,
  });

  final Widget child;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Container(
      constraints: BoxConstraints(maxHeight: height * maxHeightFactor),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1116),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.panel),
        ),
      ),
      child: child,
    );
  }
}

class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 5,
      margin: const EdgeInsets.only(top: 10, bottom: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF31363F),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// 浮层提示条。不用 SnackBar：ScaffoldMessenger 只在 build 里、且入场动画
/// 完成后才创建自动关闭的 Timer，从底部弹层返回后立刻提示时这个条件可能永远
/// 不满足，导致提示条一直挂在屏幕上。这里自己持有 Timer 与 OverlayEntry。
OverlayEntry? _barEntry;

void _dismissBar() {
  _barEntry?.remove();
  _barEntry = null;
}

void _showBar(
  BuildContext context, {
  required String message,
  required Duration duration,
  VoidCallback? onUndo,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  _dismissBar();
  final entry = OverlayEntry(
    builder: (_) => _FloatingBar(
      message: message,
      duration: duration,
      onUndo: onUndo == null
          ? null
          : () {
              _dismissBar();
              onUndo();
            },
      onTimeout: _dismissBar,
    ),
  );
  _barEntry = entry;
  overlay.insert(entry);
}

/// 3 秒撤销条（SYS-R-05）。
void showUndoSnack(BuildContext context, String message, VoidCallback onUndo) {
  _showBar(
    context,
    message: message,
    duration: AppDuration.undo,
    onUndo: onUndo,
  );
}

void showToast(BuildContext context, String message) {
  _showBar(context, message: message, duration: const Duration(seconds: 2));
}

class _FloatingBar extends StatefulWidget {
  const _FloatingBar({
    required this.message,
    required this.duration,
    required this.onTimeout,
    this.onUndo,
  });

  final String message;
  final Duration duration;
  final VoidCallback onTimeout;
  final VoidCallback? onUndo;

  @override
  State<_FloatingBar> createState() => _FloatingBarState();
}

class _FloatingBarState extends State<_FloatingBar> {
  Timer? _timer;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    // 下一帧再显式上来，配合 AnimatedOpacity 做淡入
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _shown = true);
    });
    _timer = Timer(widget.duration, () {
      if (!mounted) return;
      widget.onTimeout();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 14,
      right: 14,
      bottom: 104,
      child: IgnorePointer(
        ignoring: false,
        child: AnimatedOpacity(
          opacity: _shown ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          // Overlay 里没有 Material 祖先，缺了它文字会带黄色双下划线（调试样式）
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E24),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFFE9EDF3),
                      ),
                    ),
                  ),
                  if (widget.onUndo != null)
                    GestureDetector(
                      onTap: widget.onUndo,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Text(
                          '撤销',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
