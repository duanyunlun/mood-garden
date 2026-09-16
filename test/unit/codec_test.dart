import 'package:flutter_test/flutter_test.dart';
import 'package:mood_garden/data/models/garden_state_codec.dart';
import 'package:mood_garden/data/models/mood_entry_codec.dart';
import 'package:mood_garden/domain/entities/flower.dart';
import 'package:mood_garden/domain/entities/flower_species.dart';
import 'package:mood_garden/domain/entities/garden_state.dart';
import 'package:mood_garden/domain/entities/garden_theme.dart';
import 'package:mood_garden/domain/entities/mood_entry.dart';

/// 序列化编解码测试。
///
/// 关键验证点：**已燃烧的纸卷序列化后不得含有任何原文痕迹**。
/// 隐私承诺必须在数据落盘的那一层也成立——否则「不可恢复」只是一句空话。
void main() {
  final createdAt = DateTime(2026, 3, 16, 21, 4);

  group('MoodEntryCodec', () {
    test('开心事记录往返编解码保持一致', () {
      final entry = HappyEntry(
        id: 'h1',
        occurredAt: createdAt,
        createdAt: createdAt,
        tagId: 'gratitude',
        text: '今天阳光很好',
        imagePaths: const <String>['/tmp/a.jpg'],
      );

      final decoded = MoodEntryCodec.decodeList(
        MoodEntryCodec.encodeList(<MoodEntry>[entry]),
      );

      expect(decoded, hasLength(1));
      final restored = decoded.single as HappyEntry;
      expect(restored.id, 'h1');
      expect(restored.tagId, 'gratitude');
      expect(restored.text, '今天阳光很好');
      expect(restored.imagePaths, <String>['/tmp/a.jpg']);
      expect(restored.occurredAt, createdAt);
    });

    test('未燃烧的纸卷保留原文', () {
      final entry = UnhappyEntry(
        id: 'u1',
        occurredAt: createdAt,
        createdAt: createdAt,
        text: '还没烧',
      );

      final decoded = MoodEntryCodec.decodeList(
        MoodEntryCodec.encodeList(<MoodEntry>[entry]),
      ).single as UnhappyEntry;

      expect(decoded.isBurned, isFalse);
      expect(decoded.text, '还没烧');
    });

    test('已燃烧的纸卷序列化结果不含原文（PRD 7.2.3）', () {
      const secret = '这段内容绝对不能出现在存储里';
      final entry = UnhappyEntry(
        id: 'u1',
        occurredAt: createdAt,
        createdAt: createdAt,
        text: secret,
        imagePaths: const <String>['/tmp/secret.jpg'],
      );

      final burned = entry.burn(DateTime(2026, 3, 16, 22));
      final encoded = MoodEntryCodec.encodeList(<MoodEntry>[burned]);

      expect(encoded.contains(secret), isFalse);
      expect(encoded.contains('secret.jpg'), isFalse);

      final decoded = MoodEntryCodec.decodeList(encoded).single as UnhappyEntry;
      expect(decoded.isBurned, isTrue);
      expect(decoded.text, isEmpty);
      expect(decoded.burnedAt, DateTime(2026, 3, 16, 22));
    });

    test('即使存储文件被手工篡改塞回原文，解码时也会再次擦除', () {
      // 模拟攻击者/异常程序直接改写存储内容，试图让已燃烧的记录「复活」
      const tampered = '''
[{"type":"unhappy","id":"u1","occurredAt":"2026-03-16T21:04:00.000",
"createdAt":"2026-03-16T21:04:00.000","text":"被塞回来的原文",
"imagePaths":["/tmp/x.jpg"],"burnedAt":"2026-03-16T22:00:00.000"}]
''';

      final decoded = MoodEntryCodec.decodeList(tampered).single as UnhappyEntry;

      expect(
        decoded.text,
        isEmpty,
        reason: '只要 burnedAt 存在，解码阶段就必须丢弃原文',
      );
      expect(decoded.imagePaths, isEmpty);
    });

    test('损坏的单条记录被跳过，不影响其余记录', () {
      const raw = '''
[
  {"type":"happy","id":"ok","occurredAt":"2026-03-16T21:04:00.000",
   "createdAt":"2026-03-16T21:04:00.000","tagId":"calm","text":"正常"},
  {"type":"happy","id":"broken"},
  {"type":"unknown_type","id":"x","occurredAt":"2026-03-16T21:04:00.000",
   "createdAt":"2026-03-16T21:04:00.000"}
]
''';

      final decoded = MoodEntryCodec.decodeList(raw);

      expect(decoded, hasLength(1));
      expect(decoded.single.id, 'ok');
    });

    test('空字符串解码为空列表', () {
      expect(MoodEntryCodec.decodeList(''), isEmpty);
      expect(MoodEntryCodec.decodeList('  '), isEmpty);
    });
  });

  group('GardenStateCodec', () {
    test('花园状态往返编解码保持一致', () {
      final state = GardenState(
        nutrientValue: 125,
        streakDays: 7,
        themeId: GardenThemeId.lavenderSlope,
        seedCountBySpecies: const <String, int>{
          FlowerSpeciesId.sunflower: 7,
          FlowerSpeciesId.tulip: 2,
        },
        flowers: <Flower>[
          Flower(
            id: 'f1',
            speciesId: FlowerSpeciesId.sunflower,
            plantedAt: DateTime(2026, 3, 1),
            nutrientBoost: 30,
          ),
          Flower(
            id: 'f2',
            speciesId: FlowerSpeciesId.sakura,
            plantedAt: DateTime(2026, 3, 5),
          ),
        ],
        lastRecordedDay: DateTime(2026, 3, 16),
      );

      final restored = GardenStateCodec.decode(GardenStateCodec.encode(state));

      expect(restored.nutrientValue, 125);
      expect(restored.streakDays, 7);
      expect(restored.themeId, GardenThemeId.lavenderSlope);
      expect(restored.seedCountBySpecies[FlowerSpeciesId.sunflower], 7);
      expect(restored.flowers, hasLength(2));
      expect(restored.flowers.first.plantedAt, DateTime(2026, 3, 1));
      expect(restored.flowers.first.nutrientBoost, 30);
      expect(restored.lastRecordedDay, DateTime(2026, 3, 16));
    });

    test('空花园往返保持一致', () {
      final restored = GardenStateCodec.decode(
        GardenStateCodec.encode(GardenState.empty),
      );

      expect(restored.nutrientValue, 0);
      expect(restored.flowers, isEmpty);
      expect(restored.themeId, GardenThemeId.sunflowerField);
    });

    test('损坏的花园数据回退到空花园而非崩溃', () {
      expect(GardenStateCodec.decode('').nutrientValue, 0);
      expect(GardenStateCodec.decode('not json at all').flowers, isEmpty);
      expect(GardenStateCodec.decode('{"nutrientValue": "abc"}').nutrientValue, 0);
    });

    test('花朵列表中损坏的条目被跳过', () {
      const raw = '''
{"nutrientValue": 10, "streakDays": 1, "themeId": "sunflower_field",
 "flowers": [
   {"id":"ok","speciesId":"sunflower","plantedAt":"2026-03-01T00:00:00.000"},
   {"id":"broken"},
   {"speciesId":"tulip","plantedAt":"2026-03-01T00:00:00.000"}
 ],
 "seedCountBySpecies": {}}
''';

      final restored = GardenStateCodec.decode(raw);
      expect(restored.flowers, hasLength(1));
      expect(restored.flowers.single.id, 'ok');
    });
  });
}
