/// 情绪记录基类。
///
/// 两条记录路径（PRD 7.1 与 7.2）共用同一套「时间 + 文字 + 图片」输入结构，
/// 但后续命运完全不同：开心事入土生长，不开心事被烧成灰烬。
/// 因此用 `sealed class` 建模，配合 Dart 的穷尽 `switch` 保证
/// 任何新增的记录类型都能被时光轴、花园等消费方显式处理。
sealed class MoodEntry {
  const MoodEntry({
    required this.id,
    required this.occurredAt,
    required this.createdAt,
    this.text = '',
    this.imagePaths = const <String>[],
  });

  /// 记录唯一标识。
  final String id;

  /// 记录归属的时间。
  ///
  /// 依据 PRD 7.1.1 步骤 4「日期时间可编辑（支持补记过去某天的开心事）」，
  /// 该字段由用户指定，可能早于 [createdAt]。
  final DateTime occurredAt;

  /// 记录的创建时刻，由系统写入，用户不可修改。
  final DateTime createdAt;

  /// 记录的文字内容。
  final String text;

  /// 记录的图片资源引用列表（PRD 7.1.1 支持多图）。
  ///
  /// 骨架期保存本地文件路径；正式实现需指向加密存储中的资源引用。
  final List<String> imagePaths;

  /// 是否为补记（记录归属日早于创建日）。
  bool get isBackfilled {
    final occurredDay = DateTime(
      occurredAt.year,
      occurredAt.month,
      occurredAt.day,
    );
    final createdDay = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
    );
    return occurredDay.isBefore(createdDay);
  }

  /// 记录归属的日期（去掉时分秒），用于时光轴按天归组（PRD Tab2）。
  DateTime get occurredDay =>
      DateTime(occurredAt.year, occurredAt.month, occurredAt.day);

  /// 该记录是否还有可阅读的原始内容。
  ///
  /// 对已燃烧的纸卷恒为 `false`（PRD 7.2.3）。
  bool get hasReadableContent;

  @override
  String toString() => '$runtimeType($id, occurredAt: $occurredAt)';
}

/// 开心事记录（PRD 7.1）。
///
/// 保存后触发「种子落地」反馈动画，并在花园中种下对应花种的种子。
final class HappyEntry extends MoodEntry {
  const HappyEntry({
    required super.id,
    required super.occurredAt,
    required super.createdAt,
    required this.tagId,
    super.text,
    super.imagePaths,
  });

  /// 心情标签 id，决定种下哪一种花（PRD 7.1.1 步骤 3）。
  /// 见 `MoodTagId` 与 `MoodTag.presets`。
  final String tagId;

  @override
  bool get hasReadableContent => true;

  HappyEntry copyWith({
    String? id,
    DateTime? occurredAt,
    DateTime? createdAt,
    String? tagId,
    String? text,
    List<String>? imagePaths,
  }) {
    return HappyEntry(
      id: id ?? this.id,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt ?? this.createdAt,
      tagId: tagId ?? this.tagId,
      text: text ?? this.text,
      imagePaths: imagePaths ?? this.imagePaths,
    );
  }
}

/// 不开心事记录 —— 情绪纸卷（PRD 7.2）。
///
/// 生命周期：写入 → 长按点燃 → 燃烧 → 灰烬入土转化为养分。
///
/// ⚠️ 隐私机制（PRD 7.2.3）：一旦 [burnedAt] 不为 `null`，原始文字与图片
/// **必须被物理擦除且不可恢复**，时光轴中仅保留「已转化为养分」的封条提示。
/// [burn] 方法即该承诺的模型层落点——它不是「标记隐藏」，而是返回一个
/// 内容字段已被清空的新实例。
final class UnhappyEntry extends MoodEntry {
  const UnhappyEntry({
    required super.id,
    required super.occurredAt,
    required super.createdAt,
    super.text,
    super.imagePaths,
    this.burnedAt,
  });

  /// 燃烧完成时刻。`null` 表示纸卷尚未被点燃，仍是草稿态。
  final DateTime? burnedAt;

  /// 是否已被烧成灰烬。
  bool get isBurned => burnedAt != null;

  @override
  bool get hasReadableContent => !isBurned;

  /// 执行燃烧：返回一个内容已被擦除的副本（PRD 7.2.3）。
  ///
  /// 这是「原始记录内容不可再次查看、不可恢复」这条产品承诺的强制实现点。
  /// 任何持久化层在保存 [burn] 的返回值时，都不应再持有原文的引用。
  ///
  /// 返回的实例仅保留：唯一标识、归属时间、创建时间、燃烧时间。
  /// 文字与图片引用均被清空。
  UnhappyEntry burn(DateTime at) {
    return UnhappyEntry(
      id: id,
      occurredAt: occurredAt,
      createdAt: createdAt,
      text: '',
      imagePaths: const <String>[],
      burnedAt: at,
    );
  }

  /// 草稿态内容的编辑方法。已燃烧的纸卷不允许再编辑。
  ///
  /// 尝试编辑已燃烧的纸卷会抛出 [StateError]，从模型层杜绝
  /// 「烧掉之后又被改回来」这类破坏机制严谨性的操作。
  UnhappyEntry editContent({String? text, List<String>? imagePaths}) {
    if (isBurned) {
      throw StateError(
        '纸卷已于 $burnedAt 燃烧，原始内容不可恢复、不可编辑（PRD 7.2.3）',
      );
    }
    return UnhappyEntry(
      id: id,
      occurredAt: occurredAt,
      createdAt: createdAt,
      text: text ?? this.text,
      imagePaths: imagePaths ?? this.imagePaths,
    );
  }

  UnhappyEntry copyWith({
    String? id,
    DateTime? occurredAt,
    DateTime? createdAt,
    String? text,
    List<String>? imagePaths,
    DateTime? burnedAt,
  }) {
    return UnhappyEntry(
      id: id ?? this.id,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt ?? this.createdAt,
      text: text ?? this.text,
      imagePaths: imagePaths ?? this.imagePaths,
      burnedAt: burnedAt ?? this.burnedAt,
    );
  }
}
