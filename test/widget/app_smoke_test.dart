import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mood_garden/app.dart';
import 'package:mood_garden/application/settings_controller.dart';
import 'package:mood_garden/application/mood_garden_controller.dart';
import 'package:mood_garden/data/datasources/encrypted_image_store.dart';
import 'package:mood_garden/data/datasources/local_store.dart';
import 'package:mood_garden/data/datasources/storage_bootstrap.dart';
import 'package:mood_garden/data/repositories/local_entry_repository.dart';
import 'package:mood_garden/data/repositories/local_settings_repository.dart';
import 'package:mood_garden/data/repositories/local_garden_repository.dart';
import 'package:mood_garden/domain/repositories/sound_player.dart';
import 'package:mood_garden/domain/entities/mood_tag.dart';
import 'package:mood_garden/features/codex/codex_page.dart';
import 'package:mood_garden/features/profile/profile_page.dart';

/// 应用级冒烟测试。
///
/// 覆盖目标：验证四个一级 Tab 的骨架能真实渲染、页面间导航能真实走通。
/// 深层业务逻辑已由 `test/unit/` 下的单元测试覆盖，此处不重复验证，
/// 因此**刻意不触发保存流程**——那会引入动画与 FakeAsync 时钟的耦合，
/// 让测试变得脆弱而收益有限。
void main() {
  /// 以手机尺寸渲染应用，避免测试默认 800x600 触发布局溢出。
  Future<MoodGardenController> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final store = InMemoryLocalStore();
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
        // 组件测试注入内存存储：不触碰真实文件系统与系统安全区。
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

  /// 在指定页面内滚动直到目标可见。
  ///
  /// 页面使用 `ListView` 懒加载，视口外的 widget 根本不会被构建，
  /// 因此断言视口外的内容前必须先滚动到它——否则会得到「找到 0 个」的
  /// 假失败，而不是真正的问题。
  Future<void> scrollToInPage(
    WidgetTester tester,
    Finder target,
    Type pageType,
  ) async {
    if (target.evaluate().isNotEmpty) {
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

  group('启动与信息架构（原型 v5）', () {
    testWidgets('启动后停在记录页，四个一级 Tab 为 记录 / 时光 / 花园 / 我的',
        (WidgetTester tester) async {
      await pumpApp(tester);

      // 记录页是进入 App 的第一屏（原型 screen-home）
      expect(find.text('今天，有什么\n想记下来的吗？'), findsOneWidget);

      // 四个 Tab 标签
      expect(find.text('记录'), findsWidgets);
      expect(find.text('时光'), findsWidgets);
      expect(find.text('花园'), findsWidgets);
      expect(find.text('我的'), findsWidgets);

      // 图鉴已并入花园，不再是独立 Tab
      expect(find.text('图鉴'), findsNothing);
    });

    testWidgets('记录页展示两个记录入口', (WidgetTester tester) async {
      await pumpApp(tester);

      expect(find.text('开心的事'), findsOneWidget);
      expect(find.text('难过的事'), findsOneWidget);
      expect(find.text('记下来，会开出一片花瓣'), findsOneWidget);
      expect(find.text('写下来，然后烧掉它'), findsOneWidget);
    });

    testWidgets('新用户看到空花园引导，而非空白页', (WidgetTester tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('花园').last);
      await tester.pumpAndSettle();

      expect(find.text('这里还是一片空地'), findsOneWidget);
    });

    testWidgets('花园页展示养分与收集进度（PRD 7.3 常驻展示）', (WidgetTester tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('花园').last);
      await tester.pumpAndSettle();

      expect(find.text('养分'), findsOneWidget);
      expect(find.text('已绽放'), findsOneWidget);
      expect(find.text('已释放'), findsOneWidget);
    });

    testWidgets('展示产品心智文案', (WidgetTester tester) async {
      await pumpApp(tester);

      expect(
        find.textContaining('开心的事被温柔地收藏'),
        findsOneWidget,
      );
    });
  });

  group('Tab 切换', () {
    testWidgets('切换到时光轴', (WidgetTester tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('时光').last);
      await tester.pumpAndSettle();

      expect(find.text('周'), findsOneWidget);
      expect(find.text('月'), findsOneWidget);
      expect(find.text('年'), findsOneWidget);
    });

    testWidgets('切换到花之图鉴并展示三个分区', (WidgetTester tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('花园').last);
      await tester.pumpAndSettle();

      expect(find.text('常见花种'), findsOneWidget);

      await scrollToInPage(tester, find.text('进化与隐藏款'), CodexPage);
      expect(find.text('进化与隐藏款'), findsOneWidget);

      await scrollToInPage(tester, find.text('季节限定'), CodexPage);
      // 「季节限定」既是分区标题、也是稀有度角标文案，会匹配到多个
      expect(find.text('季节限定'), findsWidgets);
    });

    testWidgets('图鉴展示 PRD 7.1.1 举例的花种', (WidgetTester tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('花园').last);
      await tester.pumpAndSettle();

      expect(find.text('向日葵'), findsOneWidget);
      expect(find.text('郁金香'), findsOneWidget);
      expect(find.text('薰衣草'), findsOneWidget);

      await scrollToInPage(tester, find.text('樱花'), CodexPage);
      expect(find.text('樱花'), findsOneWidget);
    });

    testWidgets('切换到我的并展示花园主题换肤（PRD Tab4）', (WidgetTester tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('我的').last);
      await tester.pumpAndSettle();

      await scrollToInPage(tester, find.text('花园主题'), ProfilePage);
      expect(find.text('花园主题'), findsOneWidget);
      expect(find.text('向日葵田'), findsOneWidget);
      expect(find.text('樱花谷'), findsOneWidget);
      expect(find.text('薰衣草坡'), findsOneWidget);
      expect(find.text('麦浪田'), findsOneWidget);
    });

    testWidgets('我的页面展示心情标签与花种的对应关系', (WidgetTester tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('我的').last);
      await tester.pumpAndSettle();

      await scrollToInPage(tester, find.text('我的心情标签'), ProfilePage);
      expect(find.text('我的心情标签'), findsOneWidget);

      for (final tag in MoodTag.presets) {
        await scrollToInPage(tester, find.text(tag.label), ProfilePage);
        expect(
          find.text(tag.label),
          findsWidgets,
          reason: '标签「${tag.label}」应当可见',
        );
      }
    });

    testWidgets('我的页面：设置项都是真功能，且不暴露内部标记', (WidgetTester tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('我的').last);
      await tester.pumpAndSettle();

      for (final label in <String>['字体大小', '每日提醒', '分享花园', '隐私与数据']) {
        await scrollToInPage(tester, find.text(label), ProfilePage);
        expect(find.text(label), findsOneWidget, reason: '$label 应当存在');
      }

      // 回归护栏：这些是给开发看的内部优先级标记，不该出现在产品界面上。
      // 曾经它们被拿来给「点了没反应」的占位入口做角标。
      for (final label in <String>['P1', 'P2', '待设计']) {
        expect(
          find.text(label),
          findsNothing,
          reason: '$label 不应出现在界面上',
        );
      }
    });
  });

  group('页面导航', () {
    testWidgets('从首页进入记录开心事页（PRD 7.1.1 五步流程）',
        (WidgetTester tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('开心的事'));
      await tester.pumpAndSettle();

      expect(find.text('这是什么心情？'), findsOneWidget);
      expect(find.text('什么时候的事？'), findsOneWidget);
      // 文案取自原型 v5 的「收进花园」（原为「种下这颗种子」）
      expect(find.text('收进花园'), findsOneWidget);
    });

    testWidgets('记录开心事页展示全部预设心情标签', (WidgetTester tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('开心的事'));
      await tester.pumpAndSettle();

      for (final tag in MoodTag.presets) {
        expect(find.text(tag.label), findsOneWidget);
      }
    });

    testWidgets('从首页进入情绪纸卷页（PRD 7.2.1）', (WidgetTester tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('难过的事'));
      await tester.pumpAndSettle();

      expect(find.text('写给自己的话'), findsOneWidget);
      // 空内容时点燃按钮为禁用态
      expect(find.text('写点什么才能点燃'), findsOneWidget);
    });

    testWidgets('纸卷页解释「烧掉就看不到」的机制（PRD 7.2.3）',
        (WidgetTester tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('难过的事'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('没有一种情绪是被浪费的'),
        findsOneWidget,
      );
    });

    testWidgets('纸卷页不提供「放弃 / 删除」入口（PRD 7.2.2 机制单一纯粹）',
        (WidgetTester tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('难过的事'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.text('删除'), findsNothing);
      expect(find.text('放弃'), findsNothing);
    });
  });
}
