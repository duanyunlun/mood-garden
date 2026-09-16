import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/flower.dart';
import '../../../domain/entities/growth_stage.dart';
import '../../../shared/widgets/soft_empty_state.dart';

/// 花园全景展示区（PRD Tab1 核心视觉入口）。
///
/// 承担 PRD 7.1.2 的核心心智：
/// > 花园中的花并非静态统计数字，而是随真实时间流逝自然生长的活地图：
/// > 种子 → 发芽 → 抽叶 → 开花，用户下次打开 App 时能看到花朵比上次
/// > 「又长大了一点」，形成持续的期待感和回访动力。
///
/// 实现要点：
/// - 每株植物在画布上的位置由 [Flower.renderSeed] 确定性生成，
///   保证重绘时不会「跳动」，也保证同一株花每次都长在同一个地方；
/// - 植物尺寸与形态随 [GrowthStage] 变化，让「长大」这件事肉眼可见。
class GardenCanvas extends StatelessWidget {
  const GardenCanvas({
    required this.flowers,
    super.key,
    this.now,
    this.height = 260,
    this.onTap,
  });

  /// 花园中的全部植物。
  final List<Flower> flowers;

  /// 用于推导生长阶段的时间基准。默认取当前时刻；
  /// 时光轴回看历史时传入对应日期，即可复现当天的花园样貌。
  final DateTime? now;

  /// 画布高度。
  final double height;

  /// 点击回调。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final moment = now ?? DateTime.now();

    return SizedBox(
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFFFFFDF8),
              AppColors.sageGreenTint,
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: flowers.isEmpty
                  ? const SoftEmptyState(
                      emoji: '🌱',
                      title: '这里还是一片空地',
                      description: '记录一件让你觉得「谢谢，真好呀」的小事，\n第一颗种子就会在这里入土。',
                      compact: true,
                    )
                  : Stack(
                      children: <Widget>[
                        // 地平线：土壤层
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: height * 0.24,
                          child: const _SoilLayer(),
                        ),
                        // 植物层
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              14,
                              14,
                              14,
                              10,
                            ),
                            child: _PlantBed(flowers: flowers, now: moment),
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

/// 土壤层。用两层渐变的圆弧营造柔和的土丘感，避免生硬的直线分割。
class _SoilLayer extends StatelessWidget {
  const _SoilLayer();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.sageGreenSoft,
            AppColors.soil.withValues(alpha: 0.35),
          ],
        ),
      ),
    );
  }
}

/// 植物种植床。
///
/// 用 [Wrap] 排布，让植物数量增长时自然换行，而不会溢出或重叠。
/// 每株植物的相对大小由生长阶段决定，整体读起来像一片「正在长起来的园子」。
class _PlantBed extends StatelessWidget {
  const _PlantBed({required this.flowers, required this.now});

  final List<Flower> flowers;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    // 最近的记录排在后面（视觉上更靠前、更显眼），与「刚种下」的直觉一致。
    final ordered = List<Flower>.of(flowers)
      ..sort((a, b) => a.plantedAt.compareTo(b.plantedAt));

    return Align(
      alignment: Alignment.bottomLeft,
      child: Wrap(
        spacing: 2,
        runSpacing: 0,
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: ordered
            .map((flower) => _PlantSprite(flower: flower, now: now))
            .toList(growable: false),
      ),
    );
  }
}

/// 单株植物。
class _PlantSprite extends StatelessWidget {
  const _PlantSprite({required this.flower, required this.now});

  final Flower flower;
  final DateTime now;

  /// 各生长阶段对应的视觉尺寸。让「长大」这件事有直观的量感差异。
  static const Map<GrowthStage, double> _sizeByStage = <GrowthStage, double>{
    GrowthStage.seed: 20,
    GrowthStage.sprout: 28,
    GrowthStage.leafing: 36,
    GrowthStage.blooming: 46,
  };

  @override
  Widget build(BuildContext context) {
    final stage = flower.stageAt(now);
    final size = _sizeByStage[stage] ?? 28;

    // 基于稳定种子生成的轻微偏移与倾斜，让园子看起来自然错落，
    // 而不是一整排整齐划一的图标（也避免每帧重绘时位置跳动）。
    final verticalJitter = flower.jitter(1, min: 0, max: 6);
    final tilt = flower.jitter(2, min: -0.09, max: 0.09);

    return Tooltip(
      message: '${flower.species?.name ?? '植物'} · ${stage.label}',
      child: Transform.translate(
        offset: Offset(0, -verticalJitter),
        child: Transform.rotate(
          angle: tenderAngle(tilt),
          child: Text(
            stage.emoji,
            style: TextStyle(fontSize: size),
          ),
        ),
      ),
    );
  }

  /// 让倾斜角度保持柔和。花园是治愈场景，不该出现夸张的歪斜。
  double tenderAngle(double raw) => raw;
}
