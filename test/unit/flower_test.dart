import 'package:flutter_test/flutter_test.dart';
import 'package:mood_garden/core/constants/app_constants.dart';
import 'package:mood_garden/domain/entities/flower.dart';
import 'package:mood_garden/domain/entities/flower_species.dart';
import 'package:mood_garden/domain/entities/growth_stage.dart';

/// 花朵生长推导测试。
///
/// 核心验证点（PRD 7.1.2）：
/// > 花园中的花并非静态统计数字，而是随真实时间流逝自然生长的活地图。
///
/// 即：生长阶段必须由「种植时间 → 当前时间」的时间差推导，
/// 而不是由任何用户操作或存储字段决定。
void main() {
  final plantedAt = DateTime(2026, 3, 1, 9);

  Flower flowerAt({int nutrientBoost = 0}) => Flower(
        id: 'f1',
        speciesId: FlowerSpeciesId.sunflower,
        plantedAt: plantedAt,
        nutrientBoost: nutrientBoost,
      );

  group('生长阶段随时间自然推进（PRD 7.1.2）', () {
    test('刚种下是种子', () {
      final flower = flowerAt();
      final stage = flower.stageAt(plantedAt.add(const Duration(hours: 2)));
      expect(stage, GrowthStage.seed);
    });

    test('满 1 天发芽', () {
      final flower = flowerAt();
      final stage = flower.stageAt(plantedAt.add(const Duration(days: 1, hours: 1)));
      expect(stage, GrowthStage.sprout);
    });

    test('满 3 天抽叶', () {
      final flower = flowerAt();
      final stage = flower.stageAt(plantedAt.add(const Duration(days: 3, hours: 1)));
      expect(stage, GrowthStage.leafing);
    });

    test('满 7 天开花', () {
      final flower = flowerAt();
      final stage = flower.stageAt(plantedAt.add(const Duration(days: 7, hours: 1)));
      expect(stage, GrowthStage.blooming);
    });

    test('同一朵花在不同时刻查询得到不同阶段——无需任何写操作', () {
      final flower = flowerAt();
      final day1 = flower.stageAt(plantedAt.add(const Duration(days: 1, hours: 1)));
      final day8 = flower.stageAt(plantedAt.add(const Duration(days: 8)));

      expect(day1, isNot(day8));
      expect(flower.currentStage, isNotNull);
    });
  });

  group('养分加速生长（PRD 7.3：养分越高生长周期越短）', () {
    test('高养分的花比零养分的更早开花', () {
      final poor = flowerAt();
      final rich = flowerAt(nutrientBoost: AppConstants.nutrientLevelCap);
      final checkAt = plantedAt.add(const Duration(days: 5));

      expect(
        rich.stageAt(checkAt).progressIndex,
        greaterThan(poor.stageAt(checkAt).progressIndex),
        reason: '满养分时 5 天应当已经比零养分时长得更靠后',
      );
    });

    test('满养分时开花所需天数缩短到基准的一半', () {
      final rich = flowerAt(nutrientBoost: AppConstants.nutrientLevelCap);
      // 基准 7 天，满养分（加速 2 倍）应在 3.5 天后开花
      expect(
        rich.stageAt(plantedAt.add(const Duration(days: 4))),
        GrowthStage.blooming,
      );
      expect(
        rich.stageAt(plantedAt.add(const Duration(days: 3))),
        isNot(GrowthStage.blooming),
      );
    });

    test('负数养分不会导致异常', () {
      final negative = flowerAt(nutrientBoost: -500);
      expect(
        negative.stageAt(plantedAt.add(const Duration(days: 8))),
        GrowthStage.blooming,
      );
    });
  });

  group('开花倒计时与进度', () {
    test('剩余天数随时间递减', () {
      final flower = flowerAt();
      final early = flower.daysUntilBlooming(plantedAt);
      final later = flower.daysUntilBlooming(plantedAt.add(const Duration(days: 3)));

      expect(later, lessThan(early));
    });

    test('已开花时剩余天数为 0', () {
      final flower = flowerAt();
      expect(flower.daysUntilBlooming(plantedAt.add(const Duration(days: 30))), 0);
    });

    test('生长进度落在 0~1 区间内', () {
      final flower = flowerAt();
      for (var hours = 0; hours <= 24 * 10; hours += 12) {
        final progress = flower.growthProgressAt(
          plantedAt.add(Duration(hours: hours)),
        );
        expect(progress, inInclusiveRange(0.0, 1.0));
      }
    });

    test('开花后进度为 1.0', () {
      final flower = flowerAt();
      expect(
        flower.growthProgressAt(plantedAt.add(const Duration(days: 20))),
        1.0,
      );
    });
  });

  group('渲染种子稳定性（避免花园重绘时跳动）', () {
    test('同一朵花的抖动值可复现', () {
      final a = flowerAt();
      final b = flowerAt();

      expect(a.renderSeed, b.renderSeed);
      expect(a.jitter(1), b.jitter(1));
    });

    test('抖动值落在指定区间内', () {
      final flower = flowerAt();
      final value = flower.jitter(7, min: -0.1, max: 0.1);
      expect(value, inInclusiveRange(-0.1, 0.1));
    });
  });

  group('花种目录', () {
    test('PRD 7.1.1 举例的六个标签都有对应花种', () {
      for (final id in <String>[
        FlowerSpeciesId.sunflower,
        FlowerSpeciesId.tulip,
        FlowerSpeciesId.lavender,
        FlowerSpeciesId.wheat,
        FlowerSpeciesId.sakura,
        FlowerSpeciesId.clover,
      ]) {
        expect(FlowerSpecies.byId(id), isNotNull, reason: '$id 应在花种目录中');
      }
    });

    test('樱花是季节限定，仅 3-4 月可种（PRD 7.1.3）', () {
      expect(FlowerSpecies.sakura.isSeasonal, isTrue);
      expect(FlowerSpecies.sakura.isPlantableInMonth(3), isTrue);
      expect(FlowerSpecies.sakura.isPlantableInMonth(4), isTrue);
      expect(FlowerSpecies.sakura.isPlantableInMonth(7), isFalse);
    });

    test('非季节限定花全年可种', () {
      expect(FlowerSpecies.sunflower.isSeasonal, isFalse);
      for (var month = 1; month <= 12; month++) {
        expect(FlowerSpecies.sunflower.isPlantableInMonth(month), isTrue);
      }
    });

    test('进化花种记录了来源花种', () {
      expect(FlowerSpecies.goldenSunflower.isEvolved, isTrue);
      expect(
        FlowerSpecies.goldenSunflower.evolvedFromId,
        FlowerSpeciesId.sunflower,
      );
    });

    test('不存在的花种 id 返回 null 而不是抛异常', () {
      expect(FlowerSpecies.byId('not_exist'), isNull);
    });
  });
}
