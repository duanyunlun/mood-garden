/// 花种稀有度（PRD 7.1.3 进阶收集玩法）。
enum SpeciesRarity {
  /// 常规花种，首次记录即可获得。
  common(label: '常见'),

  /// 稀有花种，同类标签累积到阈值后解锁的「进化花种」。
  rare(label: '稀有'),

  /// 隐藏款，连续记录天数达标后解锁（PRD 7.1.3，阈值见 AppConstants）。
  hidden(label: '隐藏款'),

  /// 季节限定，仅在特定月份可种（如樱花仅 3-4 月）。
  seasonal(label: '季节限定');

  const SpeciesRarity({required this.label});

  final String label;
}

/// 花种。
///
/// 对应 PRD 7.1.1 步骤 3 的「标签与花种一一对应」，
/// 以及 Tab3「花之图鉴」的收集维度。
class FlowerSpecies {
  const FlowerSpecies({
    required this.id,
    required this.name,
    required this.emoji,
    required this.rarity,
    required this.blossomColor,
    this.evolvedFromId,
    this.seasonMonths = const <int>[],
    this.description = '',
  });

  /// 花种唯一标识。
  final String id;

  /// 花种中文名。
  final String name;

  /// 示意图标。骨架期用 emoji 占位，正式版替换为手绘插画资源（PRD 11.3）。
  final String emoji;

  /// 稀有度。
  final SpeciesRarity rarity;

  /// 花色描述。用于图鉴展示与花园渲染的配色提示。
  final String blossomColor;

  /// 由哪个花种进化而来（PRD 7.1.3「进化花种」）。为 `null` 表示基础花种。
  final String? evolvedFromId;

  /// 可种植的月份区间（含边界）。空列表表示不受季节限制。
  final List<int> seasonMonths;

  /// 图鉴中的花种描述文案。
  final String description;

  /// 是否为季节限定花种。
  bool get isSeasonal => seasonMonths.isNotEmpty;

  /// 判断给定月份是否处于该花种的种植季。
  bool isPlantableInMonth(int month) {
    if (seasonMonths.isEmpty) {
      return true;
    }
    return seasonMonths.contains(month);
  }

  /// 是否为进化花种。
  bool get isEvolved => evolvedFromId != null;

  // ---------------------------------------------------------------------------
  // 内置花种目录
  // ---------------------------------------------------------------------------

  /// 向日葵 —— 对应「感恩」标签（PRD 7.1.1 示例）。
  static const FlowerSpecies sunflower = FlowerSpecies(
    id: FlowerSpeciesId.sunflower,
    name: '向日葵',
    emoji: '🌻',
    rarity: SpeciesRarity.common,
    blossomColor: '暖橘黄',
    description: '总是朝着光的方向。感恩的心意攒够了，它就开花了。',
  );

  /// 郁金香 —— 对应「惊喜」标签。
  static const FlowerSpecies tulip = FlowerSpecies(
    id: FlowerSpeciesId.tulip,
    name: '郁金香',
    emoji: '🌷',
    rarity: SpeciesRarity.common,
    blossomColor: '柔粉',
    description: '开得毫无预兆，像生活里突然冒出来的小惊喜。',
  );

  /// 薰衣草 —— 对应「陪伴」标签。
  static const FlowerSpecies lavender = FlowerSpecies(
    id: FlowerSpeciesId.lavender,
    name: '薰衣草',
    emoji: '💜',
    rarity: SpeciesRarity.common,
    blossomColor: '雾紫',
    description: '安静地开成一片，是长久陪伴才有的样子。',
  );

  /// 成就麦穗 —— 对应「成就」标签。
  static const FlowerSpecies wheat = FlowerSpecies(
    id: FlowerSpeciesId.wheat,
    name: '成就麦穗',
    emoji: '🌾',
    rarity: SpeciesRarity.common,
    blossomColor: '麦金',
    description: '每一粒都记得你认真过的那些时刻。',
  );

  /// 樱花 —— 对应「美食」标签，季节限定（PRD 7.1.3）。
  static const FlowerSpecies sakura = FlowerSpecies(
    id: FlowerSpeciesId.sakura,
    name: '樱花',
    emoji: '🌸',
    rarity: SpeciesRarity.seasonal,
    blossomColor: '浅粉',
    seasonMonths: <int>[3, 4],
    description: '只在春天开放的限定款。错过就要再等一年。',
  );

  /// 四叶草 —— 对应「平静」标签。
  static const FlowerSpecies clover = FlowerSpecies(
    id: FlowerSpeciesId.clover,
    name: '四叶草',
    emoji: '🍀',
    rarity: SpeciesRarity.common,
    blossomColor: '鼠尾草绿',
    description: '安安静静的四片叶子，是心里踏实的样子。',
  );

  /// 月光花 —— 隐藏款，连续记录达标后解锁（PRD 7.1.3）。
  static const FlowerSpecies moonflower = FlowerSpecies(
    id: FlowerSpeciesId.moonflower,
    name: '月光花',
    emoji: '🌙',
    rarity: SpeciesRarity.hidden,
    blossomColor: '月白',
    description: '只在夜里开。送给坚持记录了很久的你。',
  );

  /// 金向日葵 —— 向日葵的进化形态（PRD 7.1.3「进化花种」）。
  static const FlowerSpecies goldenSunflower = FlowerSpecies(
    id: FlowerSpeciesId.goldenSunflower,
    name: '金向日葵',
    emoji: '🌟',
    rarity: SpeciesRarity.rare,
    blossomColor: '灿金',
    evolvedFromId: FlowerSpeciesId.sunflower,
    description: '攒下足够多的感恩之后，向日葵会变成金色。',
  );

  /// 全部内置花种。
  ///
  /// ⚠️ PRD 第 12 章待定项：「花种与心情标签对照表的完整细节」尚未定案，
  /// 此处为基于 PRD 示例的骨架期清单，需产品补充完整清单、花色与稀有度分级标准。
  static const List<FlowerSpecies> catalog = <FlowerSpecies>[
    sunflower,
    tulip,
    lavender,
    wheat,
    sakura,
    clover,
    moonflower,
    goldenSunflower,
  ];

  /// 按 id 查找花种。未找到返回 `null`。
  static FlowerSpecies? byId(String id) {
    for (final species in catalog) {
      if (species.id == id) {
        return species;
      }
    }
    return null;
  }

  /// 按稀有度筛选花种，供图鉴分区展示（PRD Tab3）。
  static List<FlowerSpecies> byRarity(SpeciesRarity rarity) =>
      catalog.where((s) => s.rarity == rarity).toList(growable: false);

  /// 某个基础花种对应的进化形态。没有进化款时返回空列表。
  static List<FlowerSpecies> evolvedFrom(String baseSpeciesId) => catalog
      .where((s) => s.evolvedFromId == baseSpeciesId)
      .toList(growable: false);

  @override
  String toString() => 'FlowerSpecies($id, $name)';
}

/// 花种 id 常量表。避免在业务代码中散落魔法字符串。
abstract final class FlowerSpeciesId {
  static const String sunflower = 'sunflower';
  static const String tulip = 'tulip';
  static const String lavender = 'lavender';
  static const String wheat = 'wheat';
  static const String sakura = 'sakura';
  static const String clover = 'clover';
  static const String moonflower = 'moonflower';
  static const String goldenSunflower = 'golden_sunflower';
}
