import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/mood_garden_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/flower_species.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/growth_stage.dart';
import '../../domain/entities/mood_entry.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/soft_card.dart';
import '../codex/widgets/codex_sections.dart';
import '../garden/widgets/garden_canvas.dart';
import 'garden_view_page.dart';

/// Tab3 我的花瓣（原型 v5 · `screen-petals`）。
///
/// 原型把「花园」与「图鉴」两件事合到了一页：
/// 上半部分是收集进度与走进花园的入口，下半部分才是花之图鉴。
///
/// 这样安排的理由说得通：用户来这里是为了看**自己攒到了什么**，
/// 「还差多少」和「已经有什么」本来就是同一个问题的两面，
/// 分成两个 Tab 反而要来回切。
///
/// 注意收集单位：原型用的是**花瓣**（每片花瓣攒成一个花苞）。
/// 当前仍是「种子 → 开花」的旧机制，第三阶段会替换；
/// 因此这里的文案与进度条按现有机制表述，不提前使用花瓣的说法——
/// 界面写着花瓣、算的却是种子，比不写更糟。
class PetalsPage extends StatelessWidget {
  const PetalsPage({super.key});

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

            final now = DateTime.now();

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                10,
                AppTheme.pagePadding,
                28,
              ),
              children: <Widget>[
                Text(
                  '我的花园',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  '每一片花瓣，都是你认真记下的一天',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 16),

                // 花园实景：一眼看到自己攒下的东西
                _GardenPreview(controller: controller, now: now),
                const SizedBox(height: 14),

                _StatRow(controller: controller, now: now),
                const SizedBox(height: 14),

                // 走进花园：全屏沉浸版
                _EnterGardenButton(controller: controller),

                const SizedBox(height: 26),
                const SectionHeader(
                  title: '各花种进度',
                  emoji: '🌱',
                  subtitle: '同类心情记够数量，就会开出对应的花',
                ),
                const SizedBox(height: 12),
                _SpeciesProgress(controller: controller, now: now),

                const SizedBox(height: 26),
                const SectionHeader(
                  title: '花之图鉴',
                  emoji: '📖',
                  subtitle: '已收集的花种与还没遇见的花',
                ),
                const SizedBox(height: 12),
                const CodexSections(showHeading: true),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 花园实景缩略图。
class _GardenPreview extends StatelessWidget {
  const _GardenPreview({required this.controller, required this.now});

  final MoodGardenController controller;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: GardenCanvas(
          flowers: controller.garden.flowers,
          now: now,
          height: 190,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => GardenViewPage(controller: controller),
            ),
          ),
        ),
      ),
    );
  }
}

/// 三个数字：养分 / 已绽放 / 已释放。
class _StatRow extends StatelessWidget {
  const _StatRow({required this.controller, required this.now});

  final MoodGardenController controller;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final garden = controller.garden;
    final bloomed = garden.flowers
        .where((f) => f.stageAt(now) == GrowthStage.blooming)
        .length;
    // 「已释放」= 已经烧掉的纸卷。未燃烧的草稿不计入：
    // 它们还没有完成「转化」这个动作。
    final released = controller.entries
        .whereType<UnhappyEntry>()
        .where((entry) => entry.isBurned)
        .length;

    return Row(
      children: <Widget>[
        Expanded(
          child: _Stat(
            emoji: '🌟',
            label: '养分',
            value: '${garden.nutrientValue}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(
            emoji: '🌸',
            label: '已绽放',
            value: '$bloomed 朵',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(
            emoji: '🕊️',
            label: '已释放',
            value: '$released 件',
          ),
        ),
      ],
    );
  }
}

/// 单个统计块。
class _Stat extends StatelessWidget {
  const _Stat({required this.emoji, required this.label, required this.value});

  final String emoji;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.creamSoft,
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
      ),
      child: Column(
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 5),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              color: AppColors.warmApricotDeep,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// 「走进花园 →」主按钮。
class _EnterGardenButton extends StatelessWidget {
  const _EnterGardenButton({required this.controller});

  final MoodGardenController controller;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '走进花园，全屏查看',
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => GardenViewPage(controller: controller),
          ),
        ),
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.warmApricot,
            borderRadius: BorderRadius.circular(AppTheme.pillRadius),
          ),
          child: Text(
            '走进花园 →',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.inkPrimary,
                ),
          ),
        ),
      ),
    );
  }
}

/// 各花种进度条。
///
/// 把「离下一朵还差几颗种子」直接写出来，而不是只给一个光秃秃的图标——
/// 收集玩法的动力来自**看得见的下一步**。
class _SpeciesProgress extends StatelessWidget {
  const _SpeciesProgress({required this.controller, required this.now});

  final MoodGardenController controller;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final garden = controller.garden;
    final textTheme = Theme.of(context).textTheme;
    final seeded = <FlowerSpecies>[
      for (final species in FlowerSpecies.catalog)
        if (garden.petalsOfSpecies(species.id) > 0) species,
    ];

    if (seeded.isEmpty) {
      return SoftCard(
        child: Text(
          '还没有种下任何花种。记一件开心事，第一颗种子就会入土。',
          style: textTheme.bodySmall,
        ),
      );
    }

    return SoftCard(
      child: Column(
        children: <Widget>[
          for (var i = 0; i < seeded.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 14),
            _SpeciesRow(
              species: seeded[i],
              seeds: garden.petalsOfSpecies(seeded[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

/// 单个花种的进度行。
class _SpeciesRow extends StatelessWidget {
  const _SpeciesRow({required this.species, required this.seeds});

  final FlowerSpecies species;
  final int seeds;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final inBloom = seeds ~/ AppConstants.petalsPerBloom;
    final into = seeds % AppConstants.petalsPerBloom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(species.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(species.name, style: textTheme.titleMedium),
            ),
            Text(
              inBloom > 0 ? '已绽放 $inBloom 朵' : '还差 ${AppConstants.petalsPerBloom - into} 颗',
              style: textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: into / AppConstants.petalsPerBloom,
            minHeight: 5,
            backgroundColor: AppColors.creamDeep,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.warmApricot,
            ),
          ),
        ),
      ],
    );
  }
}
