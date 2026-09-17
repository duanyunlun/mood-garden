import 'package:flutter_test/flutter_test.dart';
import 'package:mood_garden/core/constants/app_constants.dart';
import 'package:mood_garden/domain/entities/flower.dart';
import 'package:mood_garden/domain/entities/flower_species.dart';
import 'package:mood_garden/domain/entities/garden_state.dart';
import 'package:mood_garden/domain/entities/growth_stage.dart';

/// 花园聚合状态测试（PRD 7.3 养分系统 / Tab3 图鉴收集度）。
void main() {
  final now = DateTime(2026, 3, 16, 12);

  GardenState buildGarden({
    int nutrient = 0,
    int streak = 0,
    List<Flower> flowers = const <Flower>[],
    Map<String, int> seeds = const <String, int>{},
  }) {
    return GardenState(
      nutrientValue: nutrient,
      streakDays: streak,
      flowers: flowers,
      petalStockBySpecies: seeds,
    );
  }

  Flower flower({
    required String id,
    required String speciesId,
    required DateTime plantedAt,
  }) =>
      Flower(id: id, speciesId: speciesId, plantedAt: plantedAt);

  group('养分值（PRD 7.3）', () {
    test('进度与百分比换算正确', () {
      final garden = buildGarden(nutrient: AppConstants.nutrientLevelCap ~/ 2);
      expect(garden.nutrientProgress, closeTo(0.5, 0.01));
      expect(garden.nutrientProgressPercent, 50);
    });

    test('养分超出上限时进度封顶为 1.0', () {
      final garden = buildGarden(nutrient: AppConstants.nutrientLevelCap * 5);
      expect(garden.nutrientProgress, 1.0);
    });

    test('活力描述随养分变化', () {
      expect(buildGarden().vitalityLabel, '静待播种');
      expect(
        buildGarden(nutrient: AppConstants.nutrientLevelCap).vitalityLabel,
        '郁郁葱葱',
      );
    });

    test('距下一等级所需养分为 0 时表示已满', () {
      final full = buildGarden(nutrient: AppConstants.nutrientLevelCap);
      expect(full.nutrientToNextLevel, 0);
    });
  });

  group('花朵统计', () {
    test('区分已开花与生长中', () {
      final garden = buildGarden(
        flowers: <Flower>[
          flower(
            id: 'old',
            speciesId: FlowerSpeciesId.sunflower,
            plantedAt: now.subtract(const Duration(days: 20)),
          ),
          flower(
            id: 'new',
            speciesId: FlowerSpeciesId.tulip,
            plantedAt: now,
          ),
        ],
      );

      expect(garden.bloomingAt(now), hasLength(1));
      expect(garden.growingAt(now), hasLength(1));
      expect(garden.totalPlants, 2);
      expect(garden.bloomingCountAt(now), 1);
    });

    test('按花种统计已开花数量', () {
      final garden = buildGarden(
        flowers: <Flower>[
          flower(
            id: 'a',
            speciesId: FlowerSpeciesId.sunflower,
            plantedAt: now.subtract(const Duration(days: 20)),
          ),
          flower(
            id: 'b',
            speciesId: FlowerSpeciesId.sunflower,
            plantedAt: now.subtract(const Duration(days: 20)),
          ),
          flower(
            id: 'c',
            speciesId: FlowerSpeciesId.tulip,
            plantedAt: now.subtract(const Duration(days: 20)),
          ),
        ],
      );

      expect(
        garden.bloomingCountOfSpecies(FlowerSpeciesId.sunflower, now),
        2,
      );
      expect(garden.bloomingCountOfSpecies(FlowerSpeciesId.tulip, now), 1);
      expect(
        garden.collectedSpeciesCountAt(now),
        2,
        reason: '两个花种都已开花，计入已收集',
      );
    });

    test('已收集只统计开过花的花种，种下未开花不算（PRD Tab3）', () {
      final garden = buildGarden(
        flowers: <Flower>[
          // 向日葵已开花
          flower(
            id: 'bloomed',
            speciesId: FlowerSpeciesId.sunflower,
            plantedAt: now.subtract(const Duration(days: 20)),
          ),
          // 郁金香刚种下，还是种子
          flower(
            id: 'just-planted',
            speciesId: FlowerSpeciesId.tulip,
            plantedAt: now,
          ),
        ],
      );

      expect(
        garden.collectedSpeciesCountAt(now),
        1,
        reason: '郁金香只种下未开花，图鉴里仍是剪影，不能计入已收集',
      );
      expect(
        garden.collectedSpeciesCountAt(
          now.add(const Duration(days: 20)),
        ),
        2,
        reason: '时间推移后郁金香开花，才计入已收集',
      );
    });

    test('生长阶段分布覆盖全部阶段', () {
      final garden = buildGarden(
        flowers: <Flower>[
          flower(
            id: 'seed',
            speciesId: FlowerSpeciesId.clover,
            plantedAt: now,
          ),
          flower(
            id: 'bloom',
            speciesId: FlowerSpeciesId.clover,
            plantedAt: now.subtract(const Duration(days: 20)),
          ),
        ],
      );

      final distribution = garden.stageDistributionAt(now);
      expect(distribution.keys, containsAll(GrowthStage.values));
      expect(distribution[GrowthStage.seed], 1);
      expect(distribution[GrowthStage.blooming], 1);
    });

    test('下一株即将开花的植物（首页期待感文案依据）', () {
      final garden = buildGarden(
        flowers: <Flower>[
          flower(
            id: 'later',
            speciesId: FlowerSpeciesId.clover,
            plantedAt: now.subtract(const Duration(days: 1)),
          ),
          flower(
            id: 'sooner',
            speciesId: FlowerSpeciesId.clover,
            plantedAt: now.subtract(const Duration(days: 6, hours: 12)),
          ),
        ],
      );

      final next = garden.nextBloomingAt(now);
      expect(next, isNotNull);
      expect(next!.flower.id, 'sooner');
      expect(next.days, lessThanOrEqualTo(1));
    });

    test('全部开花时没有「下一株」', () {
      final garden = buildGarden(
        flowers: <Flower>[
          flower(
            id: 'a',
            speciesId: FlowerSpeciesId.clover,
            plantedAt: now.subtract(const Duration(days: 30)),
          ),
        ],
      );

      expect(garden.nextBloomingAt(now), isNull);
    });
  });

  group('收集进度（PRD 7.1.2）', () {
    test('距下次开花的种子数计算正确', () {
      final garden = buildGarden(
        seeds: const <String, int>{FlowerSpeciesId.sunflower: 7},
      );

      expect(garden.petalsOfSpecies(FlowerSpeciesId.sunflower), 7);
      expect(
        garden.petalsUntilBloom,
        3,
        reason: 'PRD 示例：再种 3 颗会长出第一朵花',
      );
    });

    test('刚好整除时重新开始计数', () {
      final garden = buildGarden(
        seeds: const <String, int>{
          FlowerSpeciesId.sunflower: AppConstants.petalsPerBloom,
        },
      );

      expect(
        garden.petalsUntilBloom,
        AppConstants.petalsPerBloom,
      );
    });

    test('未种过的花种种子数为 0', () {
      expect(buildGarden().petalsOfSpecies(FlowerSpeciesId.wheat), 0);
      expect(
        buildGarden().petalsUntilBloom,
        AppConstants.petalsPerBloom,
      );
    });

    test('收集进度落在 0~1 之间', () {
      for (var count = 0; count <= 25; count++) {
        final garden = buildGarden(
          seeds: <String, int>{FlowerSpeciesId.sunflower: count},
        );
        expect(
          garden.speciesProgress(FlowerSpeciesId.sunflower),
          inInclusiveRange(0.0, 1.0),
        );
      }
    });
  });

  group('隐藏款解锁进度（PRD 7.1.3）', () {
    test('未达阈值', () {
      final garden = buildGarden(streak: 5);
      expect(garden.hiddenSpeciesUnlocked, isFalse);
      expect(
        garden.daysToHiddenSpecies,
        AppConstants.hiddenSpeciesStreakDays - 5,
      );
    });

    test('达到阈值即解锁', () {
      final garden = buildGarden(streak: AppConstants.hiddenSpeciesStreakDays);
      expect(garden.hiddenSpeciesUnlocked, isTrue);
      expect(garden.daysToHiddenSpecies, 0);
    });

    test('超过阈值仍保持解锁且天数不为负', () {
      final garden = buildGarden(streak: 100);
      expect(garden.hiddenSpeciesUnlocked, isTrue);
      expect(garden.daysToHiddenSpecies, 0);
    });
  });
}
