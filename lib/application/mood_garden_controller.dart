import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/id_generator.dart';
import '../domain/entities/flower.dart';
import '../domain/entities/flower_species.dart';
import '../domain/entities/garden_state.dart';
import '../domain/entities/growth_stage.dart';
import '../domain/entities/mood_entry.dart';
import '../domain/entities/mood_tag.dart';
import '../domain/repositories/entry_repository.dart';
import '../domain/repositories/garden_repository.dart';

/// 一次「种下开心事」的结果。供 UI 播放种子落地反馈动画与收集进度提示。
///
/// 对应 PRD 7.1.2：保存后播放种子入土动画，并同步提示该花种当前的收集进度，
/// 例如「向日葵第 7 颗种子，再种 3 颗会长出第一朵花」。
@immutable
class PlantSeedResult {
  const PlantSeedResult({
    required this.entry,
    required this.flower,
    required this.species,
    required this.totalSeedsOfSpecies,
    required this.seedsUntilNextBloom,
    required this.nutrientGained,
  });

  /// 新写入的开心事记录。
  final HappyEntry entry;

  /// 新入土的植物。
  final Flower flower;

  /// 该记录对应的花种。
  final FlowerSpecies species;

  /// 该花种累计已种下的种子总数。
  final int totalSeedsOfSpecies;

  /// 距离下一个收集里程碑还差几颗种子。
  final int seedsUntilNextBloom;

  /// 本次记录为花园带来的养分值增量。
  final int nutrientGained;
}

/// 一次「点燃纸卷」的结果。供 UI 播放灰烬入土反馈。
///
/// 对应 PRD 7.2.3：灰烬飘入土壤后转化为花园养分值。
@immutable
class BurnScrollResult {
  const BurnScrollResult({
    required this.entry,
    required this.nutrientGained,
    required this.totalNutrient,
  });

  /// 燃烧后的记录。其 `text` 与 `imagePaths` 已被清空（PRD 7.2.3）。
  final UnhappyEntry entry;

  /// 本次燃烧为花园带来的养分值增量。
  final int nutrientGained;

  /// 燃烧后花园的养分总值。
  final int totalNutrient;
}

/// 应用主控制器。
///
/// 集中承载 PRD 第 7 章「核心功能需求」的三套机制：
/// - 7.1 开心事记录 → 种花
/// - 7.2 不开心事记录 → 点燃纸卷 → 灰烬化肥料
/// - 7.3 花园养分系统
///
/// 之所以把所有机制收在一个控制器里，是因为它们共同操作同一份
/// 花园状态和养分池——拆散到多个控制器反而会引入跨控制器的一致性问题。
/// 待功能膨胀（图鉴、提醒、分享等 P1/P2 功能接入）后再按特性拆分。
class MoodGardenController extends ChangeNotifier {
  MoodGardenController({
    required EntryRepository entryRepository,
    required GardenRepository gardenRepository,
  })  : _entryRepository = entryRepository,
        _gardenRepository = gardenRepository;

  final EntryRepository _entryRepository;
  final GardenRepository _gardenRepository;

  bool _isLoading = true;
  List<MoodEntry> _entries = const <MoodEntry>[];
  GardenState _garden = GardenState.empty;

  /// 是否正在加载初始数据。
  bool get isLoading => _isLoading;

  /// 全部记录，按归属时间倒序。
  List<MoodEntry> get entries => List<MoodEntry>.unmodifiable(_entries);

  /// 花园聚合状态。
  GardenState get garden => _garden;

  // ---------------------------------------------------------------------------
  // 初始化
  // ---------------------------------------------------------------------------

  /// 从存储加载全部数据。App 启动时调用一次。
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    try {
      _entries = await _entryRepository.loadAll();
      _garden = await _gardenRepository.load();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 查询
  // ---------------------------------------------------------------------------

  /// 指定日期（含）之后的记录。
  List<MoodEntry> entriesSince(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return _entries
        .where((e) => !e.occurredAt.isBefore(start))
        .toList(growable: false);
  }

  /// 指定日的全部记录。
  List<MoodEntry> entriesOn(DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    return _entries
        .where((e) => e.occurredDay == target)
        .toList(growable: false);
  }

  /// 指定日的开心事。
  List<HappyEntry> happyEntriesOn(DateTime day) =>
      entriesOn(day).whereType<HappyEntry>().toList(growable: false);

  /// 指定日的纸卷记录（含已燃烧的封条）。
  List<UnhappyEntry> unhappyEntriesOn(DateTime day) =>
      entriesOn(day).whereType<UnhappyEntry>().toList(growable: false);

  /// 今日已种下的开心事数量。对应首页「今日种下数量」（PRD Tab1）。
  int get todayPlantedCount => happyEntriesOn(DateTime.now()).length;

  /// 今日已转化的纸卷数量。
  int get todayBurnedCount => unhappyEntriesOn(DateTime.now())
      .where((e) => e.isBurned)
      .length;

  /// 尚未点燃的纸卷草稿。
  List<UnhappyEntry> get pendingScrolls => _entries
      .whereType<UnhappyEntry>()
      .where((e) => !e.isBurned)
      .toList(growable: false);

  /// 最近若干条记录，供首页或时光轴预览。
  List<MoodEntry> recentEntries({int limit = 5}) =>
      _entries.take(limit).toList(growable: false);

  /// 解析标签：优先查预设标签，其次回退到自定义标签的兜底构造。
  MoodTag resolveTag(String tagId) {
    return MoodTag.presetById(tagId) ??
        MoodTag(
          id: tagId,
          label: '自定义',
          emoji: '🌱',
          speciesId: FlowerSpeciesId.sunflower,
          isCustom: true,
        );
  }

  // ---------------------------------------------------------------------------
  // PRD 7.1 开心事记录 → 种花机制
  // ---------------------------------------------------------------------------

  /// 种下一件开心事。
  ///
  /// 完整走通 PRD 7.1.1 的输入流程并触发 7.1.2 的机制结算：
  /// 1. 写入记录（[occurredAt] 可由用户编辑，支持补记过去某天）；
  /// 2. 按标签对应的花种，在花园中种下一株植物；
  /// 3. 增加基础养分值（PRD 7.3 正向路径）；
  /// 4. 更新连续记录天数（PRD 7.1.3 隐藏款解锁依据）。
  Future<PlantSeedResult> plantSeed({
    required String tagId,
    required String text,
    List<String> imagePaths = const <String>[],
    DateTime? occurredAt,
  }) async {
    final now = DateTime.now();
    final tag = resolveTag(tagId);
    final speciesId = tag.speciesId;

    final entry = HappyEntry(
      id: IdGenerator.next('happy'),
      occurredAt: occurredAt ?? now,
      createdAt: now,
      tagId: tagId,
      text: text,
      imagePaths: imagePaths,
    );

    await _entryRepository.save(entry);

    // 新植物以记录归属时间为种下时间，保证补记的记录不会「一入土就开花」。
    final flower = Flower(
      id: IdGenerator.next('flower'),
      speciesId: speciesId,
      plantedAt: entry.occurredAt,
      nutrientBoost: _garden.nutrientValue,
    );

    final nextSeedCounts = Map<String, int>.of(_garden.seedCountBySpecies);
    final totalSeeds = (nextSeedCounts[speciesId] ?? 0) + 1;
    nextSeedCounts[speciesId] = totalSeeds;

    const nutrientGained = AppConstants.nutrientPerSeed;

    _garden = _garden.copyWith(
      nutrientValue: _garden.nutrientValue + nutrientGained,
      seedCountBySpecies: nextSeedCounts,
      flowers: <Flower>[..._garden.flowers, flower],
      streakDays: _nextStreak(entry.occurredDay),
      lastRecordedDay: _laterDay(_garden.lastRecordedDay, entry.occurredDay),
    );

    await _gardenRepository.save(_garden);
    _entries = await _entryRepository.loadAll();
    notifyListeners();

    return PlantSeedResult(
      entry: entry,
      flower: flower,
      species: FlowerSpecies.byId(speciesId) ?? FlowerSpecies.sunflower,
      totalSeedsOfSpecies: totalSeeds,
      seedsUntilNextBloom:
          AppConstants.seedsPerBloom - (totalSeeds % AppConstants.seedsPerBloom),
      nutrientGained: nutrientGained,
    );
  }

  // ---------------------------------------------------------------------------
  // PRD 7.2 不开心事记录 → 点燃纸卷 → 灰烬化肥料
  // ---------------------------------------------------------------------------

  /// 保存纸卷内容（尚未点燃）。
  ///
  /// 纸卷在点燃前是普通的草稿，可反复编辑（PRD 7.2.2：中途松手则中断点燃，
  /// 用户可重新继续编辑纸卷内容）。
  Future<UnhappyEntry> saveScrollDraft({
    required String text,
    List<String> imagePaths = const <String>[],
    DateTime? occurredAt,
    String? existingId,
  }) async {
    final now = DateTime.now();
    final existing = existingId == null
        ? null
        : _entries
            .whereType<UnhappyEntry>()
            .where((e) => e.id == existingId)
            .firstOrNull;

    final entry = existing?.editContent(text: text, imagePaths: imagePaths) ??
        UnhappyEntry(
          id: IdGenerator.next('unhappy'),
          occurredAt: occurredAt ?? now,
          createdAt: now,
          text: text,
          imagePaths: imagePaths,
        );

    await _entryRepository.save(entry);
    _entries = await _entryRepository.loadAll();
    notifyListeners();
    return entry;
  }

  /// 点燃纸卷：燃烧 → 内容永久擦除 → 灰烬入土转化为养分。
  ///
  /// 这是 PRD 7.2 机制的完整结算：
  /// - 7.2.3 隐私保护：调用 [UnhappyEntry.burn] 物理清空原文与图片引用；
  /// - 7.2.3 养分转化：灰烬为花园增加养分（负向转化路径）；
  /// - 7.3 闭环：两条路径在养分池汇合。
  ///
  /// 燃烧不可逆，且不提供「随风飘散消失」等其他分支
  /// （PRD 7.2.2：灰烬入土是唯一归宿，保持机制单一纯粹）。
  Future<BurnScrollResult> burnScroll(UnhappyEntry entry) async {
    if (entry.isBurned) {
      throw StateError('该纸卷已于 ${entry.burnedAt} 燃烧，不可重复点燃');
    }

    final now = DateTime.now();
    final burned = entry.burn(now);

    await _entryRepository.save(burned);

    const nutrientGained = AppConstants.nutrientPerAsh;
    _garden = _garden.copyWith(
      nutrientValue: _garden.nutrientValue + nutrientGained,
      streakDays: _nextStreak(burned.occurredDay),
      lastRecordedDay: _laterDay(_garden.lastRecordedDay, burned.occurredDay),
    );

    await _gardenRepository.save(_garden);
    _entries = await _entryRepository.loadAll();
    notifyListeners();

    return BurnScrollResult(
      entry: burned,
      nutrientGained: nutrientGained,
      totalNutrient: _garden.nutrientValue,
    );
  }

  /// 删除一条记录。
  ///
  /// 注意：对已燃烧的纸卷，时光轴中只保留封条提示、不提供删除入口
  /// （PRD 7.2.3），因此本方法主要由开心事记录的编辑流程调用。
  Future<void> deleteEntry(String id) async {
    await _entryRepository.remove(id);
    _entries = await _entryRepository.loadAll();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 花园设置
  // ---------------------------------------------------------------------------

  /// 切换花园主题（PRD Tab4 换肤）。
  Future<void> changeTheme(String themeId) async {
    _garden = _garden.copyWith(themeId: themeId);
    await _gardenRepository.save(_garden);
    notifyListeners();
  }

  /// 清空全部数据。对应「隐私与数据设置」中的一键清除（PRD Tab4）。
  Future<void> clearAllData() async {
    await _entryRepository.clear();
    await _gardenRepository.clear();
    _entries = const <MoodEntry>[];
    _garden = GardenState.empty;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 生长阶段派生数据
  // ---------------------------------------------------------------------------

  /// 花园中每株植物当前的生长阶段分布。
  Map<GrowthStage, int> stageDistribution({DateTime? now}) =>
      _garden.stageDistributionAt(now ?? DateTime.now());

  /// 下一株即将开花的植物与所需天数，用于首页生成期待感文案。
  ({Flower flower, int days})? nextBlooming({DateTime? now}) =>
      _garden.nextBloomingAt(now ?? DateTime.now());

  // ---------------------------------------------------------------------------
  // 内部：连续记录天数
  // ---------------------------------------------------------------------------

  /// 依据本次记录归属日推算新的连续记录天数。
  ///
  /// 规则：
  /// - 首次记录 → 1；
  /// - 与上次记录同一天 → 保持不变（一天记多笔不重复累加）；
  /// - 与上次记录相差一天 → +1；
  /// - 补记过去的日期 → 不参与连续天数计算，保持不变；
  /// - 断档（相差 > 1 天）→ 重置为 1。
  int _nextStreak(DateTime occurredDay) {
    final last = _garden.lastRecordedDay;
    if (last == null) {
      return 1;
    }
    final diff = occurredDay.difference(last).inDays;
    if (diff <= 0) {
      return _garden.streakDays == 0 ? 1 : _garden.streakDays;
    }
    if (diff == 1) {
      return _garden.streakDays + 1;
    }
    return 1;
  }

  /// 取两个日期中较晚的一个，`null` 视为更早。
  DateTime _laterDay(DateTime? a, DateTime b) {
    if (a == null) {
      return b;
    }
    return b.isAfter(a) ? b : a;
  }
}
