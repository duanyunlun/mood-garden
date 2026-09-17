import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/mood_garden_controller.dart';
import '../../application/settings_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/mood_entry.dart';
import '../../domain/entities/tag_catalog.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/soft_card.dart';
import '../../shared/widgets/soft_empty_state.dart';

/// 日期详情页（PRD 第 6 章 Tab2「日期详情页」）。
///
/// PRD 明确的页面结构：
/// - 当天种下的花（可查看原始文字 / 图片）
/// - 当天已转化的灰烬记录（仅显示「已转化为养分」封条式提示，**内容不可查看**）
///
/// 该页是 PRD 7.2.3 隐私承诺的用户可见落点：
/// 已燃烧的纸卷在此处只有一条抽象封条，既没有原文，也没有「查看详情」入口。
/// 这不是 UI 层面的隐藏，而是数据在模型层就已被擦除（见 `UnhappyEntry.burn`）——
/// 因此即使有人拿到存储文件，也读不出任何内容。
class DateDetailPage extends StatelessWidget {
  const DateDetailPage({required this.day, super.key});

  /// 查看的日期。
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        title: Text(DateFormatter.fullDate(day)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Consumer<MoodGardenController>(
        builder: (context, controller, _) {
          final entries = controller.entriesOn(day);
          if (entries.isEmpty) {
            return const SoftEmptyState(
              emoji: '🌾',
              title: '这一天还没有记录',
              description: '空白的日子也很好。\n如果想起了什么，随时可以补记。',
            );
          }

          final happy = entries.whereType<HappyEntry>().toList(growable: false);
          final unhappy =
              entries.whereType<UnhappyEntry>().toList(growable: false);
          final burned =
              unhappy.where((e) => e.isBurned).toList(growable: false);
          final pending =
              unhappy.where((e) => !e.isBurned).toList(growable: false);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              10,
              AppTheme.pagePadding,
              32,
            ),
            children: <Widget>[
              _DaySummary(
                day: day,
                happyCount: happy.length,
                burnedCount: burned.length,
              ),

              if (happy.isNotEmpty) ...<Widget>[
                const SizedBox(height: 22),
                SectionHeader(
                  title: '这天种下的花',
                  emoji: '🌱',
                  subtitle: '共 ${happy.length} 件开心事',
                ),
                const SizedBox(height: 12),
                for (final entry in happy) ...<Widget>[
                  _HappyEntryCard(entry: entry),
                  const SizedBox(height: 12),
                ],
              ],

              if (burned.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                SectionHeader(
                  title: '这天转化的纸卷',
                  emoji: '🕊️',
                  subtitle: '共 ${burned.length} 张，已化为养分',
                ),
                const SizedBox(height: 12),
                for (final entry in burned) ...<Widget>[
                  _AshSeal(burnedAt: entry.burnedAt!),
                  const SizedBox(height: 10),
                ],
              ],

              if (pending.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                SectionHeader(
                  title: '还没点燃的纸卷',
                  emoji: '📜',
                  subtitle: '共 ${pending.length} 张',
                ),
                const SizedBox(height: 12),
                for (final entry in pending) ...<Widget>[
                  _PendingScrollCard(entry: entry),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 当日概览。
class _DaySummary extends StatelessWidget {
  const _DaySummary({
    required this.day,
    required this.happyCount,
    required this.burnedCount,
  });

  final DateTime day;
  final int happyCount;
  final int burnedCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SoftCard(
      color: AppColors.warmApricotTint,
      border: const BorderSide(color: AppColors.warmApricotSoft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            DateFormatter.friendlyDay(day),
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '${DateFormatter.weekday(day)} · 这一天留下的痕迹',
            style: textTheme.labelSmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (happyCount > 0)
                _Pill(
                  emoji: '🌱',
                  label: '种下 $happyCount 件',
                  color: AppColors.warmApricotSoft,
                ),
              if (burnedCount > 0)
                _Pill(
                  emoji: '🕊️',
                  label: '转化 $burnedCount 张',
                  color: AppColors.ashSoft,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.emoji,
    required this.label,
    required this.color,
  });

  final String emoji;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
      ),
      child: Text(
        '$emoji $label',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.inkPrimary,
            ),
      ),
    );
  }
}

/// 开心事记录卡片。原文可查看（PRD Tab2：可查看原始文字 / 图片）。
class _HappyEntryCard extends StatelessWidget {
  const _HappyEntryCard({required this.entry});

  final HappyEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // 标签要能还原进化款、隐藏款与自定义标签，否则这些记录会退化成「记录 · 花」。
    final customTags =
        context.watch<SettingsController>().settings.customTags;
    final tag = TagCatalog.displayTag(entry.tagId, customTags: customTags);
    final species = tag?.species;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                tag?.emoji ?? '🌱',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${tag?.label ?? '记录'} · ${species?.name ?? '花'}',
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.warmApricotDeep,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormatter.timeOfDay(entry.occurredAt) +
                          (entry.isBackfilled ? ' · 补记' : ''),
                      style: textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (entry.text.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(entry.text, style: textTheme.bodyLarge),
          ],
          if (entry.imagePaths.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _ImageStrip(imageIds: entry.imagePaths),
          ],
        ],
      ),
    );
  }
}

/// 记录附图条。
///
/// 图片是加密存的，这里按需解密后渲染——磁盘上没有可直接打开的明文图片文件。
/// 单击任意一张进入全屏查看。
class _ImageStrip extends StatefulWidget {
  const _ImageStrip({required this.imageIds});

  final List<String> imageIds;

  @override
  State<_ImageStrip> createState() => _ImageStripState();
}

class _ImageStripState extends State<_ImageStrip> {
  static const double _thumbSize = 92;

  late final Future<List<Uint8List>> _images = _load();

  Future<List<Uint8List>> _load() async {
    final controller = context.read<MoodGardenController>();
    final loaded = <Uint8List>[];
    for (final id in widget.imageIds) {
      final bytes = await controller.loadImage(id);
      // 解不开的那一张直接跳过：少一张图，好过整页记录打不开。
      if (bytes != null) {
        loaded.add(bytes);
      }
    }
    return loaded;
  }

  void _openViewer(List<Uint8List> images, int index) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, _, _) => _ImageViewer(images: images, initial: index),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Uint8List>>(
      future: _images,
      builder: (context, snapshot) {
        final images = snapshot.data;
        if (images == null) {
          // 解密是毫秒级的本地操作，给个等高占位避免卡片高度跳动。
          return const SizedBox(height: _thumbSize);
        }
        if (images.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: _thumbSize,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) => Semantics(
              button: true,
              label: '查看第 ${index + 1} 张图片',
              child: GestureDetector(
                onTap: () => _openViewer(images, index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    images[index],
                    width: _thumbSize,
                    height: _thumbSize,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 全屏看图。支持双指缩放与左右切换。
class _ImageViewer extends StatefulWidget {
  const _ImageViewer({required this.images, required this.initial});

  final List<Uint8List> images;
  final int initial;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final PageController _pageController =
      PageController(initialPage: widget.initial);
  late int _current = widget.initial;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Stack(
          children: <Widget>[
            PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _current = index),
              itemBuilder: (context, index) => InteractiveViewer(
                maxScale: 4,
                child: Center(
                  child: Image.memory(widget.images[index], fit: BoxFit.contain),
                ),
              ),
            ),
            if (widget.images.length > 1)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    '${_current + 1} / ${widget.images.length}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 灰烬封条（PRD 7.2.3）。
///
/// > 该记录在时光轴中仅保留一个抽象的「已转化为养分」封条式提示
/// > （不显示原文字 / 图片内容），原始记录内容不可再次查看、不可恢复。
///
/// 注意此组件**没有** `onTap`——不提供任何进入详情的路径。
/// 这是刻意的：封条是这条记录在世界上留下的最后痕迹。
class _AshSeal extends StatelessWidget {
  const _AshSeal({required this.burnedAt});

  /// 燃烧时刻。
  final DateTime burnedAt;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: '一条已转化为养分的记录，内容不可查看',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.ashSoft,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(
            color: AppColors.ash.withValues(alpha: 0.28),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: <Widget>[
            const Text('🕊️', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '已转化为养分',
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.ash,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${DateFormatter.timeOfDay(burnedAt)} 点燃 · 内容已随灰烬散去',
                    style: textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 尚未点燃的纸卷卡片。
class _PendingScrollCard extends StatelessWidget {
  const _PendingScrollCard({required this.entry});

  final UnhappyEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SoftCard(
      color: AppColors.mistyRoseTint,
      border: const BorderSide(color: AppColors.mistyRoseSoft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('📜', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                '还没点燃',
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.mistyRoseDeep,
                ),
              ),
              const Spacer(),
              Text(
                DateFormatter.timeOfDay(entry.occurredAt),
                style: textTheme.labelSmall,
              ),
            ],
          ),
          if (entry.text.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(entry.text, style: textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
