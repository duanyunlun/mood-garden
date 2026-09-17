import 'dart:convert';

import '../../domain/entities/app_settings.dart';
import '../../domain/entities/flower_species.dart';
import '../../domain/entities/mood_tag.dart';

/// [AppSettings] 的序列化编解码。
///
/// 与其它 codec 一样手写，理由见 `docs/ARCHITECTURE.md` 2.6。
abstract final class AppSettingsCodec {
  static const String _textScaleKey = 'textScale';
  static const String _customTagsKey = 'customTags';
  static const String _reminderEnabledKey = 'reminderEnabled';
  static const String _reminderHourKey = 'reminderHour';
  static const String _reminderMinuteKey = 'reminderMinute';
  static const String _soundEnabledKey = 'soundEnabled';

  static Map<String, Object?> toMap(AppSettings settings) {
    return <String, Object?>{
      _textScaleKey: settings.textScale,
      _customTagsKey: settings.customTags.map(_tagToMap).toList(growable: false),
      _reminderEnabledKey: settings.reminderEnabled,
      _reminderHourKey: settings.reminderHour,
      _reminderMinuteKey: settings.reminderMinute,
      _soundEnabledKey: settings.soundEnabled,
    };
  }

  static AppSettings fromMap(Map<String, Object?> map) {
    return AppSettings(
      textScale: _asDouble(map[_textScaleKey], AppSettings.defaults.textScale),
      customTags: _decodeTags(map[_customTagsKey]),
      reminderEnabled:
          map[_reminderEnabledKey] as bool? ??
              AppSettings.defaults.reminderEnabled,
      reminderHour: _asInt(map[_reminderHourKey], AppSettings.defaults.reminderHour),
      reminderMinute:
          _asInt(map[_reminderMinuteKey], AppSettings.defaults.reminderMinute),
      // 缺字段时默认开：老用户没关过，就不该替他关掉。
      soundEnabled:
          map[_soundEnabledKey] as bool? ?? AppSettings.defaults.soundEnabled,
    );
  }

  static Map<String, Object?> _tagToMap(MoodTag tag) => <String, Object?>{
        'id': tag.id,
        'label': tag.label,
        'emoji': tag.emoji,
        'speciesId': tag.speciesId,
      };

  /// 自定义标签的宽容解码：单条坏掉只丢那一条，不让整份设置回退默认值。
  static List<MoodTag> _decodeTags(Object? raw) {
    if (raw is! List) {
      return const <MoodTag>[];
    }

    final tags = <MoodTag>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, Object?>.from(item);
      final id = map['id'] as String?;
      final label = map['label'] as String?;
      if (id == null || label == null || label.isEmpty) {
        continue;
      }

      final speciesId = map['speciesId'] as String?;
      tags.add(
        MoodTag(
          id: id,
          label: label,
          emoji: map['emoji'] as String? ?? '🌱',
          // 花种目录里找不到就退回向日葵，保证标签始终能种出东西。
          speciesId: speciesId != null && FlowerSpecies.byId(speciesId) != null
              ? speciesId
              : FlowerSpeciesId.sunflower,
          isCustom: true,
        ),
      );
    }
    return tags;
  }

  static double _asDouble(Object? raw, double fallback) {
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw) ?? fallback;
    }
    return fallback;
  }

  static int _asInt(Object? raw, int fallback) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw) ?? fallback;
    }
    return fallback;
  }

  static String encode(AppSettings settings) => jsonEncode(toMap(settings));

  /// 从 JSON 还原。任何损坏都回退到默认设置——
  /// 宁可让用户重调一次字体大小，也不该让 App 卡在启动崩溃页。
  static AppSettings decode(String raw) {
    if (raw.trim().isEmpty) {
      return AppSettings.defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return AppSettings.defaults;
      }
      return fromMap(Map<String, Object?>.from(decoded));
    } on FormatException {
      return AppSettings.defaults;
    }
  }
}
