import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// 「点燃引信」长按按钮（PRD 7.2.2）。
///
/// PRD 原文：
/// > 长按「点燃引信」按钮，出现长按进度条，模拟划火柴的仪式感；
/// > 进度条上升过程中若松手，则中断点燃，用户可重新继续编辑纸卷内容。
///
/// 交互实现要点：
/// - 松手即**回退**进度（而非清零后卡住），让用户感到「火柴还没划完」，
///   而不是「我失败了」——情绪释放的入口不该带有惩罚感；
/// - 只有长按满进度才触发 [onCompleted]，中途松手不产生任何副作用。
class IgniteButton extends StatefulWidget {
  const IgniteButton({
    required this.onCompleted,
    super.key,
    this.enabled = true,
    this.holdDuration = const Duration(milliseconds: 1600),
  });

  /// 长按满进度后的回调。
  final VoidCallback onCompleted;

  /// 是否可用。纸卷内容为空时通常应禁用。
  final bool enabled;

  /// 长按满进度所需时长。
  final Duration holdDuration;

  @override
  State<IgniteButton> createState() => _IgniteButtonState();
}

class _IgniteButtonState extends State<IgniteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _controller.reset();
          setState(() => _isHolding = false);
          widget.onCompleted();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startHold() {
    if (!widget.enabled) {
      return;
    }
    setState(() => _isHolding = true);
    _controller.forward();
  }

  void _cancelHold() {
    if (!_isHolding) {
      return;
    }
    setState(() => _isHolding = false);
    // 回退而非清零：保留「刚才划到一半」的体感
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final enabled = widget.enabled;

    return Semantics(
      button: true,
      enabled: enabled,
      label: '点燃引信，长按不放直到进度走满',
      child: GestureDetector(
        onLongPressStart: (_) => _startHold(),
        onLongPressEnd: (_) => _cancelHold(),
        onLongPressCancel: _cancelHold,
        onTapDown: enabled ? (_) => setState(() => _isHolding = true) : null,
        onTapUp: (_) => _cancelHold(),
        onTapCancel: _cancelHold,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = _controller.value;
            final isActive = progress > 0;

            return Container(
              height: 58,
              decoration: BoxDecoration(
                color: enabled
                    ? Color.lerp(
                        AppColors.mistyRoseSoft,
                        AppColors.flame,
                        // 上限刻意只到 0.35：底色若一路烧成火苗色，
                        // 上面的文字无论用深色还是浅色都读不清
                        // （奶油白压火苗色只有 2.88:1，深棕也只有 3.40:1）。
                        // 让底色始终保持在浅色区间，文字才能稳定达到 AA。
                        progress * 0.35,
                      )
                    : AppColors.creamDeep,
                borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                border: Border.all(
                  color: isActive
                      ? AppColors.flame
                      : AppColors.mistyRose.withValues(alpha: 0.6),
                  width: 1.4,
                ),
              ),
              child: Stack(
                children: <Widget>[
                  // 进度填充层
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      heightFactor: 1,
                      child: ColoredBox(
                        color: AppColors.flame.withValues(alpha: 0.22),
                      ),
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Text('🔥', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 9),
                        // Flexible：字体放大时按钮文案换行，而不是横向溢出
                        // （PRD 第 10 章无障碍要求文字大小可调节）。
                        Flexible(
                          child: Text(
                            _labelFor(progress, enabled),
                            textAlign: TextAlign.center,
                            style: textTheme.labelLarge?.copyWith(
                              // 底色始终是浅色（见上面的 lerp 上限），
                              // 所以文字固定用深色，不随进度变色——
                              // 变色会让文字在中途某一刻正好落在对比度最低的组合上。
                              color: enabled
                                  ? AppColors.inkPrimary
                                  : AppColors.inkTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _labelFor(double progress, bool enabled) {
    if (!enabled) {
      return '写点什么才能点燃';
    }
    if (progress <= 0) {
      return '长按点燃引信';
    }
    if (progress >= 0.98) {
      return '就要着了…';
    }
    return '别松手…';
  }
}
