import '../../core/constants/app_constants.dart';
import 'flower.dart';
import 'flower_species.dart';
import 'garden_theme.dart';
import 'growth_stage.dart';

/// 花园聚合状态。
///
/// 承载 PRD 7.3「花园养分系统」这一核心闭环的落点：
///
/// ```
/// 开心事 → 种子入土 ─┐
///                    ├─→ 花园养分池 ─→ 生长速度 / 繁茂程度
/// 不开心事 → 灰烬入土 ─┘
/// ```
///
/// 两条路径在「养分池」汇合，共同作用于同一片花园——这是本产品
/// 「无论情绪好坏，都在为花园做贡献」核心心智的数据结构表达。
class GardenState {
  const GardenState({
    this.nutrientValue = 0,
    this.streakDays = 0,
    this.flowers = const <Flower>[],
    this.petalStockBySpecies = const <String, int>{},
    this.petalProgressDay,
    this.thingsTowardPetal = 0,
    this.tagCountsForDay = const <String, int>{},
    this.unlockedSpeciesIds = const <String>{},
    this.themeId = GardenThemeId.sunflowerField,
    this.lastRecordedDay,
  });

  /// 空花园。新用户的初始状态。
  static const GardenState empty = GardenState();

  /// 养分值（PRD 7.3）。
  ///
  /// 由两个来源共同驱动：种花的基础养分 + 烧灰的额外养分。
  final int nutrientValue;

  /// 连续记录天数。
  ///
  /// 达到 [AppConstants.hiddenSpeciesStreakDays] 解锁隐藏款花种（PRD 7.1.3）。
  final int streakDays;

  /// 花园中已种下的所有花朵。
  final List<Flower> flowers;

  /// 各花种已攒下的花瓣数（原型 v5：各花种花瓣）。
  ///
  /// key 为花种 id，value 为花瓣片数。
  final Map<String, int> petalStockBySpecies;

  /// 下面三个字段共同实现原型 v5 的**按天聚合**规则：
  /// 一天集齐 [AppConstants.thingsPerPetal] 件小事，才收获一片花瓣；
  /// 这片花瓣的花种 = 当天用得最多的那个标签。
  ///
  /// 计数器跟着**记录归属的那一天**走，而不是跟着「今天」走——
  /// 否则补记上周三的三件小事将永远攒不到花瓣。
  /// 三个字段要么一起有效，要么一起为空。
  final DateTime? petalProgressDay;

  /// [petalProgressDay] 这一天已经记下了几件小事（0 起步，满 3 归零）。
  final int thingsTowardPetal;

  /// [petalProgressDay] 这一天各标签出现的次数，用于判定花瓣归属。
  final Map<String, int> tagCountsForDay;

  /// 已解锁的进阶花种 id（PRD 7.1.3 的进化花种）。
  ///
  /// 刻意独立成一个集合，而不是每次由种子数现算：解锁是**一次性事件**，
  /// 一旦达成就不该因为后续计数变化（例如清除数据重来之外的任何情况）而回退。
  /// 现算还会让「已解锁」与「解锁瞬间的花园状态」脱钩。
  final Set<String> unlockedSpeciesIds;

  /// 当前花园主题（PRD Tab4 换肤）。
  final String themeId;

  /// 最近一次记录归属的日期。用于连续记录天数的判定与每日提醒。
  final DateTime? lastRecordedDay;

  /// 当前主题配置。
  GardenThemeOption get theme => GardenThemeOption.byId(themeId);

  // ---------------------------------------------------------------------------
  // 养分值（PRD 7.3）
  // ---------------------------------------------------------------------------

  /// 养分进度，范围 `0.0 ~ 1.0`。用于首页常驻进度条。
  double get nutrientProgress =>
      (nutrientValue / AppConstants.nutrientLevelCap).clamp(0.0, 1.0);

  /// 养分进度百分比（0~100 整数），用于无障碍朗读与文字展示。
  int get nutrientProgressPercent => (nutrientProgress * 100).round();

  /// 养分带来的花园繁茂程度描述（PRD 7.3）。
  ///
  /// 用文字而非数值表达，弱化数据化、工具化的视觉语言（PRD 11.3）。
  String get vitalityLabel {
    final ratio = nutrientProgress;
    if (ratio >= 0.85) {
      return '郁郁葱葱';
    }
    if (ratio >= 0.6) {
      return '生机勃勃';
    }
    if (ratio >= 0.35) {
      return '长势喜人';
    }
    if (ratio >= 0.15) {
      return '刚刚抽芽';
    }
    return '静待播种';
  }

  /// 距下一次养分等级提升还差多少养分值。
  /// 骨架期按线性封顶计算，待产品确认是否改为分段等级制。
  int get nutrientToNextLevel {
    const cap = AppConstants.nutrientLevelCap;
    if (nutrientValue >= cap) {
      return 0;
    }
    return cap - nutrientValue;
  }

  // ---------------------------------------------------------------------------
  // 花朵统计
  // ---------------------------------------------------------------------------

  /// 指定时刻已完全绽放的花朵。
  List<Flower> bloomingAt(DateTime now) =>
      flowers.where((f) => f.isBloomingAt(now)).toList(growable: false);

  /// 指定时刻仍在生长中的花朵（尚未开花）。
  List<Flower> growingAt(DateTime now) =>
      flowers.where((f) => !f.isBloomingAt(now)).toList(growable: false);

  /// 已绽放的花朵数量。
  int bloomingCountAt(DateTime now) => bloomingAt(now).length;

  /// 花园中的植物总数（含生长中）。
  int get totalPlants => flowers.length;

  /// 指定花种已绽放的数量，用于图鉴的收集进度（PRD Tab3）。
  int bloomingCountOfSpecies(String speciesId, DateTime now) =>
      flowers
          .where((f) => f.speciesId == speciesId && f.isBloomingAt(now))
          .length;

  /// 指定花种已攒下的花瓣数。
  int petalsOfSpecies(String speciesId) => petalStockBySpecies[speciesId] ?? 0;

  /// 已攒下的花瓣总数。
  int get totalPetals =>
      petalStockBySpecies.values.fold(0, (sum, count) => sum + count);

  /// 当前花苞上已点亮的花瓣数（`0 ~ petalsPerBloom-1`）。
  ///
  /// 花苞**跨花种**拼合：任何花种的花瓣都往同一个花苞上添，
  /// 这与原型 `petalCount % PETALS_PER_FLOWER` 的算法一致。
  int get budProgress => totalPetals % AppConstants.petalsPerBloom;

  /// 距离下一次绽放还差几片花瓣。
  int get petalsUntilBloom => AppConstants.petalsPerBloom - budProgress;

  /// 指定花种距离下一片花瓣还差几件小事。
  ///
  /// 注意这是**按天**的：花瓣由「当天记满 3 件」产出。
  int thingsUntilNextPetal(String speciesId) {
    final done = petalProgressDay == null ? 0 : thingsTowardPetal;
    return AppConstants.thingsPerPetal - done;
  }

  /// 指定花种的花瓣存量进度，范围 `0.0 ~ 1.0`（用于「各花种花瓣」的进度条）。
  ///
  /// 以 5 片为一个花苞周期取余，因为攒满 5 片就会绽放并清零重新计。
  double speciesProgress(String speciesId) {
    final current = petalsOfSpecies(speciesId) % AppConstants.petalsPerBloom;
    return current / AppConstants.petalsPerBloom;
  }

  /// 指定时刻已收集的花种数量（至少开出过一朵花），用于图鉴收集度（PRD Tab3）。
  ///
  /// 口径必须与图鉴卡片的「已收集」判定一致：**开花才算收集**。
  /// 只种下种子仍算未收集（卡片显示为剪影），否则会出现
  /// 「顶部说收集了 3 种、页面上却有 2 张剪影」的自相矛盾。
  int collectedSpeciesCountAt(DateTime now) => flowers
      .where((f) => f.isBloomingAt(now))
      .map((f) => f.speciesId)
      .toSet()
      .length;

  // ---------------------------------------------------------------------------
  // 隐藏款解锁（PRD 7.1.3）
  // ---------------------------------------------------------------------------

  /// 连续记录是否已达隐藏款花种的解锁阈值。
  bool get hiddenSpeciesUnlocked =>
      streakDays >= AppConstants.hiddenSpeciesStreakDays;

  /// 某个进阶花种是否已解锁。
  ///
  /// 隐藏款走的是另一条路径（看连续天数，不看集合），因此这里对它一并为真。
  bool isSpeciesUnlocked(String speciesId) {
    if (unlockedSpeciesIds.contains(speciesId)) {
      return true;
    }
    final species = FlowerSpecies.byId(speciesId);
    return species != null &&
        species.rarity == SpeciesRarity.hidden &&
        hiddenSpeciesUnlocked;
  }

  /// 距离解锁隐藏款花种还差几天。已解锁返回 0。
  int get daysToHiddenSpecies {
    final remaining = AppConstants.hiddenSpeciesStreakDays - streakDays;
    return remaining <= 0 ? 0 : remaining;
  }

  // ---------------------------------------------------------------------------
  // 生长阶段分布
  // ---------------------------------------------------------------------------

  /// 按生长阶段统计植物数量。用于花园全景的分层绘制与首页概览。
  Map<GrowthStage, int> stageDistributionAt(DateTime now) {
    final distribution = <GrowthStage, int>{
      for (final stage in GrowthStage.values) stage: 0,
    };
    for (final flower in flowers) {
      final stage = flower.stageAt(now);
      distribution[stage] = (distribution[stage] ?? 0) + 1;
    }
    return distribution;
  }

  /// 下一株即将开花的植物，以及它还需几天。
  ///
  /// 对应 PRD 7.1.2「用户下次打开 App 时能看到花朵比上次又长大了一点，
  /// 形成持续的期待感和回访动力」——首页可用它生成一句期待的文案。
  ({Flower flower, int days})? nextBloomingAt(DateTime now) {
    final growing = growingAt(now);
    if (growing.isEmpty) {
      return null;
    }
    var best = growing.first;
    var bestDays = best.daysUntilBlooming(now);
    for (final flower in growing.skip(1)) {
      final days = flower.daysUntilBlooming(now);
      if (days < bestDays) {
        best = flower;
        bestDays = days;
      }
    }
    return (flower: best, days: bestDays);
  }

  GardenState copyWith({
    int? nutrientValue,
    int? streakDays,
    List<Flower>? flowers,
    Map<String, int>? petalStockBySpecies,
    DateTime? petalProgressDay,
    int? thingsTowardPetal,
    Map<String, int>? tagCountsForDay,
    Set<String>? unlockedSpeciesIds,
    String? themeId,
    DateTime? lastRecordedDay,
  }) {
    return GardenState(
      nutrientValue: nutrientValue ?? this.nutrientValue,
      streakDays: streakDays ?? this.streakDays,
      flowers: flowers ?? this.flowers,
      petalStockBySpecies: petalStockBySpecies ?? this.petalStockBySpecies,
      petalProgressDay: petalProgressDay ?? this.petalProgressDay,
      thingsTowardPetal: thingsTowardPetal ?? this.thingsTowardPetal,
      tagCountsForDay: tagCountsForDay ?? this.tagCountsForDay,
      unlockedSpeciesIds: unlockedSpeciesIds ?? this.unlockedSpeciesIds,
      themeId: themeId ?? this.themeId,
      lastRecordedDay: lastRecordedDay ?? this.lastRecordedDay,
    );
  }

  @override
  String toString() =>
      'GardenState(nutrient: $nutrientValue, streak: $streakDays, '
      'plants: ${flowers.length})';
}
