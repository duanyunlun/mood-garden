import 'package:flutter_test/flutter_test.dart';
import 'package:mood_garden/domain/entities/entry_filter.dart';
import 'package:mood_garden/domain/entities/mood_entry.dart';
import 'package:mood_garden/domain/entities/mood_tag.dart';
import 'package:mood_garden/domain/entities/tag_catalog.dart';

/// PRD Tab2 P2「按心情标签筛选历史记录」的规则测试。
void main() {
  final now = DateTime(2026, 5, 1, 20);

  HappyEntry happy({
    required String id,
    required String tagId,
    String text = '',
  }) =>
      HappyEntry(
        id: id,
        occurredAt: now,
        createdAt: now,
        tagId: tagId,
        text: text,
      );

  UnhappyEntry scroll({required String id, String text = '', bool burned = false}) =>
      UnhappyEntry(
        id: id,
        occurredAt: now,
        createdAt: now,
        text: burned ? '' : text,
        burnedAt: burned ? now : null,
      );

  group('空筛选', () {
    test('isEmpty / isActive 语义正确', () {
      expect(EntryFilter.none.isEmpty, isTrue);
      expect(EntryFilter.none.isActive, isFalse);
      expect(const EntryFilter(keyword: '  ').isEmpty, isTrue,
          reason: '只有空白的关键词等于没筛');
    });

    test('空筛选命中一切，包括烧掉的纸卷', () {
      expect(EntryFilter.none.matches(happy(id: 'a', tagId: MoodTagId.calm)), isTrue);
      expect(EntryFilter.none.matches(scroll(id: 'b', burned: true)), isTrue);
    });
  });

  group('按标签筛选', () {
    test('命中选中的标签，其他标签落选', () {
      const filter = EntryFilter(tagIds: <String>{MoodTagId.gratitude});

      expect(filter.matches(happy(id: 'a', tagId: MoodTagId.gratitude)), isTrue);
      expect(filter.matches(happy(id: 'b', tagId: MoodTagId.calm)), isFalse);
    });

    test('进化款算在它的基础标签名下', () {
      const filter = EntryFilter(tagIds: <String>{MoodTagId.gratitude});
      const evolvedId = '${MoodTagId.gratitude}${TagCatalog.evolvedSuffix}';

      expect(
        filter.matches(happy(id: 'a', tagId: evolvedId)),
        isTrue,
        reason: '用户心里「感恩」就是同一件事，开了进化形态不该搜不到',
      );
    });

    test('纸卷没有心情标签，按标签筛时一律不出现', () {
      const filter = EntryFilter(tagIds: <String>{MoodTagId.calm});

      expect(filter.matches(scroll(id: 'a', text: '难过')), isFalse);
      expect(filter.matches(scroll(id: 'b', burned: true)), isFalse);
    });

    test('toggleTag 可选中也可取消', () {
      var filter = EntryFilter.none;
      filter = filter.toggleTag(MoodTagId.calm);
      expect(filter.tagIds, <String>{MoodTagId.calm});

      filter = filter.toggleTag(MoodTagId.calm);
      expect(filter.tagIds, isEmpty);
    });
  });

  group('按关键词搜索', () {
    test('命中正文，且不区分大小写', () {
      const filter = EntryFilter(keyword: 'Coffee');

      expect(
        filter.matches(happy(id: 'a', tagId: MoodTagId.calm, text: '喝到一杯 coffee')),
        isTrue,
      );
      expect(
        filter.matches(happy(id: 'b', tagId: MoodTagId.calm, text: '喝了杯茶')),
        isFalse,
      );
    });

    test('搜不到已燃烧纸卷的原文', () {
      const filter = EntryFilter(keyword: '难过');

      expect(filter.matches(scroll(id: 'a', text: '今天很难过')), isTrue);
      expect(
        filter.matches(scroll(id: 'b', text: '今天很难过', burned: true)),
        isFalse,
        reason: '原文已被物理擦除，搜不到才是对的——这是 PRD 7.2.3 在搜索上的体现',
      );
    });

    test('没有正文的记录不会命中非空关键词', () {
      const filter = EntryFilter(keyword: '什么');

      expect(filter.matches(happy(id: 'a', tagId: MoodTagId.calm)), isFalse);
    });
  });

  group('标签与关键词同时生效', () {
    test('两者都要满足', () {
      const filter = EntryFilter(
        tagIds: <String>{MoodTagId.gratitude},
        keyword: '猫',
      );

      expect(
        filter.matches(
          happy(id: 'a', tagId: MoodTagId.gratitude, text: '遇到一只猫'),
        ),
        isTrue,
      );
      // 标签对但关键词不对
      expect(
        filter.matches(happy(id: 'b', tagId: MoodTagId.gratitude, text: '吃面')),
        isFalse,
      );
      // 关键词对但标签不对
      expect(
        filter.matches(happy(id: 'c', tagId: MoodTagId.calm, text: '遇到一只猫')),
        isFalse,
      );
    });
  });

  group('摘要文案', () {
    test('只筛标签', () {
      const filter = EntryFilter(tagIds: <String>{MoodTagId.calm, MoodTagId.food});
      expect(filter.summary, '2 个标签');
    });

    test('只搜关键词', () {
      const filter = EntryFilter(keyword: '散步');
      expect(filter.summary, '“散步”');
    });

    test('两者都有', () {
      const filter = EntryFilter(
        tagIds: <String>{MoodTagId.calm},
        keyword: '散步',
      );
      expect(filter.summary, '1 个标签 · “散步”');
    });

    test('空筛选显示全部记录', () {
      expect(EntryFilter.none.summary, '全部记录');
    });
  });
}
