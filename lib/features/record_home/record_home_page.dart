import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/mood_garden_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/growth_stage.dart';
import '../../domain/entities/mood_entry.dart';
import '../shell/shell_tab_controller.dart';

/// Tab1 记录首页（原型 v5 · `screen-home`）。
///
/// 这是进入 App 的第一屏，刻意做得极简：
/// 一句话、两个选择、一行今日进度。没有花园画布、没有统计卡片、没有养分条——
/// 那些都在「花园」Tab 里，不该在第一屏抢注意力。
///
/// 原型的取舍值得记下来：**先问心情，再谈养成**。用户打开 App 是为了把一件事
/// 记下来，不是为了看数据；把记录入口做成一级 Tab 而不是花园页上的一张卡片，
/// 是把这件事在信息架构上也说清楚。
class RecordHomePage extends StatelessWidget {
  const RecordHomePage({super.key});

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
                child: CircularProgressIndicator(color: AppColors.warmApricot),
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(30, 16, 30, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _TopBar(controller: controller),
                  // 中部可滚动：字体放大到 2× 时，标题加两个按钮会超出可视高度。
                  // 用 SingleChildScrollView + minHeight 约束，既保持「居中」的
                  // 视觉意图，又不会在放大字体时抛 RenderFlex overflow。
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: _CenterBlock(controller: controller),
                        ),
                      ),
                    ),
                  ),
                  _FootHint(controller: controller),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 顶部：日期 + 进「我的」的入口。
class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final MoodGardenController controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            DateFormatter.homeHeadline(now),
            style: textTheme.labelMedium,
          ),
        ),
        Semantics(
          button: true,
          label: '我的',
          child: InkWell(
            onTap: () => context.read<ShellTabController>().goToProfile(),
            borderRadius: BorderRadius.circular(AppTheme.pillRadius),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.creamSoft,
                shape: BoxShape.circle,
              ),
              child: const Text('🌿', style: TextStyle(fontSize: 17)),
            ),
          ),
        ),
      ],
    );
  }
}

/// 中部：一句提问 + 两个选择。
class _CenterBlock extends StatelessWidget {
  const _CenterBlock({required this.controller});

  final MoodGardenController controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 20),
          child: Text(
            '今天，有什么\n想记下来的吗？',
            style: textTheme.displaySmall,
          ),
        ),
        _ChoiceButton(
          emoji: '🌻',
          title: '开心的事',
          subtitle: '记下来，会开出一片花瓣',
          onTap: () => AppRouter.pushRecordHappy(context),
        ),
        const SizedBox(height: 14),
        _ChoiceButton(
          emoji: '📜',
          title: '难过的事',
          subtitle: '写下来，然后烧掉它',
          onTap: () => AppRouter.pushRecordUnhappy(context),
        ),
        const SizedBox(height: 4),
        Text(
          '「${AppConstants.valueProposition}」',
          textAlign: TextAlign.center,
          style: textTheme.labelSmall,
        ),
      ],
    );
  }
}

/// 一个选择按钮：图标 + 标题 + 副标题。
///
/// 用玻璃拟态（半透明 + 模糊）而不是实心卡片：它压在花园背景上时仍然透气，
/// 这是原型贯穿始终的质感。
class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: '$title，$subtitle',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.creamWhite.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(color: AppColors.creamDeep),
          ),
          child: Row(
            children: <Widget>[
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(subtitle, style: textTheme.labelSmall),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.inkTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 底部：今日进度。
///
/// 文案随状态变化，但**不做催促**：记满了就说「今天的两件都记好了」，
/// 而不是「你已连续 0 天记录」这类带亏欠感的句子（PRD 7.2 的温和基调）。
class _FootHint extends StatelessWidget {
  const _FootHint({required this.controller});

  final MoodGardenController controller;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = controller.entriesOn(now);
    final happy = today.whereType<HappyEntry>().length;
    final released = today
        .whereType<UnhappyEntry>()
        .where((entry) => entry.isBurned)
        .length;

    final garden = controller.garden;
    final next = garden.nextBloomingAt(now);

    final parts = <String>[];
    if (happy > 0) {
      parts.add('今天种下 $happy 件');
    }
    if (released > 0) {
      parts.add('释放 $released 件');
    }

    final String hint;
    if (parts.isEmpty) {
      hint = '今天还没有记录。';
    } else {
      hint = parts.join(' · ');
    }

    final journey = next == null
        ? '花园里的花都开了。'
        : '下一朵还要 ${next.days} 天'
            '（${next.flower.stageAt(now) == GrowthStage.seed ? '种子' : '生长中'}）';

    return Column(
      children: <Widget>[
        Text(
          hint,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 3),
        Text(
          journey,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
