import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/mood_garden_controller.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchor = DateTime(now.year, now.month, now.day);
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
                Expanded(
                  child: switch (_view) {
                    TimelineView.week =>
                      _WeekView(anchor: _anchor, controller: controller),
                    TimelineView.month =>
                      _MonthView(anchor: _anchor, controller: controller),
                    TimelineView.year => _YearView(
                        anchor: _anchor,
                        controller: controller,
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
      child: Row(
        children: <Widget>[
          Text(
            '时光轴',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Spacer(),
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
  const _WeekView({required this.anchor, required this.controller});

  final DateTime anchor;
  final MoodGardenController controller;

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
        return _DayCard(day: day, controller: controller);
      },
    );
  }
}

/// 周视图中的单日卡片。
class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.controller});

  final DateTime day;
  final MoodGardenController controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final entries = controller.entriesOn(day);
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
  const _MonthView({required this.anchor, required this.controller});

  final DateTime anchor;
  final MoodGardenController controller;

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
        ),
      ],
    );
  }
}

/// 月视图中的单个日期格。
class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.controller});

  final DateTime day;
  final MoodGardenController controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final entries = controller.entriesOn(day);
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
                  if (burned > 0) const _Dot(color: AppColors.ash),
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
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// 月视图底部的当月汇总。
class _MonthDigest extends StatelessWidget {
  const _MonthDigest({
    required this.year,
    required this.month,
    required this.controller,
  });

  final int year;
  final int month;
  final MoodGardenController controller;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateFormatter.daysInMonth(year, month);
    var happy = 0;
    var burned = 0;
    var activeDays = 0;

    for (var d = 1; d <= daysInMonth; d++) {
      final entries = controller.entriesOn(DateTime(year, month, d));
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
    required this.onMonthSelected,
  });

  final DateTime anchor;
  final MoodGardenController controller;

  /// 点击某个月份时下钻到月视图。
  final void Function(int year, int month) onMonthSelected;

  @override
  Widget build(BuildContext context) {
    final year = anchor.year;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        8,
        AppTheme.pagePadding,
        28,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.92,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final month = index + 1;
        return _MonthTile(
          year: year,
          month: month,
          controller: controller,
          // 点击月份下钻到月视图
          onTap: () => onMonthSelected(year, month),
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
    required this.onTap,
  });

  final int year;
  final int month;
  final MoodGardenController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final daysInMonth = DateFormatter.daysInMonth(year, month);
    var count = 0;
    for (var d = 1; d <= daysInMonth; d++) {
      count += controller.entriesOn(DateTime(year, month, d)).length;
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('$month月', style: textTheme.titleMedium),
          Text(
            count == 0 ? '安静' : '$count 条',
            style: textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
