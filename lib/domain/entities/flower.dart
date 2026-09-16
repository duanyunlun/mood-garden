import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import 'flower_species.dart';
import 'growth_stage.dart';

/// 花园中的一朵花 / 一株植物。
///
/// 关键机制（PRD 7.1.2）：花朵的生长阶段不由用户操作决定，而是由
/// **种植时间到当前时间的自然流逝**推导而来（见 [stageAt]）。
/// 这是「活地图」心智的技术落点——用户隔天再打开，看到的是真的长大了一点。
class Flower {
  const Flower({
    required this.id,
    required this.speciesId,
    required this.plantedAt,
    this.nutrientBoost = 0,
  });

  /// 花朵唯一标识。
  final String id;

  /// 花种 id，见 [FlowerSpeciesId]。
  final String speciesId;

  /// 种下时间。
  final DateTime plantedAt;

  /// 种植时花园的养分加成。
  ///
  /// PRD 7.3：养分值越高，花朵生长周期越短、形态越饱满艳丽。
  /// 该值被固化在花朵上，保证「同一朵花的历史生长条件」可被稳定复现，
  /// 避免花园整体养分波动导致已生长进度被回退。
  final int nutrientBoost;

  /// 花种信息。花种目录缺失时返回 `null`。
  FlowerSpecies? get species => FlowerSpecies.byId(speciesId);

  /// 养分带来的生长加速系数。
  ///
  /// 养分越高，达到下一阶段所需天数越少。系数范围 `(0, 1]`：
  /// 满养分时生长周期缩短至基准的 [maxSpeedUp] 分之一。
  /// 待产品确认：加速曲线公式（当前为线性折算的骨架实现）。
  static const double maxSpeedUp = 2.0;

  double get _growthFactor {
    final clamped = nutrientBoost.clamp(0, AppConstants.nutrientLevelCap);
    final ratio = clamped / AppConstants.nutrientLevelCap; // 0.0 ~ 1.0
    return 1.0 - (ratio * (1.0 - 1.0 / maxSpeedUp));
  }

  /// 将基准天数按养分系数折算为实际天数。
  double _effectiveDays(int baseDays) => baseDays * _growthFactor;

  /// 推导给定时刻的生长阶段（PRD 7.1.2）。
  ///
  /// 传入 [now] 便于测试与时光轴回看历史某天的生长状态。
  GrowthStage stageAt(DateTime now) {
    final elapsedDays = now.difference(plantedAt).inMinutes / (60 * 24);

    if (elapsedDays >= _effectiveDays(AppConstants.daysToBlooming)) {
      return GrowthStage.blooming;
    }
    if (elapsedDays >= _effectiveDays(AppConstants.daysToLeafing)) {
      return GrowthStage.leafing;
    }
    if (elapsedDays >= _effectiveDays(AppConstants.daysToSprout)) {
      return GrowthStage.sprout;
    }
    return GrowthStage.seed;
  }

  /// 当前生长阶段。
  GrowthStage get currentStage => stageAt(DateTime.now());

  /// 当前阶段内的生长进度，范围 `0.0 ~ 1.0`。
  ///
  /// 用于花园全景绘制「这朵花又长大了一点」的细腻过渡，
  /// 以及花朵详情页的进度展示。
  double growthProgressAt(DateTime now) {
    final elapsedDays = now.difference(plantedAt).inMinutes / (60 * 24);

    final milestones = <double>[
      0,
      _effectiveDays(AppConstants.daysToSprout),
      _effectiveDays(AppConstants.daysToLeafing),
      _effectiveDays(AppConstants.daysToBlooming),
    ];

    final stageIndex = stageAt(now).progressIndex;
    if (stageIndex >= GrowthStage.totalStages - 1) {
      return 1.0;
    }

    final start = milestones[stageIndex];
    final end = milestones[stageIndex + 1];
    final span = end - start;
    if (span <= 0) {
      return 1.0;
    }
    return ((elapsedDays - start) / span).clamp(0.0, 1.0);
  }

  /// 距离完全绽放还剩的天数。已开花返回 0。
  int daysUntilBlooming(DateTime now) {
    final bloomDays = _effectiveDays(AppConstants.daysToBlooming);
    final elapsedDays = now.difference(plantedAt).inMinutes / (60 * 24);
    final remaining = bloomDays - elapsedDays;
    return remaining <= 0 ? 0 : remaining.ceil();
  }

  /// 是否已完全绽放。
  bool isBloomingAt(DateTime now) => stageAt(now).isBlooming;

  /// 花园渲染用的稳定随机种子。
  ///
  /// 让同一朵花在花园里的位置、倾斜角度、大小抖动保持一致——
  /// 否则每帧重绘都会「跳一下」，破坏柔和治愈的观感（PRD 11.3）。
  int get renderSeed => id.hashCode;

  /// 由稳定种子生成 `0.0 ~ 1.0` 的确定性伪随机数，供布局抖动使用。
  double jitter(int salt, {double min = 0.0, double max = 1.0}) {
    final rng = math.Random(renderSeed ^ salt);
    return min + rng.nextDouble() * (max - min);
  }

  Flower copyWith({
    String? id,
    String? speciesId,
    DateTime? plantedAt,
    int? nutrientBoost,
  }) {
    return Flower(
      id: id ?? this.id,
      speciesId: speciesId ?? this.speciesId,
      plantedAt: plantedAt ?? this.plantedAt,
      nutrientBoost: nutrientBoost ?? this.nutrientBoost,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Flower &&
          other.id == id &&
          other.speciesId == speciesId &&
          other.plantedAt == plantedAt &&
          other.nutrientBoost == nutrientBoost;

  @override
  int get hashCode => Object.hash(id, speciesId, plantedAt, nutrientBoost);

  @override
  String toString() => 'Flower($id, $speciesId, plantedAt: $plantedAt)';
}
