/// 花园主题（PRD Tab4「花园主题换肤」）。
///
/// PRD 3.4 竞品对比中，「个性化主题」被列为本产品的差异化能力之一；
/// 用户故事中也提到「为我的花园更换不同的主题风格（如樱花谷、薰衣草坡）」。
///
/// 主题只改变花园的视觉皮肤，不影响任何机制数值。
class GardenThemeOption {
  const GardenThemeOption({
    required this.id,
    required this.name,
    required this.emoji,
    this.description = '',
    this.unlockHint = '',
  });

  /// 主题唯一标识。
  final String id;

  /// 主题显示名。
  final String name;

  /// 主题图标。骨架期用 emoji 占位。
  final String emoji;

  /// 主题描述。
  final String description;

  /// 未解锁时的解锁条件提示。
  ///
  /// ⚠️ PRD 第 12 章待定项：商业化模式（主题皮肤付费解锁）尚未定案，
  /// 此处仅保留字段，骨架期所有主题均可自由切换。
  final String unlockHint;

  /// 向日葵田 —— 默认主题。
  static const GardenThemeOption sunflowerField = GardenThemeOption(
    id: GardenThemeId.sunflowerField,
    name: '向日葵田',
    emoji: '🌻',
    description: '一望无际的暖橘黄，永远是晴天。',
  );

  /// 樱花谷。
  static const GardenThemeOption sakuraValley = GardenThemeOption(
    id: GardenThemeId.sakuraValley,
    name: '樱花谷',
    emoji: '🌸',
    description: '风一吹，花瓣就落满整条小径。',
  );

  /// 薰衣草坡。
  static const GardenThemeOption lavenderSlope = GardenThemeOption(
    id: GardenThemeId.lavenderSlope,
    name: '薰衣草坡',
    emoji: '💜',
    description: '傍晚的紫色斜坡，安静得能听见风声。',
  );

  /// 麦浪田。
  static const GardenThemeOption wheatField = GardenThemeOption(
    id: GardenThemeId.wheatField,
    name: '麦浪田',
    emoji: '🌾',
    description: '风过时，金色的波浪一层层涌过来。',
  );

  /// 全部主题。
  static const List<GardenThemeOption> catalog = <GardenThemeOption>[
    sunflowerField,
    sakuraValley,
    lavenderSlope,
    wheatField,
  ];

  /// 默认主题。
  static const GardenThemeOption fallback = sunflowerField;

  /// 按 id 查找主题。未找到时回退到默认主题，保证 UI 永不空指针。
  static GardenThemeOption byId(String id) {
    for (final theme in catalog) {
      if (theme.id == id) {
        return theme;
      }
    }
    return fallback;
  }
}

/// 花园主题 id 常量表。
abstract final class GardenThemeId {
  static const String sunflowerField = 'sunflower_field';
  static const String sakuraValley = 'sakura_valley';
  static const String lavenderSlope = 'lavender_slope';
  static const String wheatField = 'wheat_field';
}
