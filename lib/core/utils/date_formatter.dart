/// 日期时间格式化工具。
///
/// 刻意不引入 `intl` 依赖：骨架期只需中文单语展示，
/// 手写实现可以避免 `intl` 与 Flutter 版本间的约束冲突。
/// 正式支持多语言时（PRD 未要求，但后续可能拓展），再切换为 `intl` + ARB 方案。
abstract final class DateFormatter {
  static const List<String> _weekdayNames = <String>[
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日',
  ];

  /// `2026年3月16日`
  static String fullDate(DateTime date) =>
      '${date.year}年${date.month}月${date.day}日';

  /// `3月16日`
  static String monthDay(DateTime date) => '${date.month}月${date.day}日';

  /// `2026年3月`
  static String yearMonth(DateTime date) => '${date.year}年${date.month}月';

  /// `2026年`
  static String year(DateTime date) => '${date.year}年';

  /// `14:30`
  static String timeOfDay(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// `周一`
  static String weekday(DateTime date) =>
      _weekdayNames[(date.weekday - 1) % 7];

  /// `周一 14:30`
  static String weekdayWithTime(DateTime date) =>
      '${weekday(date)} ${timeOfDay(date)}';

  /// 相对今天的友好描述：`今天` / `昨天` / `前天` / `3月16日`。
  ///
  /// 供时光轴列表使用，让日期读起来更像回忆而非数据（PRD 11.3）。
  static String friendlyDay(DateTime date, {DateTime? now}) {
    final today = _dayOf(now ?? DateTime.now());
    final target = _dayOf(date);
    final diff = today.difference(target).inDays;

    return switch (diff) {
      0 => '今天',
      1 => '昨天',
      2 => '前天',
      _ when diff > 2 && diff < 7 => '$diff天前',
      _ => fullDate(date),
    };
  }

  /// 列表用的紧凑标签：`今天 14:30` / `昨天 09:12` / `3月16日 21:04`。
  static String entryTimestamp(DateTime date, {DateTime? now}) {
    final dayLabel = friendlyDay(date, now: now);
    return '$dayLabel ${timeOfDay(date)}';
  }

  /// 距今天数（正数表示过去）。
  static int daysAgo(DateTime date, {DateTime? now}) {
    final today = _dayOf(now ?? DateTime.now());
    return today.difference(_dayOf(date)).inDays;
  }

  /// 是否为同一天。
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 是否为今天。
  static bool isToday(DateTime date, {DateTime? now}) =>
      isSameDay(date, now ?? DateTime.now());

  /// 去掉时分秒，仅保留日期部分。
  static DateTime _dayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// 该月有多少天。
  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  /// 该月第一天是周几（1 = 周一）。
  static int firstWeekdayOfMonth(int year, int month) =>
      DateTime(year, month, 1).weekday;
}
