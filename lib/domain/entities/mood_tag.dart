import 'flower_species.dart';

/// 心情标签。
///
/// 依据 PRD 7.1.1 步骤 3：用户为开心事选择一个心情标签，**标签与花种一一对应**，
/// 例如「感恩 → 向日葵」「惊喜 → 郁金香」。
///
/// 同时支撑 Tab4「快捷标签管理（自定义常用心情/场景标签）」——
/// 因此这里是可扩展的类而非 enum：[isCustom] 为 `true` 的标签由用户创建。
class MoodTag {
  const MoodTag({
    required this.id,
    required this.label,
    required this.emoji,
    required this.speciesId,
    this.isCustom = false,
  });

  /// 标签唯一标识。自定义标签使用 `custom_` 前缀。
  final String id;

  /// 标签显示名，如「感恩」「陪伴」。
  final String label;

  /// 标签图标。骨架期用 emoji 占位，正式版替换为手绘插画。
  final String emoji;

  /// 该标签对应的花种 id，见 [FlowerSpeciesId]。
  final String speciesId;

  /// 是否为用户自定义标签。
  final bool isCustom;

  /// 该标签对应的花种。若花种目录中不存在则返回 `null`。
  ///
  /// ⚠️ PRD 第 12 章待定项：完整的「标签-花种对照表」尚未定案，
  /// 当前仅实现 PRD 7.1.1 明确举例的六个标签。
  FlowerSpecies? get species => FlowerSpecies.byId(speciesId);

  /// 内置预设标签（PRD 7.1.1 步骤 3 列举的示例）。
  static const List<MoodTag> presets = <MoodTag>[
    MoodTag(
      id: MoodTagId.gratitude,
      label: '感恩',
      emoji: '🌻',
      speciesId: FlowerSpeciesId.sunflower,
    ),
    MoodTag(
      id: MoodTagId.surprise,
      label: '惊喜',
      emoji: '🌷',
      speciesId: FlowerSpeciesId.tulip,
    ),
    MoodTag(
      id: MoodTagId.companionship,
      label: '陪伴',
      emoji: '💜',
      speciesId: FlowerSpeciesId.lavender,
    ),
    MoodTag(
      id: MoodTagId.achievement,
      label: '成就',
      emoji: '🌾',
      speciesId: FlowerSpeciesId.wheat,
    ),
    MoodTag(
      id: MoodTagId.food,
      label: '美食',
      emoji: '🌸',
      speciesId: FlowerSpeciesId.sakura,
    ),
    MoodTag(
      id: MoodTagId.calm,
      label: '平静',
      emoji: '🍀',
      speciesId: FlowerSpeciesId.clover,
    ),
  ];

  /// 按 id 在预设标签中查找。未找到返回 `null`。
  static MoodTag? presetById(String id) {
    for (final tag in presets) {
      if (tag.id == id) {
        return tag;
      }
    }
    return null;
  }

  MoodTag copyWith({
    String? label,
    String? emoji,
    String? speciesId,
    bool? isCustom,
  }) {
    return MoodTag(
      id: id,
      label: label ?? this.label,
      emoji: emoji ?? this.emoji,
      speciesId: speciesId ?? this.speciesId,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoodTag &&
          other.id == id &&
          other.label == label &&
          other.emoji == emoji &&
          other.speciesId == speciesId &&
          other.isCustom == isCustom;

  @override
  int get hashCode => Object.hash(id, label, emoji, speciesId, isCustom);

  @override
  String toString() => 'MoodTag($id, $label)';
}

/// 预设心情标签的 id 常量表。
abstract final class MoodTagId {
  static const String gratitude = 'gratitude';
  static const String surprise = 'surprise';
  static const String companionship = 'companionship';
  static const String achievement = 'achievement';
  static const String food = 'food';
  static const String calm = 'calm';

  /// 自定义标签的 id 前缀。
  ///
  /// 用它区分内置标签与用户创建的标签——例如删除时只允许删后者。
  static const String customPrefix = 'custom';

  /// 隐藏款标签的 id 前缀（连续记录达标后出现，PRD 7.1.3）。
  static const String hiddenPrefix = 'hidden';
}
