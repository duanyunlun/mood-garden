import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mood_garden/app.dart';
import 'package:mood_garden/application/settings_controller.dart';
import 'package:mood_garden/application/mood_garden_controller.dart';
import 'package:mood_garden/data/datasources/encrypted_image_store.dart';
import 'package:mood_garden/data/datasources/local_store.dart';
import 'package:mood_garden/data/datasources/storage_bootstrap.dart';
import 'package:mood_garden/data/models/garden_state_codec.dart';
import 'package:mood_garden/data/repositories/local_entry_repository.dart';
import 'package:mood_garden/data/repositories/local_settings_repository.dart';
import 'package:mood_garden/data/repositories/local_garden_repository.dart';
import 'package:mood_garden/domain/repositories/sound_player.dart';
import 'package:mood_garden/core/constants/app_constants.dart';
import 'package:mood_garden/domain/entities/flower.dart';
import 'package:mood_garden/domain/entities/flower_species.dart';
import 'package:mood_garden/domain/entities/garden_state.dart';
import 'package:mood_garden/features/codex/widgets/codex_sections.dart';

/// 图鉴收集度口径测试（PRD Tab3）。
///
/// 这一条守的是一个真实出现过的自相矛盾：页面顶部的「已收集 N 种花」
/// 曾按「种下过」计数，而卡片的灰显剪影按「开过花」判定，
/// 于是会出现「顶部说收集了 3 种、页面上却有 2 张剪影」。
///
/// 现在两者统一为**开花才算收集**，本测试把这个不变量钉住。
void main() {
  Future<void> pumpCodex(WidgetTester tester, GardenState garden) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final store = InMemoryLocalStore();
    await store.write(
      StoreKeys.gardenState,
      GardenStateCodec.encode(garden),
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

    await tester.tap(find.text('花园').last);
    await tester.pumpAndSettle();

    // 图鉴已并入花园页（原型 v5），位于该页下半部分。
    // ListView 懒加载，不滚过去就不会被构建。
    await tester.scrollUntilVisible(
      find.byType(CodexSections),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('顶部「已收集」数量与卡片剪影判定一致（只算开过花的花种）', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();

    await pumpCodex(
      tester,
      GardenState(
        flowers: <Flower>[
          // 向日葵已开花
          Flower(
            id: 'bloomed',
            speciesId: FlowerSpeciesId.sunflower,
            plantedAt: now.subtract(const Duration(days: 20)),
          ),
          // 郁金香与幸运草只种下、尚未开花
          Flower(
            id: 'seed-tulip',
            speciesId: FlowerSpeciesId.tulip,
            plantedAt: now,
          ),
          Flower(
            id: 'seed-clover',
            speciesId: FlowerSpeciesId.clover,
            plantedAt: now,
          ),
        ],
        petalStockBySpecies: <String, int>{
          FlowerSpeciesId.sunflower: 12,
          FlowerSpeciesId.tulip: 1,
          FlowerSpeciesId.clover: 1,
        },
      ),
    );

    // 图鉴已并入花园页（原型 v5），内容组件仍是 CodexSections
    expect(find.byType(CodexSections), findsOneWidget);

    // 只有向日葵开过花 → 顶部只能算 1 种
    expect(
      find.text('已收集 1 / ${FlowerSpecies.catalog.length} 种花'),
      findsOneWidget,
      reason: '种下但未开花的花种仍是剪影，不能计入已收集',
    );

    // 卡片侧：显示「已开 N 朵」的卡片数必须与顶部计数一致
    final collectedCards = find.textContaining('已开 ');
    expect(
      collectedCards,
      findsOneWidget,
      reason: '「已开 N 朵」的卡片数量必须等于顶部已收集数量',
    );

    // 未开花的花种显示收集进度，而不是「已开」
    expect(find.text('已攒 1 / ${AppConstants.petalsPerBloom} 片花瓣'), findsWidgets);
  });

  testWidgets('时间推移到开花之后，已收集数量随之增加', (WidgetTester tester) async {
    // 种下 20 天：三个花种都该开花
    final now = DateTime.now();

    await pumpCodex(
      tester,
      GardenState(
        flowers: <Flower>[
          for (final speciesId in <String>[
            FlowerSpeciesId.sunflower,
            FlowerSpeciesId.tulip,
            FlowerSpeciesId.clover,
          ])
            Flower(
              id: 'f-$speciesId',
              speciesId: speciesId,
              plantedAt: now.subtract(const Duration(days: 20)),
            ),
        ],
      ),
    );

    expect(
      find.text('已收集 3 / ${FlowerSpecies.catalog.length} 种花'),
      findsOneWidget,
    );
  });
}
