import 'dart:convert';

import '../../domain/entities/flower.dart';
import '../../domain/entities/garden_state.dart';

/// [GardenState] 的序列化编解码。
abstract final class GardenStateCodec {
  static const String _nutrientKey = 'nutrientValue';
  static const String _streakKey = 'streakDays';
  static const String _flowersKey = 'flowers';
  static const String _petalStockKey = 'petalStockBySpecies';
  static const String _petalDayKey = 'petalProgressDay';
  static const String _thingsKey = 'thingsTowardPetal';
  static const String _tagCountsKey = 'tagCountsForDay';
  static const String _unlockedSpeciesKey = 'unlockedSpeciesIds';
  static const String _themeKey = 'themeId';
  static const String _lastRecordedKey = 'lastRecordedDay';

  static Map<String, Object?> toMap(GardenState state) {
    return <String, Object?>{
      _nutrientKey: state.nutrientValue,
      _streakKey: state.streakDays,
      _flowersKey: state.flowers.map(_flowerToMap).toList(growable: false),
      _petalStockKey: state.petalStockBySpecies,
      _petalDayKey: state.petalProgressDay?.toIso8601String(),
      _thingsKey: state.thingsTowardPetal,
      _tagCountsKey: state.tagCountsForDay,
      _unlockedSpeciesKey: state.unlockedSpeciesIds.toList(growable: false),
      _themeKey: state.themeId,
      _lastRecordedKey: state.lastRecordedDay?.toIso8601String(),
    };
  }

  static GardenState fromMap(Map<String, Object?> map) {
    return GardenState(
      nutrientValue: _asInt(map[_nutrientKey]),
      streakDays: _asInt(map[_streakKey]),
      flowers: _decodeFlowers(map[_flowersKey]),
      petalStockBySpecies: _decodeSeedCounts(map[_petalStockKey]),
      petalProgressDay: _decodeDay(map[_petalDayKey]),
      thingsTowardPetal: _asInt(map[_thingsKey]),
      tagCountsForDay: _decodeSeedCounts(map[_tagCountsKey]),
      unlockedSpeciesIds: _decodeUnlockedSpecies(map[_unlockedSpeciesKey]),
      themeId: map[_themeKey] as String? ?? GardenState.empty.themeId,
      lastRecordedDay: _decodeDay(map[_lastRecordedKey]),
    );
  }

  /// 已解锁花种。旧数据里没有这个字段，解码为空集合即可——
  /// 解锁是向前累积的，缺字段只会让老用户少几个已解锁项，
  /// 而它们会在下一次达到阈值时重新解锁。
  static Set<String> _decodeUnlockedSpecies(Object? raw) {
    if (raw is! List) {
      return const <String>{};
    }
    return raw.whereType<String>().toSet();
  }

  static Map<String, Object?> _flowerToMap(Flower flower) {
    return <String, Object?>{
      'id': flower.id,
      'speciesId': flower.speciesId,
      'plantedAt': flower.plantedAt.toIso8601String(),
      'nutrientBoost': flower.nutrientBoost,
    };
  }

  static List<Flower> _decodeFlowers(Object? raw) {
    if (raw is! List) {
      return const <Flower>[];
    }
    final flowers = <Flower>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, Object?>.from(item);
      final id = map['id'] as String?;
      final speciesId = map['speciesId'] as String?;
      final plantedAtRaw = map['plantedAt'] as String?;
      if (id == null || speciesId == null || plantedAtRaw == null) {
        continue;
      }
      flowers.add(
        Flower(
          id: id,
          speciesId: speciesId,
          plantedAt: DateTime.parse(plantedAtRaw),
          nutrientBoost: _asInt(map['nutrientBoost']),
        ),
      );
    }
    return flowers;
  }

  static Map<String, int> _decodeSeedCounts(Object? raw) {
    if (raw is! Map) {
      return const <String, int>{};
    }
    final counts = <String, int>{};
    raw.forEach((key, value) {
      if (key is String) {
        counts[key] = _asInt(value);
      }
    });
    return counts;
  }

  static DateTime? _decodeDay(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  static int _asInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw) ?? 0;
    }
    return 0;
  }

  /// 编码为 JSON 字符串。
  static String encode(GardenState state) => jsonEncode(toMap(state));

  /// 从 JSON 字符串还原。
  ///
  /// 任何损坏情况（非法 JSON、根节点类型不对、字段缺失）都回退到空花园，
  /// 而不是抛异常——情绪日记类 App 宁可丢失一份花园统计，
  /// 也不该让用户卡在启动崩溃页（PRD 第 10 章「稳定性」）。
  static GardenState decode(String raw) {
    if (raw.trim().isEmpty) {
      return GardenState.empty;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return GardenState.empty;
      }
      return fromMap(Map<String, Object?>.from(decoded));
    } on FormatException {
      return GardenState.empty;
    }
  }
}
