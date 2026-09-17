import 'package:flutter/material.dart';

import 'app.dart';
import 'application/mood_garden_controller.dart';
import 'application/settings_controller.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/asset_sound_player.dart';
import 'data/datasources/storage_bootstrap.dart';
import 'data/repositories/local_entry_repository.dart';
import 'data/repositories/local_garden_repository.dart';
import 'data/repositories/local_settings_repository.dart';

/// 应用入口。
///
/// 依赖装配采用「手工构造注入」而非引入 DI 框架：依赖数量少时手工装配更直观、
/// 零额外依赖，也便于测试时替换实现。
///
/// ## 为什么先 `runApp` 一个过渡页，而不是等装配完再 `runApp`
///
/// 存储装配要异步向系统安全区（Keychain / Keystore）取主密钥。绝大多数情况下
/// 这只要几十毫秒，但**它可能被阻塞**：macOS 上如果 App 的签名变了，
/// 访问钥匙串会弹出系统授权框等待用户输入——此时界面还没渲染，
/// 用户看到的就是一片纯黑窗口，完全不知道发生了什么。
///
/// 这个问题是在桌面实测中真实撞到的。因此这里先渲染一帧与主题一致的过渡页，
/// 装配完成后再替换根组件：快路径下它只闪一下，慢路径下用户至少有东西可看。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const _BootingApp());

  // PRD 第 10 章：情绪记录属敏感数据，必须加密后落盘，且密钥由系统安全区托管。
  // 装配失败时本调用会降级为内存存储，并把原因带到 UI，而不是让 App 打不开。
  final bootstrap = await bootstrapLocalStore();

  final controller = MoodGardenController(
    entryRepository: LocalEntryRepository(bootstrap.store),
    gardenRepository: LocalGardenRepository(bootstrap.store),
    imageStore: bootstrap.images,
  );

  // 仪式音效。素材是合成的占位音，见 tool/generate_audio_assets.py。
  final soundPlayer = AssetSoundPlayer();

  final settings = SettingsController(
    repository: LocalSettingsRepository(bootstrap.store),
  );

  runApp(
    MoodGardenApp(
      controller: controller,
      settings: settings,
      storage: bootstrap,
      soundPlayer: soundPlayer,
    ),
  );
}

/// 启动过渡页。
///
/// 刻意保持静态而非转圈：装配通常是瞬时的，一个转圈图标反而像是闪了一下。
class _BootingApp extends StatelessWidget {
  const _BootingApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) {
          final textTheme = Theme.of(context).textTheme;
          return Scaffold(
            backgroundColor: AppColors.creamWhite,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('🌻', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 16),
                  Text(AppConstants.appName, style: textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(AppConstants.slogan, style: textTheme.labelSmall),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
