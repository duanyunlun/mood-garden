import 'package:flutter/material.dart';

import 'app.dart';
import 'application/mood_garden_controller.dart';
import 'data/datasources/local_store.dart';
import 'data/repositories/local_entry_repository.dart';
import 'data/repositories/local_garden_repository.dart';

/// 应用入口。
///
/// 依赖装配采用「手工构造注入」而非引入 DI 框架：骨架期依赖数量少，
/// 手工装配更直观、零额外依赖，也便于测试时替换实现。
/// 待依赖规模增长后再评估是否引入 `get_it` 等方案。
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ⚠️ 骨架期使用内存存储，数据不落盘、不加密。
  // 正式实现需替换为加密持久化方案（PRD 第 10 章「数据安全与隐私」）。
  final LocalStore store = InMemoryLocalStore();

  final controller = MoodGardenController(
    entryRepository: LocalEntryRepository(store),
    gardenRepository: LocalGardenRepository(store),
  );

  runApp(MoodGardenApp(controller: controller));
}
