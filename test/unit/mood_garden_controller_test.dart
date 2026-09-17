import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mood_garden/application/mood_garden_controller.dart';
import 'package:mood_garden/core/constants/app_constants.dart';
import 'package:mood_garden/data/datasources/encrypted_image_store.dart';
import 'package:mood_garden/data/datasources/local_store.dart';
import 'package:mood_garden/data/repositories/local_entry_repository.dart';
import 'package:mood_garden/data/repositories/local_garden_repository.dart';
import 'package:mood_garden/domain/entities/flower_species.dart';
import 'package:mood_garden/domain/entities/garden_state.dart';
import 'package:mood_garden/domain/entities/garden_theme.dart';
import 'package:mood_garden/domain/entities/mood_entry.dart';
import 'package:mood_garden/domain/entities/mood_tag.dart';
import 'package:mood_garden/domain/entities/tag_catalog.dart';

/// 主控制器测试 —— 覆盖 PRD 第 7 章的三套核心机制。
void main() {
  MoodGardenController buildController() {
    final store = InMemoryLocalStore();
    return MoodGardenController(
      entryRepository: LocalEntryRepository(store),
      gardenRepository: LocalGardenRepository(store),
      imageStore: InMemoryEntryImageStore(),
    );
  }

  late MoodGardenController controller;

  setUp(() async {
    controller = buildController();
    await controller.load();
  });

  group('初始状态', () {
    test('新用户的花园为空', () {
      expect(controller.entries, isEmpty);
      expect(controller.garden.nutrientValue, 0);
      expect(controller.garden.flowers, isEmpty);
      expect(controller.garden.streakDays, 0);
      expect(controller.isLoading, isFalse);
    });
  });

  group('PRD 7.1 开心事记录 → 种花机制', () {
    test('种下一件开心事：写入记录、种下植物、增加养分', () async {
      final result = await controller.plantSeed(
        tagId: MoodTagId.gratitude,
        text: '路上遇到一只很亲人的橘猫',
      );

      // 记录落库
      expect(controller.entries, hasLength(1));
      expect(controller.entries.first, isA<HappyEntry>());

      // 植物入土
      expect(controller.garden.flowers, hasLength(1));
      expect(result.flower.speciesId, FlowerSpeciesId.sunflower);
      expect(result.species.name, '向日葵');

      // 养分增加（PRD 7.3 正向路径）
      expect(controller.garden.nutrientValue, AppConstants.nutrientPerSeed);
      expect(result.nutrientGained, AppConstants.nutrientPerSeed);
    });

    test('标签决定花种（PRD 7.1.1 步骤 3）', () async {
      await controller.plantSeed(tagId: MoodTagId.surprise, text: '收到意外的礼物');
      expect(controller.garden.flowers.first.speciesId, FlowerSpeciesId.tulip);

      await controller.plantSeed(tagId: MoodTagId.calm, text: '下午很安静');
      expect(controller.garden.flowers.last.speciesId, FlowerSpeciesId.clover);
    });

    test('收集进度提示符合 PRD 7.1.2 示例文案的语义', () async {
      // 第 1 颗种子：再种 9 颗
      final first = await controller.plantSeed(
        tagId: MoodTagId.gratitude,
        text: '第 1 件',
      );
      expect(first.totalSeedsOfSpecies, 1);
      expect(first.seedsUntilNextBloom, 9);

      // 累积到第 7 颗时应为「再种 3 颗」，与 PRD 示例一致
      for (var i = 2; i <= 7; i++) {
        await controller.plantSeed(
          tagId: MoodTagId.gratitude,
          text: '第 $i 件',
        );
      }
      expect(controller.garden.seedsOfSpecies(FlowerSpeciesId.sunflower), 7);
      expect(
        controller.garden.seedsUntilNextBloom(FlowerSpeciesId.sunflower),
        3,
        reason: 'PRD 示例：向日葵第 7 颗种子，再种 3 颗会长出第一朵花',
      );
    });

    test('不同花种的收集进度互相独立', () async {
      await controller.plantSeed(tagId: MoodTagId.gratitude, text: 'a');
      await controller.plantSeed(tagId: MoodTagId.gratitude, text: 'b');
      await controller.plantSeed(tagId: MoodTagId.surprise, text: 'c');

      expect(controller.garden.seedsOfSpecies(FlowerSpeciesId.sunflower), 2);
      expect(controller.garden.seedsOfSpecies(FlowerSpeciesId.tulip), 1);
      expect(controller.garden.seedsOfSpecies(FlowerSpeciesId.clover), 0);
    });

    test('补记过去的日期：植物以归属时间为种下时间，不会「一入土就开花」', () async {
      final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10));
      final result = await controller.plantSeed(
        tagId: MoodTagId.gratitude,
        text: '想起十年前的今天',
        occurredAt: tenDaysAgo,
      );

      expect(result.entry.isBackfilled, isTrue);
      expect(result.flower.plantedAt, tenDaysAgo);
      // 十天后状态是开花，因为「时间已经流逝」——这正是活地图心智
      expect(result.flower.isBloomingAt(DateTime.now()), isTrue);
    });

    test('今日种下数量统计正确', () async {
      expect(controller.todayPlantedCount, 0);
      await controller.plantSeed(tagId: MoodTagId.gratitude, text: 'today');
      expect(controller.todayPlantedCount, 1);

      await controller.plantSeed(
        tagId: MoodTagId.gratitude,
        text: 'yesterday',
        occurredAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(controller.todayPlantedCount, 1, reason: '昨天的不计入今日');
    });

    test('季节限定：非当季不能种樱花（PRD 7.1.3）', () async {
      // 樱花只在 3-4 月可种。测试不依赖跑测试时正好是哪个月，
      // 而是直接用 TagCatalog 判定「现在是否当季」，再断言控制器与它一致。
      final now = DateTime.now();
      final inSeason = TagCatalog.isPlantable(FlowerSpeciesId.sakura, now);

      if (inSeason) {
        // 当季：应当能种，并长成樱花
        final result = await controller.plantSeed(
          tagId: MoodTagId.food,
          text: '当季的樱花',
        );
        expect(result.species.id, FlowerSpeciesId.sakura);
      } else {
        // 非当季：控制器必须拦住，不能只靠界面置灰
        await expectLater(
          controller.plantSeed(tagId: MoodTagId.food, text: '不当季的樱花'),
          throwsA(isA<StateError>()),
        );
        expect(
          controller.garden.flowers,
          isEmpty,
          reason: '被拦下的记录不该在花园里留下任何东西',
        );
      }
    });

    test('季节限定的提示文案与花种定义一致', () {
      // 1 月一定不是樱花季
      final january = DateTime(2026, 1, 15);
      expect(TagCatalog.isPlantable(FlowerSpeciesId.sakura, january), isFalse);
      expect(TagCatalog.unavailableReason(FlowerSpeciesId.sakura, january),
          isNotNull);

      // 4 月在季内
      final april = DateTime(2026, 4, 15);
      expect(TagCatalog.isPlantable(FlowerSpeciesId.sakura, april), isTrue);
      expect(
        TagCatalog.unavailableReason(FlowerSpeciesId.sakura, april),
        isNull,
      );

      // 非季节限定花种任何时候都可种
      expect(
        TagCatalog.isPlantable(FlowerSpeciesId.sunflower, january),
        isTrue,
      );
    });
  });

  group('PRD 7.2 不开心事 → 点燃纸卷 → 灰烬化肥料', () {
    test('保存草稿不会增加养分', () async {
      final draft = await controller.saveScrollDraft(text: '今天有点难过');

      expect(draft.isBurned, isFalse);
      expect(controller.garden.nutrientValue, 0);
      expect(controller.pendingScrolls, hasLength(1));
    });

    test('燃烧：内容被擦除 + 养分增加（PRD 7.2.3）', () async {
      final draft = await controller.saveScrollDraft(text: '一件很糟的事');
      final result = await controller.burnScroll(draft);

      // 内容擦除
      expect(result.entry.isBurned, isTrue);
      expect(result.entry.text, isEmpty);
      expect(result.entry.hasReadableContent, isFalse);

      // 养分转化（负向路径）
      expect(result.nutrientGained, AppConstants.nutrientPerAsh);
      expect(controller.garden.nutrientValue, AppConstants.nutrientPerAsh);
      expect(result.totalNutrient, AppConstants.nutrientPerAsh);
    });

    test('燃烧后存储中不再保留原文', () async {
      final draft = await controller.saveScrollDraft(text: '不该被留下的内容');
      await controller.burnScroll(draft);

      final stored = controller.entries.whereType<UnhappyEntry>().single;
      expect(stored.text, isEmpty);
      expect(stored.isBurned, isTrue);
    });

    test('已燃烧的纸卷不能重复点燃', () async {
      final draft = await controller.saveScrollDraft(text: '烧一次');
      await controller.burnScroll(draft);

      final burned = controller.entries.whereType<UnhappyEntry>().single;
      expect(
        () => controller.burnScroll(burned),
        throwsA(isA<StateError>()),
      );
    });

    test('燃烧会连同附图一起删除（PRD 7.2.3「不可恢复」在图片上的落点）',
        () async {
      final images = InMemoryEntryImageStore();
      final local = MoodGardenController(
        entryRepository: LocalEntryRepository(InMemoryLocalStore()),
        gardenRepository: LocalGardenRepository(InMemoryLocalStore()),
        imageStore: images,
      );

      final draft = await local.saveScrollDraft(
        text: '带着照片的不开心事',
        images: <Uint8List>[_imageBytes(1), _imageBytes(2)],
      );

      expect(draft.imagePaths, hasLength(2), reason: '两张图都应已存下');
      expect(await images.count(), 2);

      await local.burnScroll(draft);

      expect(
        await images.count(),
        0,
        reason: '记录里的图片引用被清空的同时，图片本身也必须消失——'
            '否则「原文不可恢复」在图片上就是一句空话',
      );
      expect(await images.read(draft.imagePaths.first), isNull);
    });

    test('种下带图开心事：图片被保存且记录持有其 id', () async {
      final images = InMemoryEntryImageStore();
      final local = MoodGardenController(
        entryRepository: LocalEntryRepository(InMemoryLocalStore()),
        gardenRepository: LocalGardenRepository(InMemoryLocalStore()),
        imageStore: images,
      );

      final result = await local.plantSeed(
        tagId: MoodTagId.gratitude,
        text: '今天拍了张好看的照片',
        images: <Uint8List>[_imageBytes(3)],
      );

      expect(result.entry.imagePaths, hasLength(1));
      expect(await images.count(), 1);
      expect(await local.loadImage(result.entry.imagePaths.single), isNotNull);
    });

    test('删除记录会连同附图一起清理，不留孤儿密文', () async {
      final images = InMemoryEntryImageStore();
      final local = MoodGardenController(
        entryRepository: LocalEntryRepository(InMemoryLocalStore()),
        gardenRepository: LocalGardenRepository(InMemoryLocalStore()),
        imageStore: images,
      );

      final result = await local.plantSeed(
        tagId: MoodTagId.calm,
        text: '一件小事',
        images: <Uint8List>[_imageBytes(4)],
      );
      expect(await images.count(), 1);

      await local.deleteEntry(result.entry.id);

      expect(await images.count(), 0);
    });

    test('清除全部数据会清掉图片密文', () async {
      final images = InMemoryEntryImageStore();
      final local = MoodGardenController(
        entryRepository: LocalEntryRepository(InMemoryLocalStore()),
        gardenRepository: LocalGardenRepository(InMemoryLocalStore()),
        imageStore: images,
      );

      await local.plantSeed(
        tagId: MoodTagId.surprise,
        text: 'x',
        images: <Uint8List>[_imageBytes(5)],
      );

      await local.clearAllData();

      expect(await images.count(), 0);
    });

    test('燃烧后不再出现在待点燃列表中', () async {
      final draft = await controller.saveScrollDraft(text: '烧掉');
      expect(controller.pendingScrolls, hasLength(1));

      await controller.burnScroll(draft);
      expect(controller.pendingScrolls, isEmpty);
    });

    test('今日转化数量统计正确', () async {
      final draft = await controller.saveScrollDraft(text: 'x');
      expect(controller.todayBurnedCount, 0);

      await controller.burnScroll(draft);
      expect(controller.todayBurnedCount, 1);
    });
  });

  group('PRD 7.3 花园养分系统：两条路径汇入同一养分池', () {
    test('种花与烧灰的养分累加（正负情绪协同滋养同一片花园）', () async {
      await controller.plantSeed(tagId: MoodTagId.gratitude, text: '开心事');

      final draft = await controller.saveScrollDraft(text: '不开心事');
      await controller.burnScroll(draft);

      expect(
        controller.garden.nutrientValue,
        AppConstants.nutrientPerSeed + AppConstants.nutrientPerAsh,
      );
    });

    test('负向转化带来的养分不低于正向记录（PRD 7.2.3 价值观）', () {
      expect(
        AppConstants.nutrientPerAsh,
        greaterThanOrEqualTo(AppConstants.nutrientPerSeed),
        reason: '不应对负向情绪做任何数值上的贬抑',
      );
    });

    test('养分进度与活力描述随养分增长', () async {
      expect(controller.garden.nutrientProgress, 0);
      expect(controller.garden.vitalityLabel, '静待播种');

      for (var i = 0; i < 40; i++) {
        await controller.plantSeed(tagId: MoodTagId.gratitude, text: '$i');
      }

      expect(controller.garden.nutrientProgress, greaterThan(0));
      expect(controller.garden.vitalityLabel, isNot('静待播种'));
    });
  });

  group('连续记录天数（PRD 7.1.3 隐藏款解锁依据）', () {
    test('首次记录为 1 天', () async {
      await controller.plantSeed(tagId: MoodTagId.calm, text: 'x');
      expect(controller.garden.streakDays, 1);
    });

    test('同一天记录多笔不重复累加', () async {
      final today = DateTime.now();
      await controller.plantSeed(
        tagId: MoodTagId.calm,
        text: 'a',
        occurredAt: today,
      );
      await controller.plantSeed(
        tagId: MoodTagId.calm,
        text: 'b',
        occurredAt: today,
      );

      expect(controller.garden.streakDays, 1);
    });

    test('连续两天记录累加', () async {
      final now = DateTime.now();
      await controller.plantSeed(
        tagId: MoodTagId.calm,
        text: 'a',
        occurredAt: now.subtract(const Duration(days: 1)),
      );
      await controller.plantSeed(
        tagId: MoodTagId.calm,
        text: 'b',
        occurredAt: now,
      );

      expect(controller.garden.streakDays, 2);
    });

    test('断档超过一天后重新计数', () async {
      final now = DateTime.now();
      await controller.plantSeed(
        tagId: MoodTagId.calm,
        text: 'a',
        occurredAt: now.subtract(const Duration(days: 5)),
      );
      expect(controller.garden.streakDays, 1);

      await controller.plantSeed(
        tagId: MoodTagId.calm,
        text: 'b',
        occurredAt: now,
      );
      expect(controller.garden.streakDays, 1, reason: '断了就要重新开始');
    });

    test('未达阈值时隐藏款未解锁', () async {
      await controller.plantSeed(tagId: MoodTagId.calm, text: 'x');
      expect(controller.garden.hiddenSpeciesUnlocked, isFalse);
      expect(
        controller.garden.daysToHiddenSpecies,
        AppConstants.hiddenSpeciesStreakDays - 1,
      );
    });
  });

  group('花园主题与数据管理', () {
    test('切换主题', () async {
      expect(controller.garden.themeId, GardenThemeId.sunflowerField);

      await controller.changeTheme(GardenThemeId.sakuraValley);
      expect(controller.garden.themeId, GardenThemeId.sakuraValley);
      expect(controller.garden.theme.name, '樱花谷');
    });

    test('未知主题 id 回退到默认主题', () async {
      await controller.changeTheme('not_a_theme');
      expect(controller.garden.theme.id, GardenThemeId.sunflowerField);
    });

    test('清空全部数据', () async {
      await controller.plantSeed(tagId: MoodTagId.calm, text: 'x');
      final draft = await controller.saveScrollDraft(text: 'y');
      await controller.burnScroll(draft);

      expect(controller.entries, isNotEmpty);

      await controller.clearAllData();

      expect(controller.entries, isEmpty);
      expect(controller.garden.nutrientValue, 0);
      expect(controller.garden.flowers, isEmpty);
    });
  });

  group('查询能力', () {
    test('按日期查询记录', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));

      await controller.plantSeed(
        tagId: MoodTagId.calm,
        text: 'today',
        occurredAt: today,
      );
      await controller.plantSeed(
        tagId: MoodTagId.calm,
        text: 'yesterday',
        occurredAt: yesterday,
      );

      expect(controller.entriesOn(today), hasLength(1));
      expect(controller.entriesOn(yesterday), hasLength(1));
      expect(controller.happyEntriesOn(today), hasLength(1));
      expect(controller.unhappyEntriesOn(today), isEmpty);
    });

    test('记录按时间倒序返回', () async {
      final now = DateTime.now();
      await controller.plantSeed(
        tagId: MoodTagId.calm,
        text: '早',
        occurredAt: now.subtract(const Duration(hours: 5)),
      );
      await controller.plantSeed(
        tagId: MoodTagId.calm,
        text: '晚',
        occurredAt: now,
      );

      expect((controller.entries.first as HappyEntry).text, '晚');
    });

    test('生长阶段分布统计', () async {
      await controller.plantSeed(
        tagId: MoodTagId.calm,
        text: '刚种下',
        occurredAt: DateTime.now(),
      );
      await controller.plantSeed(
        tagId: MoodTagId.calm,
        text: '十天前种的',
        occurredAt: DateTime.now().subtract(const Duration(days: 10)),
      );

      final distribution = controller.stageDistribution();
      expect(distribution.values.reduce((a, b) => a + b), 2);
    });
  });

  group('PRD 7.1.3 进阶收集玩法（端到端）', () {
    test('攒够同类记录后解锁进化花种，并能真的种下它', () async {
      const need = AppConstants.evolutionUnlockCount;

      PlantSeedResult? last;
      for (var i = 0; i < need; i++) {
        last = await controller.plantSeed(
          tagId: MoodTagId.gratitude,
          text: '第 ${i + 1} 件开心事',
        );
      }

      // 第 need 次记录恰好触发解锁
      expect(last!.unlockedSpecies, hasLength(1));
      expect(last.unlockedSpecies.single.id, FlowerSpeciesId.goldenSunflower);
      expect(
        controller.garden.isSpeciesUnlocked(FlowerSpeciesId.goldenSunflower),
        isTrue,
      );

      // 解锁之后不该重复上报（否则每次记录都弹一次「解锁了」）
      final again = await controller.plantSeed(
        tagId: MoodTagId.gratitude,
        text: '再来一件',
      );
      expect(again.unlockedSpecies, isEmpty);

      // 标签列表里出现进化款
      final evolved = controller
          .availableTags(now: DateTime(2026, 5, 1))
          .where((item) => item.isEvolved)
          .toList();
      expect(evolved, hasLength(1));
      expect(evolved.single.tag.speciesId, FlowerSpeciesId.goldenSunflower);

      // 能真的种下，且花园里出现的是金向日葵而不是向日葵
      final planted = await controller.plantSeed(
        tagId: evolved.single.tag.id,
        speciesId: evolved.single.tag.speciesId,
        text: '进化形态',
      );
      expect(planted.species.id, FlowerSpeciesId.goldenSunflower);
      expect(
        controller.garden.flowers
            .where((f) => f.speciesId == FlowerSpeciesId.goldenSunflower),
        hasLength(1),
      );
    });

    test('隐藏款：连续记录达标后可以种月光花', () async {
      // 直接构造一个已达标的花园，逐日补记太慢且会依赖系统时钟
      final local = MoodGardenController(
        entryRepository: LocalEntryRepository(InMemoryLocalStore()),
        gardenRepository: LocalGardenRepository(InMemoryLocalStore()),
        imageStore: InMemoryEntryImageStore(),
      );
      await local.load();

      final hidden = TagCatalog.available(
        garden: GardenState.empty.copyWith(
          streakDays: AppConstants.hiddenSpeciesStreakDays,
        ),
        now: DateTime(2026, 5, 1),
      ).where((item) => item.isHidden).toList();

      expect(hidden, hasLength(1), reason: '达标后应出现隐藏款标签');

      final planted = await local.plantSeed(
        tagId: hidden.single.tag.id,
        speciesId: hidden.single.tag.speciesId,
        text: '坚持了很久',
      );

      expect(planted.species.id, FlowerSpeciesId.moonflower);
    });
  });
}

/// 造一段可识别的假图片字节，用于验证「存下去 / 删干净」。
Uint8List _imageBytes(int seed) => Uint8List.fromList(
      <int>[0xFF, 0xD8, 0xFF, 0xE0, ...List<int>.filled(32, seed % 256)],
    );
