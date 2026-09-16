import 'dart:convert';

import '../../domain/entities/mood_entry.dart';

/// [MoodEntry] 的序列化编解码。
///
/// 手写而非依赖代码生成，避免骨架期引入 `build_runner` 带来的构建复杂度。
/// 待模型稳定后可迁移到 `json_serializable`。
///
/// 安全约束（PRD 7.2.3）：已燃烧的纸卷序列化后不得包含任何原文内容。
/// [toMap] 对 [UnhappyEntry] 的处理天然满足该约束——因为 [UnhappyEntry.burn]
/// 已经在模型层把 `text` 与 `imagePaths` 清空，此处无需也不应做特殊判断。
abstract final class MoodEntryCodec {
  static const String _typeKey = 'type';
  static const String _typeHappy = 'happy';
  static const String _typeUnhappy = 'unhappy';

  static const String _idKey = 'id';
  static const String _occurredAtKey = 'occurredAt';
  static const String _createdAtKey = 'createdAt';
  static const String _textKey = 'text';
  static const String _imagePathsKey = 'imagePaths';
  static const String _tagIdKey = 'tagId';
  static const String _burnedAtKey = 'burnedAt';

  /// 将单条记录编码为可 JSON 化的 Map。
  static Map<String, Object?> toMap(MoodEntry entry) {
    return switch (entry) {
      HappyEntry() => <String, Object?>{
          _typeKey: _typeHappy,
          _idKey: entry.id,
          _occurredAtKey: entry.occurredAt.toIso8601String(),
          _createdAtKey: entry.createdAt.toIso8601String(),
          _textKey: entry.text,
          _imagePathsKey: entry.imagePaths,
          _tagIdKey: entry.tagId,
        },
      UnhappyEntry() => <String, Object?>{
          _typeKey: _typeUnhappy,
          _idKey: entry.id,
          _occurredAtKey: entry.occurredAt.toIso8601String(),
          _createdAtKey: entry.createdAt.toIso8601String(),
          _textKey: entry.text,
          _imagePathsKey: entry.imagePaths,
          _burnedAtKey: entry.burnedAt?.toIso8601String(),
        },
    };
  }

  /// 从 Map 还原记录。
  ///
  /// 遇到未知 `type` 或必填字段缺失时抛出 [FormatException]，
  /// 由上层决定是跳过该条还是整体回滚——避免静默吞掉数据损坏。
  static MoodEntry fromMap(Map<String, Object?> map) {
    final type = map[_typeKey];
    final id = map[_idKey] as String?;
    final occurredAtRaw = map[_occurredAtKey] as String?;
    final createdAtRaw = map[_createdAtKey] as String?;

    if (id == null || occurredAtRaw == null || createdAtRaw == null) {
      throw FormatException('记录缺少必填字段: $map');
    }

    final occurredAt = DateTime.parse(occurredAtRaw);
    final createdAt = DateTime.parse(createdAtRaw);
    final text = map[_textKey] as String? ?? '';
    final imagePaths = _decodeImagePaths(map[_imagePathsKey]);

    switch (type) {
      case _typeHappy:
        final tagId = map[_tagIdKey] as String?;
        if (tagId == null) {
          throw const FormatException('开心事记录缺少 tagId 字段');
        }
        return HappyEntry(
          id: id,
          occurredAt: occurredAt,
          createdAt: createdAt,
          tagId: tagId,
          text: text,
          imagePaths: imagePaths,
        );
      case _typeUnhappy:
        final burnedAtRaw = map[_burnedAtKey] as String?;
        return UnhappyEntry(
          id: id,
          occurredAt: occurredAt,
          createdAt: createdAt,
          text: burnedAtRaw == null ? text : '',
          imagePaths: burnedAtRaw == null ? imagePaths : const <String>[],
          burnedAt: burnedAtRaw == null ? null : DateTime.parse(burnedAtRaw),
        );
      default:
        throw FormatException('未知的记录类型: $type');
    }
  }

  static List<String> _decodeImagePaths(Object? raw) {
    if (raw is List) {
      return raw.whereType<String>().toList(growable: false);
    }
    return const <String>[];
  }

  /// 将记录列表编码为 JSON 字符串。
  static String encodeList(List<MoodEntry> entries) {
    return jsonEncode(
      entries.map(toMap).toList(growable: false),
    );
  }

  /// 从 JSON 字符串还原记录列表。
  ///
  /// 两级容错：
  /// - 根级 JSON 损坏 → 返回空列表（不让用户卡在崩溃页）；
  /// - 单条记录损坏 → 跳过该条并继续，保证其余记录不因一条脏数据全部丢失。
  static List<MoodEntry> decodeList(String raw) {
    if (raw.trim().isEmpty) {
      return const <MoodEntry>[];
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const <MoodEntry>[];
    }

    if (decoded is! List) {
      return const <MoodEntry>[];
    }

    final entries = <MoodEntry>[];
    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }
      try {
        entries.add(fromMap(Map<String, Object?>.from(item)));
      } on FormatException {
        continue;
      }
    }
    return entries;
  }
}
