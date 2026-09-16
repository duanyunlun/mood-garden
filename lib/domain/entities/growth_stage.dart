/// 花朵生长阶段（PRD 7.1.2）。
///
/// 核心心智：花园中的花「并非静态统计数字，而是随真实时间流逝自然生长的活地图」——
/// 种子 → 发芽 → 抽叶 → 开花，用户每次打开 App 都能看到花朵「又长大了一点」。
enum GrowthStage {
  /// 种子：已入土，尚未破土。
  seed(label: '种子', emoji: '🌰'),

  /// 发芽：破土而出，可见嫩芽。
  sprout(label: '发芽', emoji: '🌱'),

  /// 抽叶：长出叶片，尚未结蕾。
  leafing(label: '抽叶', emoji: '🌿'),

  /// 开花：完全绽放，可被图鉴收录（PRD Tab3 花之图鉴）。
  blooming(label: '开花', emoji: '🌷');

  const GrowthStage({required this.label, required this.emoji});

  /// 阶段中文名。
  final String label;

  /// 阶段示意图标。骨架期用 emoji 占位，正式版替换为手绘插画资源。
  final String emoji;

  /// 是否为已绽放的终态。
  bool get isBlooming => this == GrowthStage.blooming;

  /// 从种子到当前阶段经过了几步，用于绘制生长进度条。
  int get progressIndex => index;

  /// 生长阶段总数，用于换算进度百分比。
  static int get totalStages => GrowthStage.values.length;
}
