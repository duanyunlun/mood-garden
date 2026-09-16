import 'package:flutter_test/flutter_test.dart';
import 'package:mood_garden/domain/entities/mood_entry.dart';

/// 情绪记录模型测试。
///
/// 重点验证 PRD 7.2.3 的隐私承诺在**模型层**被强制执行：
/// > 原始记录内容不可再次查看、不可恢复。
///
/// 这条承诺不能只靠 UI 不提供入口来实现——那样数据仍在存储里。
/// 因此这里断言的是「数据本身已被擦除」。
void main() {
  final createdAt = DateTime(2026, 3, 16, 21, 4);

  group('UnhappyEntry 燃烧与隐私保护（PRD 7.2.3）', () {
    test('未燃烧的纸卷内容可读', () {
      final entry = UnhappyEntry(
        id: 'u1',
        occurredAt: createdAt,
        createdAt: createdAt,
        text: '今天有件不开心的事',
        imagePaths: const <String>['/tmp/a.jpg'],
      );

      expect(entry.isBurned, isFalse);
      expect(entry.hasReadableContent, isTrue);
      expect(entry.text, '今天有件不开心的事');
    });

    test('燃烧后原文与图片引用被物理清空，且不可恢复', () {
      final entry = UnhappyEntry(
        id: 'u1',
        occurredAt: createdAt,
        createdAt: createdAt,
        text: '今天有件不开心的事',
        imagePaths: const <String>['/tmp/a.jpg', '/tmp/b.jpg'],
      );

      final burnedAt = DateTime(2026, 3, 16, 22, 0);
      final burned = entry.burn(burnedAt);

      expect(burned.isBurned, isTrue);
      expect(burned.hasReadableContent, isFalse);
      expect(burned.text, isEmpty, reason: '原文必须被清空');
      expect(burned.imagePaths, isEmpty, reason: '图片引用必须被清空');
      expect(burned.burnedAt, burnedAt);
      // 元信息保留，用于时光轴展示封条
      expect(burned.id, entry.id);
      expect(burned.occurredAt, entry.occurredAt);
    });

    test('燃烧不会修改原实例（burn 返回新对象）', () {
      final entry = UnhappyEntry(
        id: 'u1',
        occurredAt: createdAt,
        createdAt: createdAt,
        text: '原文',
      );

      entry.burn(DateTime(2026, 3, 16, 22));

      expect(entry.isBurned, isFalse);
      expect(entry.text, '原文');
    });

    test('已燃烧的纸卷不可再编辑', () {
      final burned = UnhappyEntry(
        id: 'u1',
        occurredAt: createdAt,
        createdAt: createdAt,
        burnedAt: DateTime(2026, 3, 16, 22),
      );

      expect(
        () => burned.editContent(text: '想改回来'),
        throwsA(isA<StateError>()),
        reason: '模型层必须杜绝「烧掉之后又被改回来」',
      );
    });

    test('未燃烧的纸卷可以反复编辑（PRD 7.2.2 松手后继续编辑）', () {
      final entry = UnhappyEntry(
        id: 'u1',
        occurredAt: createdAt,
        createdAt: createdAt,
        text: '第一版',
      );

      final edited = entry.editContent(text: '第二版');
      expect(edited.text, '第二版');
      expect(edited.isBurned, isFalse);
    });
  });

  group('HappyEntry', () {
    test('开心事记录始终可读', () {
      final entry = HappyEntry(
        id: 'h1',
        occurredAt: createdAt,
        createdAt: createdAt,
        tagId: 'gratitude',
        text: '同事帮我带了咖啡',
      );

      expect(entry.hasReadableContent, isTrue);
      expect(entry.tagId, 'gratitude');
    });
  });

  group('记录时间语义（PRD 7.1.1 步骤 4：支持补记）', () {
    test('occurredDay 抹去时分秒', () {
      final entry = HappyEntry(
        id: 'h1',
        occurredAt: DateTime(2026, 3, 16, 23, 59, 59),
        createdAt: createdAt,
        tagId: 'calm',
      );

      expect(entry.occurredDay, DateTime(2026, 3, 16));
    });

    test('归属日早于创建日时识别为补记', () {
      final backfilled = HappyEntry(
        id: 'h1',
        occurredAt: DateTime(2026, 3, 10, 20),
        createdAt: DateTime(2026, 3, 16, 21),
        tagId: 'calm',
      );

      expect(backfilled.isBackfilled, isTrue);
    });

    test('同日记录不算补记', () {
      final sameDay = HappyEntry(
        id: 'h1',
        occurredAt: DateTime(2026, 3, 16, 8),
        createdAt: DateTime(2026, 3, 16, 21),
        tagId: 'calm',
      );

      expect(sameDay.isBackfilled, isFalse);
    });
  });
}
