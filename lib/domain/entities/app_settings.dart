import 'mood_tag.dart';

/// 用户可调的应用设置。
///
/// 与花园状态分开放，因为两者性质不同：
/// 花园是「用户做了什么」的结果，设置是「用户希望怎么用」；
/// 前者的读写发生在每次记录，后者只在用户主动调整时发生。
class AppSettings {
  const AppSettings({
    this.textScale = 1.0,
    this.customTags = const <MoodTag>[],
    this.reminderEnabled = false,
    this.reminderHour = 21,
    this.reminderMinute = 0,
    this.soundEnabled = true,
  });

  /// 新用户的初始设置。
  static const AppSettings defaults = AppSettings();

  /// 应用内字体缩放。
  ///
  /// `1.0` 表示不干预、完全跟随系统（PRD 第 10 章的无障碍要求本来就是这样）。
  /// 这里额外给用户一个「我觉得还不够大」的补偿档位，
  /// 范围见 `AppConstants.textScaleMin/Max`。
  final double textScale;

  /// 用户自定义的心情标签（预设六个之外）。
  final List<MoodTag> customTags;

  /// 是否开启每日提醒（PRD Tab4 P1）。
  final bool reminderEnabled;

  /// 提醒时刻（24 小时制）。
  final int reminderHour;
  final int reminderMinute;

  /// 是否播放仪式音效（PRD 7.2.2）。
  ///
  /// 默认开——音效是这套仪式感的一部分；但它也是最容易打扰到旁人的一环，
  /// 所以要给一个明确的关闭入口。
  final bool soundEnabled;

  /// 预设标签 + 自定义标签。界面上一律用这个列表。
  List<MoodTag> get allTags => <MoodTag>[...MoodTag.presets, ...customTags];

  /// 按 id 找标签，先查预设再查自定义。找不到返回 `null`。
  MoodTag? tagById(String id) {
    for (final tag in allTags) {
      if (tag.id == id) {
        return tag;
      }
    }
    return null;
  }

  AppSettings copyWith({
    double? textScale,
    List<MoodTag>? customTags,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? soundEnabled,
  }) {
    return AppSettings(
      textScale: textScale ?? this.textScale,
      customTags: customTags ?? this.customTags,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }

  @override
  String toString() =>
      'AppSettings(textScale: $textScale, customTags: ${customTags.length}, '
      'reminder: $reminderEnabled @$reminderHour:$reminderMinute, '
      'sound: $soundEnabled)';
}
