import 'mood_entry.dart';
import 'tag_catalog.dart';

/// 历史记录的筛选条件（PRD Tab2 P2：按心情标签筛选历史记录）。
///
/// 只做两件事：按心情标签筛、按关键词搜。刻意不做复杂查询语言——
/// 这是日记，不是数据库客户端。
class EntryFilter {
  const EntryFilter({
    this.tagIds = const <String>{},
    this.keyword = '',
  });

  /// 空筛选：什么都不筛。
  static const EntryFilter none = EntryFilter();

  /// 选中的心情标签 id。空集合表示不限。
  final Set<String> tagIds;

  /// 关键词。空串表示不限。
  final String keyword;

  /// 是否等价于「不筛选」。
  bool get isEmpty => tagIds.isEmpty && keyword.trim().isEmpty;

  /// 是否处于筛选状态（供界面显示「筛选中」）。
  bool get isActive => !isEmpty;

  /// 用于展示的简短描述，例如「2 个标签 · “散步”」。
  String get summary {
    if (isEmpty) {
      return '全部记录';
    }
    final parts = <String>[];
    if (tagIds.isNotEmpty) {
      parts.add('${tagIds.length} 个标签');
    }
    if (keyword.trim().isNotEmpty) {
      parts.add('“${keyword.trim()}”');
    }
    return parts.join(' · ');
  }

  EntryFilter copyWith({
    Set<String>? tagIds,
    String? keyword,
  }) {
    return EntryFilter(
      tagIds: tagIds ?? this.tagIds,
      keyword: keyword ?? this.keyword,
    );
  }

  /// 切换某个标签的选中状态。
  EntryFilter toggleTag(String tagId) {
    final next = Set<String>.of(tagIds);
    if (!next.remove(tagId)) {
      next.add(tagId);
    }
    return copyWith(tagIds: next);
  }

  /// 一条记录是否命中。
  ///
  /// 纸卷的处境需要说明：它没有心情标签，烧掉之后连正文也没有。
  /// 因此
  /// - 按标签筛时，纸卷一律不命中（它本来就没有标签，硬塞一个进去是错的）；
  /// - 按关键词搜时，只有还没烧的草稿可能命中（原文已被物理擦除的，
  ///   搜不到才是对的——这是 PRD 7.2.3 的承诺在搜索上的体现）。
  bool matches(MoodEntry entry) {
    if (isEmpty) {
      return true;
    }

    switch (entry) {
      case HappyEntry():
        if (tagIds.isNotEmpty &&
            !_tagMatches(entry.tagId)) {
          return false;
        }
        return _keywordMatches(entry.text);

      case UnhappyEntry():
        if (tagIds.isNotEmpty) {
          return false;
        }
        return _keywordMatches(entry.text);
    }
  }

  /// 标签匹配。进化款（`xxx__evolved`）算在它的基础标签名下——
  /// 用户心里那是同一件事，不该因为开了进化形态就搜不到。
  bool _tagMatches(String entryTagId) {
    if (tagIds.contains(entryTagId)) {
      return true;
    }
    return TagCatalog.isEvolvedTagId(entryTagId) &&
        tagIds.contains(TagCatalog.baseTagIdOf(entryTagId));
  }

  bool _keywordMatches(String text) {
    final needle = keyword.trim();
    if (needle.isEmpty) {
      return true;
    }
    if (text.isEmpty) {
      return false;
    }
    return text.toLowerCase().contains(needle.toLowerCase());
  }

  @override
  String toString() => 'EntryFilter(tags: $tagIds, keyword: "$keyword")';
}
