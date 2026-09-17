import 'package:flutter_test/flutter_test.dart';
import 'package:mood_garden/core/constants/app_constants.dart';
import 'package:mood_garden/domain/entities/flower.dart';
import 'package:mood_garden/domain/entities/flower_species.dart';
import 'package:mood_garden/domain/entities/garden_state.dart';
import 'package:mood_garden/domain/entities/mood_tag.dart';
import 'package:mood_garden/domain/entities/tag_catalog.dart';

/// PRD 7.1.3「进阶收集玩法」的规则测试。
///
/// 这三种玩法（进化花种 / 隐藏款 / 季节限定）最终都收敛成同一个问题：
/// **此刻这个标签能不能种、不能种的话为什么。**
/// 全部逻辑集中在 [TagCatalog]，因此可以脱离界面与存储逐条钉住。
void main() {
  /// 樱花季内 / 季外两个固定时刻，避免测试结果随跑测试的月份漂移。
  final inSakuraSeason = DateTime(2026, 4, 10);
  final outOfSakuraSeason = DateTime(2026, 1, 10);

  GardenState gardenWith({
    int streak = 0,
    Map<String, int> seeds = const <String, int>{},
    Set<String> unlocked = const <String>{},
    List<Flower> flowers = const <Flower>[],
  }) {
    return GardenState(
      streakDays: streak,
      petalStockBySpecies: seeds,
      unlockedSpeciesIds: unlocked,
      flowers: flowers,
    );
  }

  group('基础：预设标签始终可选', () {
    test('空花园也给出全部预设标签', () {
      final tags = TagCatalog.available(
        garden: GardenState.empty,
        now: inSakuraSeason,
      );

      expect(tags.length, MoodTag.presets.length);
      expect(
        tags.every((item) => item.isAvailable),
        isTrue,
        reason: '樱花季内所有预设都应可种',
      );
      expect(tags.any((item) => item.isEvolved), isFalse);
      expect(tags.any((item) => item.isHidden), isFalse);
    });

    test('自定义标签追加在最后', () {
      const custom = MoodTag(
        id: '${MoodTagId.customPrefix}_x',
        label: '散步',
        emoji: '🌙',
        speciesId: FlowerSpeciesId.clover,
        isCustom: true,
      );

      final tags = TagCatalog.available(
        garden: GardenState.empty,
        customTags: <MoodTag>[custom],
        now: inSakuraSeason,
      );

      expect(tags.last.tag.id, custom.id);
      expect(tags.length, MoodTag.presets.length + 1);
    });
  });

  group('PRD 7.1.3 进化花种', () {
    test('未达阈值时不出现进化款', () {
      final tags = TagCatalog.available(
        garden: gardenWith(
          seeds: <String, int>{FlowerSpeciesId.sunflower: 5},
        ),
        now: inSakuraSeason,
      );

      expect(tags.any((item) => item.isEvolved), isFalse);
      expect(
        TagCatalog.recordsToEvolution(
          gardenWith(seeds: <String, int>{FlowerSpeciesId.sunflower: 5}),
          FlowerSpeciesId.sunflower,
        ),
        AppConstants.evolutionUnlockCount - 5,
      );
    });

    test('解锁集合里有它时，进化款出现且可种', () {
      final tags = TagCatalog.available(
        garden: gardenWith(
          seeds: <String, int>{
            FlowerSpeciesId.sunflower: AppConstants.evolutionUnlockCount,
          },
          unlocked: <String>{FlowerSpeciesId.goldenSunflower},
        ),
        now: inSakuraSeason,
      );

      final evolved = tags.where((item) => item.isEvolved).toList();
      expect(evolved, hasLength(1));
      expect(evolved.single.tag.speciesId, FlowerSpeciesId.goldenSunflower);
      expect(evolved.single.tag.label, '感恩', reason: '进化款沿用原心情的名字');
      expect(evolved.single.isAvailable, isTrue);
    });

    test('进化款 id 可还原为对应的基础标签', () {
      const evolvedId = '${MoodTagId.gratitude}${TagCatalog.evolvedSuffix}';

      expect(TagCatalog.isEvolvedTagId(evolvedId), isTrue);
      expect(TagCatalog.baseTagIdOf(evolvedId), MoodTagId.gratitude);

      final displayed = TagCatalog.displayTag(evolvedId);
      expect(displayed, isNotNull);
      expect(displayed!.label, '感恩');
      expect(displayed.speciesId, FlowerSpeciesId.goldenSunflower);
    });
  });

  group('PRD 7.1.3 隐藏款', () {
    test('连续记录未达标时不出现', () {
      final tags = TagCatalog.available(
        garden: gardenWith(
          streak: AppConstants.hiddenSpeciesStreakDays - 1,
        ),
        now: inSakuraSeason,
      );

      expect(tags.any((item) => item.isHidden), isFalse);
    });

    test('达标后出现，且标记为隐藏款', () {
      final tags = TagCatalog.available(
        garden: gardenWith(streak: AppConstants.hiddenSpeciesStreakDays),
        now: inSakuraSeason,
      );

      final hidden = tags.where((item) => item.isHidden).toList();
      expect(hidden, hasLength(1));
      expect(hidden.single.tag.speciesId, FlowerSpeciesId.moonflower);
      expect(hidden.single.tag.label, '月光花');
    });

    test('隐藏款不看解锁集合，只看连续天数', () {
      final garden = gardenWith(streak: AppConstants.hiddenSpeciesStreakDays);
      expect(garden.isSpeciesUnlocked(FlowerSpeciesId.moonflower), isTrue);

      final notYet = gardenWith(streak: 3);
      expect(notYet.isSpeciesUnlocked(FlowerSpeciesId.moonflower), isFalse);
    });

    test('隐藏款 id 可还原出花种名', () {
      final displayed = TagCatalog.displayTag(
        '${MoodTagId.hiddenPrefix}_${FlowerSpeciesId.moonflower}',
      );

      expect(displayed, isNotNull);
      expect(displayed!.label, '月光花');
      expect(displayed.speciesId, FlowerSpeciesId.moonflower);
    });
  });

  group('PRD 7.1.3 季节限定', () {
    test('樱花在非当季被标记为不可用，并给出可种月份', () {
      final tags = TagCatalog.available(
        garden: GardenState.empty,
        now: outOfSakuraSeason,
      );

      final sakura = tags.firstWhere(
        (item) => item.tag.speciesId == FlowerSpeciesId.sakura,
      );
      expect(sakura.isAvailable, isFalse);
      expect(sakura.unavailableReason, contains('3-4'));
    });

    test('当季时可种', () {
      final tags = TagCatalog.available(
        garden: GardenState.empty,
        now: inSakuraSeason,
      );

      final sakura = tags.firstWhere(
        (item) => item.tag.speciesId == FlowerSpeciesId.sakura,
      );
      expect(sakura.isAvailable, isTrue);
      expect(sakura.unavailableReason, isNull);
    });

    test('非季节限定花种不受月份影响', () {
      for (final month in <int>[1, 6, 12]) {
        expect(
          TagCatalog.isPlantable(
            FlowerSpeciesId.sunflower,
            DateTime(2026, month, 1),
          ),
          isTrue,
        );
      }
    });

    test('未知花种不拦（避免旧数据里的花种把用户卡死）', () {
      expect(
        TagCatalog.isPlantable('some_removed_species', inSakuraSeason),
        isTrue,
      );
      expect(
        TagCatalog.unavailableReason('some_removed_species', inSakuraSeason),
        isNull,
      );
    });
  });

  group('displayTag 的降级行为', () {
    test('预设标签直接命中', () {
      expect(TagCatalog.displayTag(MoodTagId.gratitude)?.label, '感恩');
    });

    test('自定义标签需要传入表才能还原', () {
      const custom = MoodTag(
        id: '${MoodTagId.customPrefix}_y',
        label: '夜跑',
        emoji: '🏃',
        speciesId: FlowerSpeciesId.clover,
        isCustom: true,
      );

      expect(TagCatalog.displayTag(custom.id), isNull);
      expect(
        TagCatalog.displayTag(custom.id, customTags: <MoodTag>[custom])?.label,
        '夜跑',
      );
    });

    test('完全无法识别的 id 返回 null，由界面决定降级显示', () {
      expect(TagCatalog.displayTag('nonsense_id'), isNull);
    });
  });
}
