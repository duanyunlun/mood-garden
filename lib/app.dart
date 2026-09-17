import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'application/mood_garden_controller.dart';
import 'application/settings_controller.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/storage_bootstrap.dart';
import 'domain/repositories/sound_player.dart';
import 'features/shell/main_shell.dart';

/// 应用根组件。
class MoodGardenApp extends StatefulWidget {
  const MoodGardenApp({
    required this.controller,
    required this.settings,
    required this.storage,
    required this.soundPlayer,
    super.key,
  });

  final MoodGardenController controller;

  /// 设置控制器（字体大小、自定义标签、每日提醒）。
  final SettingsController settings;

  /// 存储装配结果。提供给「我的 → 隐私与数据」展示真实的落盘与加密状态，
  /// 让降级为内存存储这件事对用户可见，而不是静默丢数据。
  final StorageBootstrap storage;

  /// 仪式音效播放器（PRD 7.2.2）。
  final SoundPlayer soundPlayer;

  @override
  State<MoodGardenApp> createState() => _MoodGardenAppState();
}

class _MoodGardenAppState extends State<MoodGardenApp> {
  @override
  void initState() {
    super.initState();
    // 启动即加载本地数据。加载态由各控制器的 isLoading 驱动，
    // 各页面自行决定是展示骨架屏还是内容。
    widget.controller.load();
    widget.settings.load();
  }

  /// 把「应用内字体缩放」叠加到系统缩放之上。
  ///
  /// 两者的关系是**相乘**而不是覆盖：系统级放大（PRD 第 10 章要求的
  /// 「文字大小可调节」）必须继续生效，应用内档位只是在此之上再给一层微调，
  /// 让「系统调到最大还是觉得小」的用户有地方可去。
  ///
  /// 最终值夹在 [AppConstants.textScaleMin, AppConstants.textScaleCeiling] 内。
  /// 注意上界用的是 ceiling 而不是 max——后者是用户可调的倍率上限，
  /// 拿它去夹最终值会把系统已放大的字号反向压低。
  Widget _applyTextScale(BuildContext context, Widget? child) {
    final settings = context.watch<SettingsController>();
    final media = MediaQuery.of(context);

    // `scale(1)` 等价于取出当前缩放的线性因子。
    final systemScale = media.textScaler.scale(1);
    final effective = (systemScale * settings.textScale).clamp(
      AppConstants.textScaleMin,
      AppConstants.textScaleCeiling,
    );

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(effective)),
      child: child ?? const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // 元素类型 SingleChildWidget 由 provider 内部（nested）定义且未导出，
      // 因此这里交给类型推断，不显式标注。
      providers: [
        ChangeNotifierProvider<MoodGardenController>.value(
          value: widget.controller,
        ),
        ChangeNotifierProvider<SettingsController>.value(
          value: widget.settings,
        ),
        Provider<StorageBootstrap>.value(value: widget.storage),
        Provider<SoundPlayer>.value(value: widget.soundPlayer),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('zh', 'CN'),
        supportedLocales: const <Locale>[
          Locale('zh', 'CN'),
          Locale('en'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: _applyTextScale,
        home: const MainShell(),
      ),
    );
  }
}
