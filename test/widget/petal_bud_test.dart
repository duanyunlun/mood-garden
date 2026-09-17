import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mood_garden/core/constants/app_constants.dart';
import 'package:mood_garden/features/petals/widgets/petal_bud.dart';

/// 花苞视觉的护栏（原型 v5 `.bud-flower`）。
///
/// 「花瓣拼合」是这个玩法唯一的可视化：进度条只说还差几片，
/// 花苞能说清已经拼到哪一步。因此点亮数量错一片都是可见的 bug。
void main() {
  Widget host(int lit) => MaterialApp(
        home: Scaffold(
          body: Center(child: PetalBud(lit: lit)),
        ),
      );

  /// 数出「点亮」的花瓣：AnimatedOpacity 的 opacity 为 1 表示已点亮。
  int litCount(WidgetTester tester) {
    return tester
        .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
        .where((w) => w.opacity == 1.0)
        .length;
  }

  group('花苞点亮数量', () {
    for (final lit in <int>[0, 1, 2, 3, 4]) {
      testWidgets('$lit 片花瓣时正好点亮 $lit 片', (WidgetTester tester) async {
        await tester.pumpWidget(host(lit));
        await tester.pumpAndSettle();

        expect(litCount(tester), lit);
      });
    }

    testWidgets('花瓣总数与 petalsPerBloom 一致', (WidgetTester tester) async {
      await tester.pumpWidget(host(0));
      await tester.pumpAndSettle();

      expect(
        find.byType(AnimatedOpacity),
        findsNWidgets(AppConstants.petalsPerBloom),
        reason: '一个花苞由 ${AppConstants.petalsPerBloom} 片花瓣拼成',
      );
    });

    testWidgets('超过上限时不会画出多余的花瓣', (WidgetTester tester) async {
      // 攒满即绽放并归零，理论上不会出现 lit == total，
      // 但真出现了也不该画出第六片花瓣。
      await tester.pumpWidget(host(99));
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedOpacity), findsNWidgets(AppConstants.petalsPerBloom));
      expect(litCount(tester), AppConstants.petalsPerBloom);
    });
  });

  group('无障碍', () {
    testWidgets('朗读出拼合进度，而不是只画个图', (WidgetTester tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(3));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('花苞拼合 3 / ${AppConstants.petalsPerBloom}'),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}
