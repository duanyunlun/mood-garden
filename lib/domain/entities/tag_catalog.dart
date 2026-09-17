import '../../core/constants/app_constants.dart';
import 'flower_species.dart';
import 'garden_state.dart';
import 'mood_tag.dart';

/// 一个「现在能不能选」的标签。
///
/// 不只是标签本身，还带上可用性与不可用原因——因为 PRD 7.1.3 的三种进阶玩法
/// （进化款、隐藏款、季节限定）最终都收敛成同一个问题：
/// **此刻这个标签能不能种，不能种的话为什么。**
class SelectableTag {
  const SelectableTag({
    required this.tag,
    this.isEvolved = false,
    this.isHidden = false,
    this.unavailableReason,
  });

  /// 实际用于记录的标签。
  final MoodTag tag;

  /// 是否为解锁后的进化形态。
  final bool isEvolved;

  /// 是否为连续记录解锁的隐藏款。
  final bool isHidden;

  /// 不可用原因（如「3-4 月可种」）。为 `null` 表示现在可以种。
  final String? unavailableReason;

  /// 此刻是否可种。
  bool get isAvailable => unavailableReason == null;
}

/// 由花园进度推导「现在能选哪些标签」。
///
/// 放在领域层且是纯函数：给定同一份花园状态与时刻，结果永远一致，
/// 因此可以脱离界面与存储单独测试——这正是 PRD 7.1.3 那几条规则最容易出错、
/// 也最值得钉住的地方。
abstract final class TagCatalog {
  /// 组装当前可选的标签列表。
  ///
  /// 顺序即界面顺序：预设 → 已解锁的进化款 → 已解锁的隐藏款 → 用户自定义。
  static List<SelectableTag> available({
    required GardenState garden,
    List<MoodTag> customTags = const <MoodTag>[],
    DateTime? now,
  }) {
    final moment = now ?? DateTime.now();

    return <SelectableTag>[
      for (final tag in MoodTag.presets) _forTag(tag, moment),
      for (final tag in _evolvedTags(garden)) _forTag(tag, moment, evolved: true),
      for (final tag in _hiddenTags(garden)) _forTag(tag, moment, hidden: true),
      for (final tag in customTags) _forTag(tag, moment),
    ];
  }

  /// 某个花种此刻是否可种（季节限定校验）。
  static bool isPlantable(String speciesId, DateTime now) {
    final species = FlowerSpecies.byId(speciesId);
    // 目录里没有的花种（例如旧数据里的自定义花种）不拦，按可种处理。
    return species == null || species.isPlantableInMonth(now.month);
  }

  /// 不可种时的提示文案。可种返回 `null`。
  static String? unavailableReason(String speciesId, DateTime now) {
    if (isPlantable(speciesId, now)) {
      return null;
    }
    final species = FlowerSpecies.byId(speciesId);
    if (species == null || species.seasonMonths.isEmpty) {
      return null;
    }
    return '${species.seasonMonths.join('-')} 月可种';
  }

  // ---------------------------------------------------------------------------
  // 内部
  // ---------------------------------------------------------------------------

  static SelectableTag _forTag(
    MoodTag tag,
    DateTime now, {
    bool evolved = false,
    bool hidden = false,
  }) {
    return SelectableTag(
      tag: tag,
      isEvolved: evolved,
      isHidden: hidden,
      unavailableReason: unavailableReason(tag.speciesId, now),
    );
  }

  /// 已达阈值、因而解锁的进化花种，转成可选的标签。
  ///
  /// 进化款不是新标签，而是同一个心情的另一种开法，所以 id 用
  /// `<原标签>__evolved`，标签名保持原样、不额外加后缀——
  /// 界面上靠徽章而不是靠名字来区分（PRD 11.3：弱化工具感）。
  static Iterable<MoodTag> _evolvedTags(GardenState garden) sync* {
    for (final tag in MoodTag.presets) {
      for (final species in FlowerSpecies.evolvedFrom(tag.speciesId)) {
        if (!garden.isSpeciesUnlocked(species.id)) {
          continue;
        }
        yield MoodTag(
          id: '${tag.id}$evolvedSuffix',
          label: tag.label,
          emoji: species.emoji,
          speciesId: species.id,
        );
      }
    }
  }

  /// 连续记录达标后解锁的隐藏款。
  static Iterable<MoodTag> _hiddenTags(GardenState garden) sync* {
    if (!garden.hiddenSpeciesUnlocked) {
      return;
    }
    for (final species in FlowerSpecies.byRarity(SpeciesRarity.hidden)) {
      yield MoodTag(
        id: '${MoodTagId.hiddenPrefix}_${species.id}',
        label: species.name,
        emoji: species.emoji,
        speciesId: species.id,
      );
    }
  }

  /// 进化款标签 id 的后缀。
  static const String evolvedSuffix = '__evolved';

  /// 判断某个标签 id 是否为进化款。
  static bool isEvolvedTagId(String id) => id.endsWith(evolvedSuffix);

  /// 取进化款对应的基础标签 id。
  static String baseTagIdOf(String evolvedId) =>
      evolvedId.substring(0, evolvedId.length - evolvedSuffix.length);

  /// 把记录里存的 tagId 解析成用于展示的标签。
  ///
  /// 需要处理四类 id：
  /// - 预设（`gratitude`）
  /// - 进化款（`gratitude__evolved`）——沿用原心情的名字与图标，只是花不同
  /// - 隐藏款（`hidden_moonflower`）——名字用花种名
  /// - 自定义（`custom_xxx`）——必须由调用方传入自定义标签表，否则无法还原
  ///
  /// 找不到时返回 `null`，由界面决定降级显示。
  static MoodTag? displayTag(
    String tagId, {
    List<MoodTag> customTags = const <MoodTag>[],
  }) {
    final preset = MoodTag.presetById(tagId);
    if (preset != null) {
      return preset;
    }

    for (final tag in customTags) {
      if (tag.id == tagId) {
        return tag;
      }
    }

    if (isEvolvedTagId(tagId)) {
      final base = MoodTag.presetById(baseTagIdOf(tagId));
      final evolved = base == null
          ? const <FlowerSpecies>[]
          : FlowerSpecies.evolvedFrom(base.speciesId);
      if (base != null && evolved.isNotEmpty) {
        return MoodTag(
          id: tagId,
          label: base.label,
          emoji: evolved.first.emoji,
          speciesId: evolved.first.id,
        );
      }
      return base;
    }

    if (tagId.startsWith('${MoodTagId.hiddenPrefix}_')) {
      final speciesId = tagId.substring(MoodTagId.hiddenPrefix.length + 1);
      final species = FlowerSpecies.byId(speciesId);
      if (species != null) {
        return MoodTag(
          id: tagId,
          label: species.name,
          emoji: species.emoji,
          speciesId: species.id,
        );
      }
    }

    return null;
  }

  /// 连续记录还差几天解锁隐藏款（用于提示文案）。
  static int daysToHidden(GardenState garden) => garden.daysToHiddenSpecies;

  /// 某个基础花种还差几条记录解锁进化款。
  static int recordsToEvolution(GardenState garden, String baseSpeciesId) {
    final current = garden.petalsOfSpecies(baseSpeciesId);
    final remaining = AppConstants.evolutionUnlockCount - current;
    return remaining <= 0 ? 0 : remaining;
  }
}
