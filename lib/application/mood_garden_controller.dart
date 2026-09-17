import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/id_generator.dart';
import '../domain/entities/entry_filter.dart';
import '../domain/entities/flower.dart';
import '../domain/entities/flower_species.dart';
import '../domain/entities/garden_state.dart';
import '../domain/entities/growth_stage.dart';
import '../domain/entities/mood_entry.dart';
import '../domain/entities/mood_tag.dart';
import '../domain/entities/tag_catalog.dart';
import '../domain/repositories/entry_image_store.dart';
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
    this.unlockedSpecies = const <FlowerSpecies>[],
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

  /// 本次记录**恰好解锁**的进化花种（PRD 7.1.3）。
  ///
  /// 界面据此给一次额外的正反馈；为空表示这次没有新解锁。
  final List<FlowerSpecies> unlockedSpecies;
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
    required EntryImageStore imageStore,
  })  : _entryRepository = entryRepository,
        _gardenRepository = gardenRepository,
        _imageStore = imageStore;

  final EntryRepository _entryRepository;
  final GardenRepository _gardenRepository;
  final EntryImageStore _imageStore;

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
  ///
  /// [filter] 为空时返回全部；否则只返回命中的记录（PRD Tab2 P2 的筛选）。
  List<MoodEntry> entriesOn(DateTime day, {EntryFilter? filter}) {
    final target = DateTime(day.year, day.month, day.day);
    final all = _entries.where((e) => e.occurredDay == target);
    if (filter == null || filter.isEmpty) {
      return all.toList(growable: false);
    }
    return all.where(filter.matches).toList(growable: false);
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

  /// 当前可选的标签（含已解锁的进化款与隐藏款，以及季节性可用性）。
  ///
  /// [customTags] 由设置控制器提供：自定义标签归设置管，
  /// 但「能不能种、种出什么花」必须和花园进度一起算，
  /// 所以组合这一步放在这里而不是界面里。
  List<SelectableTag> availableTags({
    List<MoodTag> customTags = const <MoodTag>[],
    DateTime? now,
  }) =>
      TagCatalog.available(
        garden: _garden,
        customTags: customTags,
        now: now,
      );

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
  ///
  /// [images] 是用户新选的图片字节（相册或拍照）。它们会被加密后各自存成
  /// 单独的文件，记录里只保留 id——明文图片不会被写进磁盘。
  Future<PlantSeedResult> plantSeed({
    required String tagId,
    required String text,
    String? speciesId,
    List<Uint8List> images = const <Uint8List>[],
    DateTime? occurredAt,
  }) async {
    final now = DateTime.now();
    final tag = resolveTag(tagId);
    // 界面可以显式指定花种（进化款、隐藏款、自定义标签都由它解析），
    // 不指定时按预设标签的固定对应关系推导。
    final resolvedSpeciesId = speciesId ?? tag.speciesId;

    // PRD 7.1.3 季节限定：非当季的花种不能种。
    // 界面会把这类标签显示为不可选，这里再守一道——
    // 否则任何绕过界面的调用都能把樱花种进十二月。
    final blockedReason = TagCatalog.unavailableReason(resolvedSpeciesId, now);
    if (blockedReason != null) {
      throw StateError('这个花种现在不能种（$blockedReason）');
    }

    final entry = HappyEntry(
      id: IdGenerator.next('happy'),
      occurredAt: occurredAt ?? now,
      createdAt: now,
      tagId: tagId,
      text: text,
      imagePaths: await _saveImages(images),
    );

    await _entryRepository.save(entry);

    // 新植物以记录归属时间为种下时间，保证补记的记录不会「一入土就开花」。
    final flower = Flower(
      id: IdGenerator.next('flower'),
      speciesId: resolvedSpeciesId,
      plantedAt: entry.occurredAt,
      nutrientBoost: _garden.nutrientValue,
    );

    final nextSeedCounts = Map<String, int>.of(_garden.seedCountBySpecies);
    final totalSeeds = (nextSeedCounts[resolvedSpeciesId] ?? 0) + 1;
    nextSeedCounts[resolvedSpeciesId] = totalSeeds;

    // PRD 7.1.3：同类标签攒够阈值 → 解锁进化花种。
    // 判定放在这里而不是界面，是为了保证「解锁」与「这一次记录」是同一个事务，
    // 不会因为界面没刷新而漏掉。
    final unlocked = Set<String>.of(_garden.unlockedSpeciesIds);
    final newlyUnlocked = <FlowerSpecies>[];
    for (final evolved in FlowerSpecies.evolvedFrom(resolvedSpeciesId)) {
      if (!unlocked.contains(evolved.id) &&
          totalSeeds >= AppConstants.evolutionUnlockCount) {
        unlocked.add(evolved.id);
        newlyUnlocked.add(evolved);
      }
    }

    const nutrientGained = AppConstants.nutrientPerSeed;

    _garden = _garden.copyWith(
      nutrientValue: _garden.nutrientValue + nutrientGained,
      seedCountBySpecies: nextSeedCounts,
      unlockedSpeciesIds: unlocked,
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
      species: FlowerSpecies.byId(resolvedSpeciesId) ?? FlowerSpecies.sunflower,
      totalSeedsOfSpecies: totalSeeds,
      seedsUntilNextBloom:
          AppConstants.seedsPerBloom - (totalSeeds % AppConstants.seedsPerBloom),
      nutrientGained: nutrientGained,
      unlockedSpecies: newlyUnlocked,
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
    List<Uint8List> images = const <Uint8List>[],
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

    final newImageIds = await _saveImages(images);

    final UnhappyEntry entry;
    if (existing == null) {
      entry = UnhappyEntry(
        id: IdGenerator.next('unhappy'),
        occurredAt: occurredAt ?? now,
        createdAt: now,
        text: text,
        imagePaths: newImageIds,
      );
    } else {
      // 继续编辑草稿时把新图追加到已有图后面，而不是覆盖——
      // 否则用户中途松手再补一张图，先前选的图就丢了。
      entry = existing.editContent(
        text: text,
        imagePaths: <String>[...existing.imagePaths, ...newImageIds],
      );
    }

    await _entryRepository.save(entry);
    _entries = await _entryRepository.loadAll();
    notifyListeners();
    return entry;
  }

  /// 点燃纸卷：燃烧 → 内容永久擦除 → 灰烬入土转化为养分。
  ///
  /// 这是 PRD 7.2 机制的完整结算：
  /// - 7.2.3 隐私保护：调用 [UnhappyEntry.burn] 物理清空原文与图片引用，
  ///   并**删除磁盘上的图片密文**；
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

    // 顺序是刻意的：先删图片密文，再落盘「已燃烧」的记录。
    //
    // 两种失败各会发生一次，代价并不对等：
    // - 先删后写失败 → 草稿记录里留下几个加载不出来的图片引用（界面小瑕疵）；
    // - 先写后删失败 → 磁盘上永久残留图片密文，而记录已经显示「已转化为养分」
    //   （隐私承诺被静默破坏）。
    // 后者是产品最核心的承诺，所以把删除放在前面。
    await _imageStore.deleteAll(entry.imagePaths);
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
    // 记录被删掉之后，它的附图 id 就再也无人引用，密文会永久残留成垃圾。
    // 所以先把图片一并删掉，再删记录本身。
    final target = _entries.where((entry) => entry.id == id).firstOrNull;
    if (target != null) {
      await _imageStore.deleteAll(target.imagePaths);
    }

    await _entryRepository.remove(id);
    _entries = await _entryRepository.loadAll();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 附图（PRD 7.1.1 / 7.2.1 的图片输入）
  // ---------------------------------------------------------------------------

  /// 读取一张附图，供界面解密展示。
  ///
  /// 返回 `null` 表示图片不存在或无法解密——界面应当优雅跳过这一张，
  /// 而不是让整页打不开。
  Future<Uint8List?> loadImage(String id) => _imageStore.read(id);

  /// 当前保存的附图数量，用于「隐私与数据」展示存储占用。
  Future<int> imageCount() => _imageStore.count();

  /// 把用户新选的图片加密存盘，返回它们的 id。
  Future<List<String>> _saveImages(List<Uint8List> images) async {
    if (images.isEmpty) {
      return const <String>[];
    }

    final ids = <String>[];
    for (final bytes in images) {
      ids.add(await _imageStore.save(bytes));
    }
    return ids;
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
    // 图片密文必须一起清掉：只清记录会留下永远无法访问、也无法删除的图片。
    await _imageStore.wipe();
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
