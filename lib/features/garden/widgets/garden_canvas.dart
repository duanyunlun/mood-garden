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

  /// 单次最多绘制多少株。
  ///
  /// 这个上限有两个理由，缺一不可：
  /// - **性能**：几百个 Text 组件的布局与绘制是这一屏最重的开销，
  ///   而首页每次 `setState` 都要重算（PRD 第 10 章的「性能」要求）；
  /// - **可读性**：几百个 emoji 挤在 260dp 高的画布里本来就是一坨色块，
  ///   画满反而看不出「花园」。
  ///
  /// 折中是只画最近种下的这一批（用户最关心的就是它们），
  /// 并在底部补一行「还有 N 株」，信息不丢。
  static const int maxRenderedPlants = 60;


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
                        // 被省略的株数。放在画布角上而不是植物床里，
                        // 这样它不会被植物床的裁剪一起裁掉。
                        if (flowers.length > GardenCanvas.maxRenderedPlants)
                          Positioned(
                            left: 10,
                            top: 10,
                            child: _HiddenPlantsBadge(
                              hidden:
                                  flowers.length -
                                      GardenCanvas.maxRenderedPlants,
                            ),
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

    final hidden = ordered.length - GardenCanvas.maxRenderedPlants;
    // 只画最近种下的这一批。它们在列表末尾，而列表自上而下排布、
    // 整块贴底对齐——所以即使真的画不下，被裁掉的也是最早的那些，
    // 用户最关心的新花始终在画面里。
    final visible = hidden > 0 ? ordered.sublist(hidden) : ordered;

    return Align(
      alignment: Alignment.bottomLeft,
      // 画布高度是固定的。植物多到铺不下时静默裁掉顶部（最早的那批），
      // 而不是抛 RenderFlex overflow——花园是装饰性场景，
      // 不该因为用户记录得多就把首页变成报错页。
      child: ClipRect(
        child: Wrap(
          spacing: 2,
          runSpacing: 0,
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: visible
              .map((flower) => _PlantSprite(flower: flower, now: now))
              .toList(growable: false),
        ),
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

/// 「还有 N 株在更早的地方」角标。
class _HiddenPlantsBadge extends StatelessWidget {
  const _HiddenPlantsBadge({required this.hidden});

  final int hidden;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '还有 $hidden 株在更早的地方',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
