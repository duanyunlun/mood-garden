import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/garden_state.dart';

/// 养分值进度条（PRD 7.3 / Tab1）。
///
/// PRD 原文：
/// > 养分值在花园首页以进度条形式常驻展示，让用户直观感受到「每一次记录
/// > （无论开心与否）都在滋养这片花园」，从而对正向和负向记录行为都产生
/// > 持续激励。
///
/// 设计取舍：不展示「137 / 1000」这类裸数值，而是用情绪化的措辞
/// （「郁郁葱葱」）+ 柔和进度条表达同一信息，避免把花园变成数据面板
/// （PRD 11.3：弱化数据化、工具化的视觉语言）。
class NutrientProgressBar extends StatelessWidget {
  const NutrientProgressBar({
    required this.garden,
    super.key,
    this.showHint = true,
  });

  final GardenState garden;

  /// 是否展示底部提示文案。
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final progress = garden.nutrientProgress;

    return Semantics(
      label: '花园养分 ${garden.nutrientProgressPercent}%，'
          '状态${garden.vitalityLabel}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('💛', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Text('花园养分', style: textTheme.labelMedium),
              const Spacer(),
              Text(
                garden.vitalityLabel,
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.warmApricotDeep,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 自定义进度条：系统 LinearProgressIndicator 的圆角与动效
          // 偏「工具化」，这里用 AnimatedContainer 做柔和过渡。
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: <Widget>[
                Container(
                  height: 10,
                  color: AppColors.creamSoft,
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 620),
                  curve: Curves.easeOutCubic,
                  widthFactor: progress == 0 ? 0.001 : progress,
                  child: Container(
                    height: 10,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          AppColors.nutrientGold,
                          AppColors.warmApricot,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showHint) ...<Widget>[
            const SizedBox(height: 7),
            Text(
              progress >= 1.0
                  ? '花园已经养分充盈，花开得正盛'
                  : '再攒 ${garden.nutrientToNextLevel} 点养分，花园会更繁茂',
              style: textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}
