import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mood_garden/domain/entities/flower.dart';
import 'package:mood_garden/domain/entities/flower_species.dart';
import 'package:mood_garden/features/garden/widgets/garden_canvas.dart';

/// 花园渲染的性能与稳定性护栏（PRD 第 10 章「性能」）。
///
/// 这一组测试守的不是「快」，而是**不会悄悄退化**：
/// 花园是首页最重的一屏，且每次记录都会让植物变多。
/// 一旦有人把逐帧分配或「渲染全部植物」写回来，这里会红。
void main() {
  Flower flower(int index, {DateTime? plantedAt}) => Flower(
        id: 'flower_$index',
        speciesId: FlowerSpeciesId.sunflower,
        plantedAt: plantedAt ?? DateTime(2026, 3, 1),
      );

  List<Flower> manyFlowers(int count) =>
      List<Flower>.generate(count, (i) => flower(i), growable: false);

  Widget host(List<Flower> flowers) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 260,
            child: GardenCanvas(flowers: flowers),
          ),
        ),
      );

  group('layout jitter 是确定且无分配的', () {
    test('同一株花永远得到同一个抖动值', () {
      final subject = flower(1);

      // 用整数散列而不是 math.Random 之后，这一点必须仍然成立——
      // 否则每次重建花园都会「跳一下」（PRD 11.3 的柔和观感）。
      for (var i = 0; i < 5; i++) {
        expect(subject.jitter(1, min: 0, max: 6), subject.jitter(1, min: 0, max: 6));
        expect(subject.jitter(2, min: -0.09, max: 0.09),
            subject.jitter(2, min: -0.09, max: 0.09));
      }
    });

    test('不同 salt 得到不同值，不同花也得到不同值', () {
      final a = flower(1);
      final b = flower(2);

      expect(a.jitter(1), isNot(equals(a.jitter(2))));
      expect(a.jitter(1), isNot(equals(b.jitter(1))));
    });

    test('落在给定区间内', () {
      for (var i = 0; i < 60; i++) {
        final value = flower(i).jitter(3, min: -0.5, max: 2.5);
        expect(value, greaterThanOrEqualTo(-0.5));
        expect(value, lessThanOrEqualTo(2.5));
      }
    });
  });

  group('大量植物时的渲染', () {
    testWidgets('渲染数量有上限，且不丢失总数信息', (WidgetTester tester) async {
      const total = 300;
      await tester.pumpWidget(host(manyFlowers(total)));
      await tester.pumpAndSettle();

      // 画布里的植物 sprite 数量必须被截断
      final sprites = find.byTooltip('向日葵 · 种子');
      expect(
        sprites.evaluate().length,
        lessThanOrEqualTo(GardenCanvas.maxRenderedPlants),
        reason: '不设上限时，几百个 Text 会让首页每次 setState 都很重',
      );

      // 但用户仍能知道还有更多
      expect(
        find.textContaining('还有 ${total - GardenCanvas.maxRenderedPlants} 株'),
        findsOneWidget,
        reason: '截断显示不该让信息消失',
      );
    });

    testWidgets('不超过上限时不显示「还有 N 株」', (WidgetTester tester) async {
      await tester.pumpWidget(host(manyFlowers(10)));
      await tester.pumpAndSettle();

      expect(find.textContaining('还有'), findsNothing);
    });

    testWidgets('三百株的首次构建在合理预算内完成', (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();
      await tester.pumpWidget(host(manyFlowers(300)));
      await tester.pumpAndSettle();
      stopwatch.stop();

      // 这是一条**防退化**断言，不是性能指标：预算给得很宽，
      // 只有真的退化成 O(n²) 或逐帧分配才会被触发。
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(4000),
        reason: '三百株植物构建耗时 ${stopwatch.elapsedMilliseconds}ms，'
            '明显超出合理范围，检查是否渲染了全部植物或引入了逐帧分配',
      );
    });
  });

  group('空花园', () {
    testWidgets('没有植物时展示引导而不是空白', (WidgetTester tester) async {
      await tester.pumpWidget(host(const <Flower>[]));
      await tester.pumpAndSettle();

      expect(find.text('这里还是一片空地'), findsOneWidget);
    });
  });
}
