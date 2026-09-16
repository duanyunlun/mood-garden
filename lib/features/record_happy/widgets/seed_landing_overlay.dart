import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 种子落地反馈动画遮罩（PRD 7.1.2）。
///
/// PRD 原文：
/// > 保存后播放「种子入土」动画：种子从记录卡片飞入花园土壤，落地生根。
///
/// ⚠️ 骨架期实现说明：用 emoji + 位移/缩放/旋转组合出「飞入土壤」的完整节奏，
/// 保证交互链路和动效时长已经可被真实体验。正式版需替换为手绘插画序列帧或
/// Rive / Lottie 动画资源（PRD 11.3 要求手绘插画风格），
/// 届时只需替换本组件内部的绘制层，外部调用方（[RecordHappyPage]）无需改动。
class SeedLandingOverlay extends StatefulWidget {
  const SeedLandingOverlay({required this.emoji, super.key});

  /// 种子对应花种的图标。
  final String emoji;

  /// 动画总时长。调用方需要按该时长等待动画播完。
  static const Duration totalDuration = Duration(milliseconds: 1500);

  @override
  State<SeedLandingOverlay> createState() => _SeedLandingOverlayState();
}

class _SeedLandingOverlayState extends State<SeedLandingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// 土壤的垂直位置（相对高度的比例值）。
  static const double _soilLine = 0.34;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: SeedLandingOverlay.totalDuration,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;

        // 阶段划分：淡入 → 加速下落 → 落地弹跳 → 淡出
        const fadeIn = Interval(0.0, 0.12, curve: Curves.easeOut);
        const fall = Interval(0.12, 0.68, curve: Curves.easeInQuad);
        const settle = Interval(0.68, 0.86, curve: Curves.easeOutBack);
        const fadeOut = Interval(0.86, 1.0, curve: Curves.easeIn);

        final opacity = t < 0.86
            ? fadeIn.transform(t.clamp(0.0, 1.0))
            : 1.0 - fadeOut.transform(t);

        // 从屏幕上方 45% 处下落到土壤线
        const startY = -0.45;
        final y = t < 0.68
            ? startY + (_soilLine - startY) * fall.transform(t)
            : _soilLine;

        // 落地时轻微压扁再回弹，模拟「陷入土里」的质感
        final settleT = settle.transform(t);
        final scale = t < 0.68
            ? 1.0
            : 1.0 - 0.25 * math.sin(settleT * math.pi);

        // 下落过程中的轻微旋转，避免轨迹过于机械
        final rotation = t < 0.68 ? fall.transform(t) * 0.4 : 0.0;

        return IgnorePointer(
          child: ColoredBox(
            color: AppColors.creamWhite.withValues(alpha: 0.86 * opacity),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: <Widget>[
                    // 土壤提示线
                    Positioned(
                      left: 0,
                      right: 0,
                      top: constraints.maxHeight *
                          (0.5 + _soilLine) -
                          10,
                      child: Opacity(
                        opacity: opacity * 0.9,
                        child: Column(
                          children: <Widget>[
                            Text(
                              '种子正在入土…',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: AppColors.soil,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 种子
                    Positioned(
                      left: 0,
                      right: 0,
                      top: constraints.maxHeight * (0.5 + y),
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Transform.rotate(
                          angle: rotation,
                          child: Transform.scale(
                            scale: scale,
                            child: Center(
                              child: Text(
                                widget.emoji,
                                style: const TextStyle(fontSize: 44),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
