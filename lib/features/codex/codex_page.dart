import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/mood_garden_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/codex_sections.dart';

/// 花之图鉴（PRD 第 6 章信息架构 / 7.1.3 进阶收集玩法）。
///
/// 原型 v5 把图鉴从一级 Tab 撤下，并入「我的花瓣」页，因此这个页面
/// 不再是 Tab 之一。它保留为独立入口的理由：花瓣页与图鉴页共用
/// [CodexSections]，但两者语境不同——花瓣页要先讲收集进度，
/// 图鉴页则直接铺花种。
///
/// PRD 明确的四个分区由 [CodexSections] 承担：
/// - 已收集花种展示（含进化等级）
/// - 未收集花种展示（灰显 / 剪影）
/// - 隐藏款花种专区（连续记录天数解锁）
/// - 季节限定花专区（如樱花仅 3-4 月可种）
class CodexPage extends StatelessWidget {
  const CodexPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      body: SafeArea(
        bottom: false,
        child: Consumer<MoodGardenController>(
          builder: (context, controller, _) {
            if (controller.isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.warmApricot,
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                10,
                AppTheme.pagePadding,
                28,
              ),
              children: <Widget>[
                Text(
                  '花之图鉴',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                // 收集度与四个分区都在这里，页面本身不再重复渲染。
                const CodexSections(),
              ],
            );
          },
        ),
      ),
    );
  }
}
