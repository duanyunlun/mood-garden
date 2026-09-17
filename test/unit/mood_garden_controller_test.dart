import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mood_garden/application/mood_garden_controller.dart';
import 'package:mood_garden/core/constants/app_constants.dart';
import 'package:mood_garden/data/datasources/encrypted_image_store.dart';
import 'package:mood_garden/data/datasources/local_store.dart';
import 'package:mood_garden/data/repositories/local_entry_repository.dart';
import 'package:mood_garden/data/repositories/local_garden_repository.dart';
import 'package:mood_garden/domain/entities/flower.dart';
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
    test('记下一件小事：落库、计入当天进度，但还不产出花瓣', () async {
      final result = await controller.plantSeed(
        tagId: MoodTagId.gratitude,
        text: '路上遇到一只很亲人的橘猫',
      );

      // 记录落库
      expect(controller.entries, hasLength(1));
      expect(controller.entries.first, isA<HappyEntry>());

      // 原型 v5 的规则：一天要记满 3 件才产出一片花瓣，
      // 所以第 1 件不产花瓣、不加养分、也不往花园里放植物。
      expect(result.petalEarned, isFalse);
      expect(result.petalStock, 0);
      expect(result.thingsUntilPetal, AppConstants.thingsPerPetal - 1);
      expect(result.nutrientGained, 0);
      expect(controller.garden.nutrientValue, 0);
      expect(controller.garden.flowers, isEmpty);
      expect(result.species.name, '向日葵');
    });

    test('一天记满 3 件才收获一片花瓣，并加养分', () async {
      for (var i = 1; i <= AppConstants.thingsPerPetal; i++) {
        final r = await controller.plantSeed(
          tagId: MoodTagId.gratitude,
          text: '第 $i 件',
        );
        if (i < AppConstants.thingsPerPetal) {
          expect(r.petalEarned, isFalse, reason: '第 $i 件不该产出花瓣');
        } else {
          expect(r.petalEarned, isTrue, reason: '第 3 件应当产出花瓣');
          expect(r.petalStock, 1);
          expect(r.nutrientGained, AppConstants.nutrientPerPetal);
        }
      }

      expect(controller.garden.petalsOfSpecies(FlowerSpeciesId.sunflower), 1);
      expect(controller.garden.nutrientValue, AppConstants.nutrientPerPetal);
      // 花瓣归零，开始攒下一个花苞
      expect(controller.garden.thingsTowardPetal, 0);
    });

    test('花瓣的花种由当天用得最多的标签决定（原型 plantSeed）', () async {
      // 感恩 2 件 + 惊喜 1 件 → 这一片花瓣属于「感恩」（当天最多）
      await controller.plantSeed(tagId: MoodTagId.gratitude, text: 'a');
      await controller.plantSeed(tagId: MoodTagId.gratitude, text: 'b');
      final third = await controller.plantSeed(
        tagId: MoodTagId.surprise,
        text: 'c',
      );

      expect(third.petalEarned, isTrue);
      expect(
        controller.garden.petalsOfSpecies(FlowerSpeciesId.sunflower),
        1,
        reason: '感恩当天出现最多，花瓣应归给向日葵',
      );
      expect(
        controller.garden.petalsOfSpecies(FlowerSpeciesId.tulip),
        0,
        reason: '惊喜只出现一次，不该拿到这片花瓣',
      );
    });

    test('攒满 5 片花瓣开出一朵花（原型 PETALS_PER_FLOWER）', () async {
      Flower? bloomed;
      FlowerSpecies? bloomedSpecies;

      // 每 3 件产出一片花瓣，攒满 5 片需要 15 件
      const need = AppConstants.petalsPerBloom * AppConstants.thingsPerPetal;
      for (var i = 1; i <= need; i++) {
        final r = await controller.plantSeed(
          tagId: MoodTagId.gratitude,
          text: '第 $i 件',
        );
        if (r.flower != null) {
          bloomed = r.flower;
          bloomedSpecies = r.bloomedSpecies;
        }
      }

      expect(controller.garden.petalsOfSpecies(FlowerSpeciesId.sunflower),
          AppConstants.petalsPerBloom);
      expect(bloomed, isNotNull, reason: '攒满 5 片应当开出一朵花');
      expect(bloomedSpecies?.id, FlowerSpeciesId.sunflower);
      expect(controller.garden.flowers, hasLength(1));
      expect(controller.garden.budProgress, 0, reason: '开花后花苞重新开始攒');
    });

    test('不同花种的收集进度互相独立', () async {
      // 每个花种各自攒花瓣：感恩记满 3 件得 1 片向日葵花瓣，
      // 平静的计数不受影响。
      for (var i = 1; i <= AppConstants.thingsPerPetal; i++) {
        await controller.plantSeed(tagId: MoodTagId.gratitude, text: 'g$i');
      }
      expect(controller.garden.petalsOfSpecies(FlowerSpeciesId.sunflower), 1);
      expect(controller.garden.petalsOfSpecies(FlowerSpeciesId.clover), 0);
    });

    test('补记过去的日期：花瓣按记录归属的那一天聚合', () async {
      final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10));

      // 补记上周的三件小事，同样应当攒够一片花瓣——
      // 计数器跟着记录归属的那一天走，而不是跟着「今天」。
      for (var i = 1; i <= AppConstants.thingsPerPetal; i++) {
        await controller.plantSeed(
          tagId: MoodTagId.gratitude,
          text: '十天前第 $i 件',
          occurredAt: tenDaysAgo,
        );
      }

      expect(controller.garden.petalsOfSpecies(FlowerSpeciesId.sunflower), 1);
      expect(controller.garden.petalProgressDay, DateTime(
        tenDaysAgo.year,
        tenDaysAgo.month,
        tenDaysAgo.day,
      ));
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
      // 正向路径要记满 3 件才产出一片花瓣，也才带来养分。
      for (var i = 1; i <= AppConstants.thingsPerPetal; i++) {
        await controller.plantSeed(tagId: MoodTagId.gratitude, text: '开心事 $i');
      }

      final draft = await controller.saveScrollDraft(text: '不开心事');
      await controller.burnScroll(draft);

      expect(
        controller.garden.nutrientValue,
        AppConstants.nutrientPerPetal + AppConstants.nutrientPerAsh,
      );
    });

    test('负向转化带来的养分不低于正向记录（PRD 7.2.3 价值观）', () {
      expect(
        AppConstants.nutrientPerAsh,
        greaterThanOrEqualTo(AppConstants.nutrientPerPetal),
        reason: '不应对负向情绪做任何数值上的贬抑',
      );
    });

    test('养分进度与活力描述随养分增长', () async {
      expect(controller.garden.nutrientProgress, 0);
      expect(controller.garden.vitalityLabel, '静待播种');

      // 养分跟着花瓣走，而花瓣要每 3 件小事才产出 1 片；
      // 想让活力描述跳出「静待播种」，记录数必须按这个比例给足。
      const records = 60; // → 20 片花瓣 → 200 养分 → 越过 15% 档位
      for (var i = 0; i < records; i++) {
        await controller.plantSeed(tagId: MoodTagId.gratitude, text: '$i');
      }

      expect(controller.garden.totalPetals, records ~/ AppConstants.thingsPerPetal);
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
      // 花在攒满 5 片花瓣时绽放，攒够 2 朵需要 30 件小事。
      // 归到同一天，确保花瓣都产出来。
      final day = DateTime.now().subtract(const Duration(days: 10));
      for (var i = 0; i < AppConstants.petalsPerBloom * AppConstants.thingsPerPetal * 2; i++) {
        await controller.plantSeed(
          tagId: MoodTagId.calm,
          text: '第 $i 件',
          occurredAt: day,
        );
      }

      expect(controller.garden.flowers, hasLength(2));
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
      // 花只在攒满花瓣时绽放，所以这里验证的是「这片花瓣归到了进化花种名下」，
      // 而不是「立刻长出一株植物」。
      expect(planted.petalEarned, isFalse, reason: '单条记录不产出花瓣');
      expect(planted.species.id, FlowerSpeciesId.goldenSunflower);
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
