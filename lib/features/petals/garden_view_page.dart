import 'package:flutter/material.dart';

import '../../application/mood_garden_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/growth_stage.dart';
import '../../domain/entities/mood_entry.dart';
import '../garden/widgets/garden_canvas.dart';

/// 全屏花园（原型 v5 · `screen-garden`）。
///
/// 从「我的花园」页点「走进花园 →」进入。刻意做成**没有 Tab 栏**的沉浸页：
/// 进到这里就是来看花的，任何导航元素都是干扰。
///
/// 所有 UI 都用玻璃拟态浮在花园之上，不占布局空间——
/// 花园本身要尽可能占满整屏，这是这个页面存在的意义。
class GardenViewPage extends StatelessWidget {
  const GardenViewPage({required this.controller, super.key});

  final MoodGardenController controller;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final garden = controller.garden;

    final bloomed =
        garden.flowers.where((f) => f.stageAt(now) == GrowthStage.blooming).length;
    final released = controller.entries
        .whereType<UnhappyEntry>()
        .where((entry) => entry.isBurned)
        .length;

    return Scaffold(
      backgroundColor: AppColors.sageGreenTint,
      body: Stack(
        children: <Widget>[
          // 花园铺满整屏
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) => GardenCanvas(
                flowers: garden.flowers,
                now: now,
                height: constraints.maxHeight,
              ),
            ),
          ),

          // 顶部：返回 + 问候
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Row(
                children: <Widget>[
                  _GlassCircleButton(
                    emoji: '‹',
                    label: '返回',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GlassPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      child: Text(
                        '今天也要谢谢你呀',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 底部：三个数字
          Positioned(
            left: 18,
            right: 18,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _GlassPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      _Metric(
                        label: '养分',
                        value: '${garden.nutrientValue}',
                      ),
                      _Metric(label: '已绽放', value: '$bloomed 朵'),
                      _Metric(label: '已释放', value: '$released 件'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 玻璃拟态面板。压在花园上仍然透气，是原型贯穿始终的质感。
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.creamWhite.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}

/// 圆形玻璃按钮。
class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.creamWhite.withValues(alpha: 0.82),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
          ),
          child: Text(
            emoji,
            style: const TextStyle(
              fontSize: 22,
              color: AppColors.inkPrimary,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

/// 一个指标：数值 + 说明。
class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: textTheme.titleLarge?.copyWith(
            color: AppColors.warmApricotDeep,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: textTheme.labelSmall),
      ],
    );
  }
}

/// 供本页与测试引用的标题，避免文案散落。
const String gardenViewTitle = AppConstants.slogan;
