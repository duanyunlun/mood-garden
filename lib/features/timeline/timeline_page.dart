import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/mood_garden_controller.dart';
import '../../application/settings_controller.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/entry_filter.dart';
import '../../domain/entities/mood_entry.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/soft_card.dart';
import '../../shared/widgets/soft_empty_state.dart';

/// 时光轴的多视图模式（PRD Tab2）。
enum TimelineView {
  week(label: '周'),
  month(label: '月'),
  year(label: '年');

  const TimelineView({required this.label});

  final String label;
}

/// Tab2 时光轴（PRD 第 6 章信息架构 / Tab2 定义）。
///
/// 页面构成对齐 PRD：
/// - 视图切换：周视图 / 月视图 / 年视图
/// - 日期详情页（点击某天）
///
/// ⚠️ PRD 中「搜索 / 筛选（按心情标签筛选历史记录）」标记为 P2，
/// 骨架期不实现，已在 `docs/ROADMAP.md` 中记录。
class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  TimelineView _view = TimelineView.month;
  late DateTime _anchor;

  /// 当前筛选条件（PRD Tab2 P2）。空筛选表示看全部。
  EntryFilter _filter = EntryFilter.none;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchor = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 打开标签筛选面板（PRD Tab2 P2）。
  ///
  /// 面板里改的是**草稿**，点「应用」才生效——否则每点一个标签
  /// 背后的三个视图都要重算一遍，页面会跟着抖。
  Future<void> _pickTags(
    BuildContext context,
    MoodGardenController controller,
  ) async {
    final settings = context.read<SettingsController>();
    final tags = controller.availableTags(
      customTags: settings.settings.customTags,
    );

    var draft = _filter;
    final picked = await showModalBottomSheet<EntryFilter>(
      context: context,
      backgroundColor: AppColors.creamWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.cardRadius),
        ),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final textTheme = Theme.of(sheetContext).textTheme;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.pagePadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('按心情筛选', style: textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    '可以多选。烧掉的纸卷没有心情标签，筛选时不会出现。',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final item in tags)
                        _SelectableChip(
                          label: item.tag.label,
                          emoji: item.tag.emoji,
                          selected: draft.tagIds.contains(item.tag.id),
                          onTap: () => setSheetState(
                            () => draft = draft.toggleTag(item.tag.id),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setSheetState(
                            () => draft = draft.copyWith(tagIds: <String>{}),
                          ),
                          child: const Text('清空标签'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(draft),
                          child: const Text('应用'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (picked != null && mounted) {
      setState(() => _filter = picked);
    }
  }

  void _shift(int delta) {
    setState(() {
      _anchor = switch (_view) {
        TimelineView.week => _anchor.add(Duration(days: 7 * delta)),
        TimelineView.month => DateTime(_anchor.year, _anchor.month + delta, 1),
        TimelineView.year => DateTime(_anchor.year + delta, _anchor.month, 1),
      };
    });
  }

  String get _periodLabel => switch (_view) {
        TimelineView.week => _weekLabel(),
        TimelineView.month =>
          '${_anchor.year}年${_anchor.month}月',
        TimelineView.year => '${_anchor.year}年',
      };

  String _weekLabel() {
    final start = _weekStart(_anchor);
    final end = start.add(const Duration(days: 6));
    if (start.month == end.month) {
      return '${start.month}月${start.day}日 - ${end.day}日';
    }
    return '${start.month}月${start.day}日 - ${end.month}月${end.day}日';
  }

  static DateTime _weekStart(DateTime day) {
    final base = DateTime(day.year, day.month, day.day);
    return base.subtract(Duration(days: base.weekday - 1));
  }

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

            return Column(
              children: <Widget>[
                _ViewSwitcher(
                  current: _view,
                  onChanged: (view) => setState(() => _view = view),
                ),
                _PeriodNavigator(
                  label: _periodLabel,
                  onPrevious: () => _shift(-1),
                  onNext: () => _shift(1),
                  onToday: () => setState(() {
                    final now = DateTime.now();
                    _anchor = DateTime(now.year, now.month, now.day);
                  }),
                ),
                _FilterBar(
                  filter: _filter,
                  searchController: _searchController,
                  onChanged: (next) => setState(() => _filter = next),
                  onPickTags: () => _pickTags(context, controller),
                ),
                Expanded(
                  child: switch (_view) {
                    TimelineView.week => _WeekView(
                        anchor: _anchor,
                        controller: controller,
                        filter: _filter,
                      ),
                    TimelineView.month => _MonthView(
                        anchor: _anchor,
                        controller: controller,
                        filter: _filter,
                      ),
                    TimelineView.year => _YearView(
                        anchor: _anchor,
                        controller: controller,
                        filter: _filter,
                        onMonthSelected: (year, month) {
                          setState(() {
                            _anchor = DateTime(year, month, 1);
                            _view = TimelineView.month;
                          });
                        },
                      ),
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}


/// 时光轴筛选条：搜索框 + 标签筛选入口 + 当前生效条件。
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.searchController,
    required this.onChanged,
    required this.onPickTags,
  });

  final EntryFilter filter;
  final TextEditingController searchController;
  final ValueChanged<EntryFilter> onChanged;
  final VoidCallback onPickTags;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        0,
        AppTheme.pagePadding,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: (value) =>
                      onChanged(filter.copyWith(keyword: value)),
                  style: textTheme.bodySmall,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '搜搜写过什么',
                    hintStyle: textTheme.labelSmall,
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 18,
                      color: AppColors.inkTertiary,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TagFilterButton(
                count: filter.tagIds.length,
                onTap: onPickTags,
              ),
            ],
          ),
          if (filter.isActive) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    filter.summary,
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.warmApricotDeep,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    searchController.clear();
                    onChanged(EntryFilter.none);
                  },
                  child: const Text('清除筛选'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 标签筛选入口，带已选数量角标。
class _TagFilterButton extends StatelessWidget {
  const _TagFilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count == 0 ? '按心情筛选' : '按心情筛选，已选 $count 个标签',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: count > 0 ? AppColors.warmApricotSoft : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.pillRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('🏷️', style: TextStyle(fontSize: 14)),
              if (count > 0) ...<Widget>[
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.warmApricotDeep,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 筛选面板里的可多选标签。
class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: '$label 标签',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.warmApricotSoft : AppColors.creamSoft,
            borderRadius: BorderRadius.circular(AppTheme.pillRadius),
            border: Border.all(
              color: selected ? AppColors.warmApricot : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 5),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

/// 周 / 月 / 年 视图切换。
class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({required this.current, required this.onChanged});

  final TimelineView current;
  final ValueChanged<TimelineView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        10,
        AppTheme.pagePadding,
        6,
      ),
      // 用 Wrap 而非 Row + Spacer：字体放大到 2x 时标题与视图切换器会挤不下，
      // Wrap 让切换器折到下一行，而不是把标题压到溢出（PRD 第 10 章无障碍）。
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: <Widget>[
          Text(
            '时光轴',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SegmentedButton<TimelineView>(
            segments: TimelineView.values
                .map(
                  (view) => ButtonSegment<TimelineView>(
                    value: view,
                    label: Text(view.label),
                  ),
                )
                .toList(growable: false),
            selected: <TimelineView>{current},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onChanged(selection.first),
            style: SegmentedButton.styleFrom(
              backgroundColor: AppColors.creamSoft,
              foregroundColor: AppColors.inkSecondary,
              selectedBackgroundColor: AppColors.warmApricotSoft,
              selectedForegroundColor: AppColors.warmApricotDeep,
              side: BorderSide.none,
              textStyle: Theme.of(context).textTheme.labelMedium,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

/// 时间区间导航（上一个 / 下一个 / 回到今天）。
class _PeriodNavigator extends StatelessWidget {
  const _PeriodNavigator({
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.pagePadding - 6,
        vertical: 4,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            color: AppColors.inkSecondary,
            tooltip: '上一段时间',
          ),
          Expanded(
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          TextButton(
            onPressed: onToday,
            child: const Text('今天'),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            color: AppColors.inkSecondary,
            tooltip: '下一段时间',
          ),
        ],
      ),
    );
  }
}

/// 周视图：7 天纵向列表，每天展示当天记录摘要。
class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.anchor,
    required this.controller,
    required this.filter,
  });

  final DateTime anchor;
  final MoodGardenController controller;
  final EntryFilter filter;

  @override
  Widget build(BuildContext context) {
    final start = _TimelinePageState._weekStart(anchor);
    final days = List<DateTime>.generate(
      7,
      (i) => start.add(Duration(days: i)),
      growable: false,
    );

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        8,
        AppTheme.pagePadding,
        28,
      ),
      itemCount: days.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final day = days[index];
        return _DayCard(day: day, controller: controller, filter: filter);
      },
    );
  }
}

/// 周视图中的单日卡片。
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.controller,
    required this.filter,
  });

  final DateTime day;
  final MoodGardenController controller;
  final EntryFilter filter;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final entries = controller.entriesOn(day, filter: filter);
    final isToday = DateFormatter.isToday(day);

    return SoftCard(
      onTap: () => AppRouter.pushDateDetail(context, day),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: isToday ? AppColors.warmApricotTint : Colors.white,
      border: isToday
          ? const BorderSide(color: AppColors.warmApricotSoft)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '${day.day}',
                style: textTheme.titleLarge?.copyWith(
                  color: isToday
                      ? AppColors.warmApricotDeep
                      : AppColors.inkPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(DateFormatter.weekday(day), style: textTheme.labelMedium),
              const Spacer(),
              Text(
                entries.isEmpty ? '还没有记录' : '${entries.length} 条记录',
                style: textTheme.labelSmall,
              ),
            ],
          ),
          if (entries.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            _EntryLine(entries: entries),
          ],
        ],
      ),
    );
  }
}

/// 记录摘要行。用 emoji 点阵概况当天记录构成，避免逐条罗列造成信息过载。
class _EntryLine extends StatelessWidget {
  const _EntryLine({required this.entries});

  final List<MoodEntry> entries;

  @override
  Widget build(BuildContext context) {
    final happy = entries.whereType<HappyEntry>().length;
    final burned = entries
        .whereType<UnhappyEntry>()
        .where((e) => e.isBurned)
        .length;
    final pending = entries
        .whereType<UnhappyEntry>()
        .where((e) => !e.isBurned)
        .length;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: <Widget>[
        if (happy > 0) _MiniChip(emoji: '🌱', label: '种下 $happy 件'),
        if (burned > 0) _MiniChip(emoji: '🕊️', label: '转化 $burned 张'),
        if (pending > 0) _MiniChip(emoji: '📜', label: '待点燃 $pending 张'),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.emoji, required this.label});

  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.creamSoft,
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
      ),
      child: Text(
        '$emoji $label',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

/// 月视图：日历网格。有记录的日期用暖橘黄圆点标记，已转化的纸卷用灰点标记。
class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.anchor,
    required this.controller,
    required this.filter,
  });

  final DateTime anchor;
  final MoodGardenController controller;
  final EntryFilter filter;

  static const List<String> _weekdayHeaders = <String>[
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  @override
  Widget build(BuildContext context) {
    final year = anchor.year;
    final month = anchor.month;
    final leadingBlanks = DateFormatter.firstWeekdayOfMonth(year, month) - 1;
    final daysInMonth = DateFormatter.daysInMonth(year, month);
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        8,
        AppTheme.pagePadding,
        28,
      ),
      children: <Widget>[
        SoftCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              Row(
                children: _weekdayHeaders
                    .map(
                      (w) => Expanded(
                        child: Center(
                          child: Text(
                            w,
                            style:
                                Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 6),
              for (var row = 0; row < rows; row++)
                Row(
                  children: List<Widget>.generate(7, (col) {
                    final cellIndex = row * 7 + col;
                    final dayNumber = cellIndex - leadingBlanks + 1;
                    if (dayNumber < 1 || dayNumber > daysInMonth) {
                      return const Expanded(child: SizedBox(height: 52));
                    }
                    return Expanded(
                      child: _DayCell(
                        day: DateTime(year, month, dayNumber),
                        controller: controller,
                        filter: filter,
                      ),
                    );
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionHeader(
          title: '这个月的记录',
          emoji: '📖',
          subtitle: '点任意一天查看当天完整内容',
        ),
        const SizedBox(height: 12),
        _MonthDigest(
          year: year,
          month: month,
          controller: controller,
          filter: filter,
        ),
      ],
    );
  }
}

/// 月视图中的单个日期格。
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.controller,
    required this.filter,
  });

  final DateTime day;
  final MoodGardenController controller;
  final EntryFilter filter;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final entries = controller.entriesOn(day, filter: filter);
    final isToday = DateFormatter.isToday(day);
    final happy = entries.whereType<HappyEntry>().length;
    final burned = entries
        .whereType<UnhappyEntry>()
        .where((e) => e.isBurned)
        .length;

    return InkWell(
      onTap: () => AppRouter.pushDateDetail(context, day),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isToday ? AppColors.warmApricotSoft : null,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${day.day}',
                style: textTheme.bodySmall?.copyWith(
                  color: isToday
                      ? AppColors.warmApricotDeep
                      : AppColors.inkPrimary,
                  fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (happy > 0)
                    const _Dot(color: AppColors.warmApricot),
                  if (happy > 0 && burned > 0) const SizedBox(width: 3),
                  if (burned > 0)
                    const _Dot(color: AppColors.ash, hollow: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, this.hollow = false});

  final Color color;

  /// 空心表示「已转化」。
  ///
  /// 用形状而不只是颜色来区分两种记录：全色盲用户看不出暖橘黄与灰烬色的差别，
  /// 但看得出实心与空心（PRD 第 10 章要求照顾色弱 / 色盲用户的可辨识度）。
  final bool hollow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: hollow ? null : color,
        border: hollow ? Border.all(color: color, width: 1.2) : null,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 月视图底部的当月汇总。
class _MonthDigest extends StatelessWidget {
  const _MonthDigest({
    required this.year,
    required this.month,
    required this.controller,
    required this.filter,
  });

  final int year;
  final int month;
  final MoodGardenController controller;
  final EntryFilter filter;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateFormatter.daysInMonth(year, month);
    var happy = 0;
    var burned = 0;
    var activeDays = 0;

    for (var d = 1; d <= daysInMonth; d++) {
      final entries = controller.entriesOn(DateTime(year, month, d), filter: filter);
      if (entries.isEmpty) {
        continue;
      }
      activeDays++;
      happy += entries.whereType<HappyEntry>().length;
      burned += entries
          .whereType<UnhappyEntry>()
          .where((e) => e.isBurned)
          .length;
    }

    if (activeDays == 0) {
      return const SoftCard(
        child: SoftEmptyState(
          emoji: '🍃',
          title: '这个月还很安静',
          description: '记录下来的每一天，都会在这里留下一片叶子。',
          compact: true,
        ),
      );
    }

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '这个月你记录了 $activeDays 天',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MiniChip(emoji: '🌱', label: '种下 $happy 件开心事'),
              if (burned > 0)
                _MiniChip(emoji: '🕊️', label: '转化 $burned 张纸卷'),
            ],
          ),
        ],
      ),
    );
  }
}

/// 年视图：12 个月份卡片，展示每个月的记录密度。
class _YearView extends StatelessWidget {
  const _YearView({
    required this.anchor,
    required this.controller,
    required this.filter,
    required this.onMonthSelected,
  });

  final DateTime anchor;
  final MoodGardenController controller;
  final EntryFilter filter;

  /// 点击某个月份时下钻到月视图。
  final void Function(int year, int month) onMonthSelected;

  @override
  Widget build(BuildContext context) {
    final year = anchor.year;

    // 与图鉴、花园主题选择器同理：用 Wrap + 固定列宽，而不是 GridView 的
    // 固定宽高比。GridView 的 childAspectRatio 意味着固定行高，一旦系统字体
    // 放大（PRD 第 10 章「无障碍」要求文字大小可调节），Column 就会
    // RenderFlex overflow；Wrap 的卡片高度由内容决定，永不溢出。
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const columns = 3;
        // 注意要扣掉页面左右安全边距，否则每行会超出可用宽度。
        final available = constraints.maxWidth - AppTheme.pagePadding * 2;
        final itemWidth = (available - spacing * (columns - 1)) / columns;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            8,
            AppTheme.pagePadding,
            28,
          ),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: <Widget>[
              for (var month = 1; month <= 12; month++)
                SizedBox(
                  width: itemWidth,
                  child: _MonthTile(
                    year: year,
                    month: month,
                    controller: controller,
                    filter: filter,
                    // 点击月份下钻到月视图
                    onTap: () => onMonthSelected(year, month),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MonthTile extends StatelessWidget {
  const _MonthTile({
    required this.year,
    required this.month,
    required this.controller,
    required this.filter,
    required this.onTap,
  });

  final int year;
  final int month;
  final MoodGardenController controller;
  final EntryFilter filter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final daysInMonth = DateFormatter.daysInMonth(year, month);
    var count = 0;
    for (var d = 1; d <= daysInMonth; d++) {
      count += controller.entriesOn(DateTime(year, month, d), filter: filter).length;
    }

    final ratio = daysInMonth == 0 ? 0.0 : (count / daysInMonth).clamp(0.0, 1.0);

    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      color: count == 0
          ? AppColors.creamSoft
          : Color.lerp(
              AppColors.warmApricotTint,
              AppColors.warmApricotSoft,
              ratio,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // Wrap 中高度不受约束，必须用 min 尺寸；间距改用显式 SizedBox
        // （spaceBetween 在 min 尺寸下没有多余空间可分配）。
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('$month月', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            count == 0 ? '安静' : '$count 条',
            style: textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
