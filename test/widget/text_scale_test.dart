import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mood_garden/app.dart';
import 'package:mood_garden/application/settings_controller.dart';
import 'package:mood_garden/application/mood_garden_controller.dart';
import 'package:mood_garden/data/datasources/encrypted_image_store.dart';
import 'package:mood_garden/data/datasources/local_store.dart';
import 'package:mood_garden/data/datasources/storage_bootstrap.dart';
import 'package:mood_garden/data/models/garden_state_codec.dart';
import 'package:mood_garden/data/models/mood_entry_codec.dart';
import 'package:mood_garden/data/repositories/local_entry_repository.dart';
import 'package:mood_garden/data/repositories/local_settings_repository.dart';
import 'package:mood_garden/data/repositories/local_garden_repository.dart';
import 'package:mood_garden/domain/repositories/sound_player.dart';
import 'package:mood_garden/domain/entities/flower.dart';
import 'package:mood_garden/domain/entities/flower_species.dart';
import 'package:mood_garden/domain/entities/garden_state.dart';
import 'package:mood_garden/domain/entities/mood_entry.dart';
import 'package:mood_garden/domain/entities/mood_tag.dart';
import 'package:mood_garden/features/record_happy/record_happy_page.dart';
import 'package:mood_garden/features/record_unhappy/record_unhappy_page.dart';
import 'package:mood_garden/features/record_home/record_home_page.dart';
import 'package:mood_garden/features/timeline/date_detail_page.dart';

/// 无障碍回归测试（PRD 第 10 章）。
///
/// > 无障碍：支持文字大小可调节，色彩对比度设计需照顾色弱/色盲用户。
///
/// 「支持文字大小可调节」不是一句可以口头承诺的事：只要有一处用了固定高度
/// 或固定宽高比（`GridView.childAspectRatio` 是典型），放大字体就会
/// `RenderFlex overflow`。这组测试把系统字体放大后逐页渲染，把溢出变成红灯。
///
/// 之所以要用带数据的种子状态而不是空花园：空态只有一行提示文案，
/// 根本压不到列表、卡片、网格的真实布局。
void main() {
  /// 用户可在系统设置里调到的大字体档位。
  const largeTextScale = 2.0;

  Future<MoodGardenController> pumpSeededApp(
    WidgetTester tester, {
    double textScale = largeTextScale,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final now = DateTime.now();
    final store = InMemoryLocalStore();

    await store.write(
      StoreKeys.entries,
      MoodEntryCodec.encodeList(<MoodEntry>[
        HappyEntry(
          id: 'h1',
          occurredAt: now,
          createdAt: now,
          tagId: MoodTagId.gratitude,
          text: '今天在楼下遇见一只很亲人的橘猫，它跟着我走了半条街，'
              '最后在便利店门口坐下来认真看着我。',
        ),
        HappyEntry(
          id: 'h2',
          occurredAt: now.subtract(const Duration(days: 2)),
          createdAt: now,
          tagId: MoodTagId.achievement,
          text: '拖了很久的方案终于写完了。',
        ),
        UnhappyEntry(
          id: 'u1',
          occurredAt: now,
          createdAt: now,
          text: '这段内容在燃烧后必须被物理擦除。',
          burnedAt: now,
        ),
        UnhappyEntry(
          id: 'u2',
          occurredAt: now,
          createdAt: now,
          text: '一张还没点燃的纸卷。',
        ),
      ]),
    );

    await store.write(
      StoreKeys.gardenState,
      GardenStateCodec.encode(
        GardenState(
          nutrientValue: 120,
          streakDays: 3,
          flowers: <Flower>[
            Flower(
              id: 'f1',
              speciesId: FlowerSpeciesId.sunflower,
              plantedAt: now.subtract(const Duration(days: 20)),
            ),
            Flower(
              id: 'f2',
              speciesId: FlowerSpeciesId.tulip,
              plantedAt: now.subtract(const Duration(days: 3)),
            ),
            Flower(
              id: 'f3',
              speciesId: FlowerSpeciesId.clover,
              plantedAt: now,
            ),
          ],
          petalStockBySpecies: <String, int>{
            FlowerSpeciesId.sunflower: 12,
            FlowerSpeciesId.tulip: 3,
          },
          lastRecordedDay: now,
        ),
      ),
    );

    final images = InMemoryEntryImageStore();
    final controller = MoodGardenController(
      entryRepository: LocalEntryRepository(store),
      gardenRepository: LocalGardenRepository(store),
      imageStore: images,
    );

    await tester.pumpWidget(
      MoodGardenApp(
        controller: controller,
        // 测试里不放音：NoopSoundPlayer 不触碰任何音频设备。
        soundPlayer: const NoopSoundPlayer(),
        settings: SettingsController(
          repository: LocalSettingsRepository(store),
        ),
        storage: StorageBootstrap(
          store: store,
          images: images,
          kind: StorageKind.memory,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return controller;
  }

  /// 断言当前这一帧没有布局异常（溢出会经由 FlutterError 被测试框架捕获）。
  void expectNoLayoutError(WidgetTester tester, String where) {
    expect(tester.takeException(), isNull, reason: '$where 在放大字体下发生了布局溢出');
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  /// 滚动到目标可见后再操作。
  ///
  /// 放大字体后原本在首屏的按钮会被推到视口外，而页面用的是 `ListView`
  /// 懒加载——视口外的 widget 根本不会被构建，直接 `tap` 会得到
  /// 「Found 0 widgets」的假失败。
  Future<void> scrollTo(
    WidgetTester tester,
    Finder target, {
    required Type pageType,
  }) async {
    if (target.evaluate().isNotEmpty) {
      // 找到了不等于点得到：放大字体后目标可能正好被底部导航栏压住，
      // tap 的命中点会落到导航栏上。ensureVisible 把它滚进完全可见的区域。
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      return;
    }
    await tester.scrollUntilVisible(
      target,
      240,
      scrollable: find
          .descendant(
            of: find.byType(pageType),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  group('文字放大 ${largeTextScale}x 下不溢出（PRD 第 10 章无障碍）', () {
    testWidgets('记录首页（Tab1）', (WidgetTester tester) async {
      await pumpSeededApp(tester);
      expectNoLayoutError(tester, '记录首页');
    });

    testWidgets('时光轴周视图与月视图', (WidgetTester tester) async {
      await pumpSeededApp(tester);
      await openTab(tester, '时光');
      expectNoLayoutError(tester, '时光轴默认（月）视图');

      await tester.tap(find.text('周'));
      await tester.pumpAndSettle();
      expectNoLayoutError(tester, '时光轴周视图');
    });

    testWidgets('时光轴年视图（本页曾用 GridView 固定宽高比）', (
      WidgetTester tester,
    ) async {
      await pumpSeededApp(tester);
      await openTab(tester, '时光');

      await tester.tap(find.text('年'));
      await tester.pumpAndSettle();

      expectNoLayoutError(tester, '时光轴年视图');
      // 12 个月份卡片必须都在，且是真实渲染出来的
      for (var month = 1; month <= 12; month++) {
        expect(find.text('$month月'), findsOneWidget);
      }
    });

    testWidgets('花之图鉴', (WidgetTester tester) async {
      await pumpSeededApp(tester);
      await openTab(tester, '花园');
      expectNoLayoutError(tester, '花之图鉴');
    });

    testWidgets('我的', (WidgetTester tester) async {
      await pumpSeededApp(tester);
      await openTab(tester, '我的');
      expectNoLayoutError(tester, '我的');
    });

    testWidgets('记录开心事页', (WidgetTester tester) async {
      await pumpSeededApp(tester);

      final entry = find.text('开心的事');
      await scrollTo(tester, entry, pageType: RecordHomePage);
      await tester.tap(entry);
      await tester.pumpAndSettle();

      // 断言页面类型而不是某段文字：放大字体后页面内容变长，
      // 首屏之外的 widget 不会被懒加载的 ListView 构建，
      // 按文字断言会得到「Found 0」这种与真实问题无关的假失败。
      expect(find.byType(RecordHappyPage), findsOneWidget, reason: '应已进入记录页');
      expectNoLayoutError(tester, '记录开心事页');
    });

    testWidgets('情绪纸卷页', (WidgetTester tester) async {
      await pumpSeededApp(tester);

      final entry = find.text('难过的事');
      await scrollTo(tester, entry, pageType: RecordHomePage);
      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(find.byType(RecordUnhappyPage), findsOneWidget, reason: '应已进入纸卷页');
      expectNoLayoutError(tester, '情绪纸卷页');
    });

    testWidgets('日期详情页（含灰烬封条）', (WidgetTester tester) async {
      await pumpSeededApp(tester);
      await openTab(tester, '时光');

      // 月视图里点「今天」那一格进入日期详情
      final today = DateTime.now().day;
      await tester.tap(find.text('$today').first);
      await tester.pumpAndSettle();

      expect(
        find.byType(DateDetailPage),
        findsOneWidget,
        reason: '应已进入日期详情页',
      );
      expectNoLayoutError(tester, '日期详情页');

      // 灰烬封条在页面下方，大字体下需先滚动到它
      final seal = find.text('已转化为养分');
      await scrollTo(tester, seal, pageType: DateDetailPage);
      expect(seal, findsWidgets);
    });
  });
}
