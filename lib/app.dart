import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'application/mood_garden_controller.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/main_shell.dart';

/// 应用根组件。
class MoodGardenApp extends StatefulWidget {
  const MoodGardenApp({required this.controller, super.key});

  final MoodGardenController controller;

  @override
  State<MoodGardenApp> createState() => _MoodGardenAppState();
}

class _MoodGardenAppState extends State<MoodGardenApp> {
  @override
  void initState() {
    super.initState();
    // 启动即加载本地数据。加载态由 controller.isLoading 驱动，
    // 各页面自行决定是展示骨架屏还是内容。
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MoodGardenController>.value(
      value: widget.controller,
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
        home: const MainShell(),
      ),
    );
  }
}
