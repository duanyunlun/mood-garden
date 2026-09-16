import '../entities/mood_entry.dart';

/// 情绪记录仓库接口（领域层契约）。
///
/// 领域层只依赖该抽象，不关心底层是内存、SQLite 还是加密文件——
/// 这保证后续接入真实加密存储（PRD 第 10 章）时，业务代码零改动。
abstract interface class EntryRepository {
  /// 读取全部记录，按 [MoodEntry.occurredAt] 倒序返回。
  Future<List<MoodEntry>> loadAll();

  /// 读取指定日期（按 [MoodEntry.occurredDay] 匹配）的全部记录。
  ///
  /// 供时光轴日期详情页使用（PRD Tab2）。
  Future<List<MoodEntry>> loadByDay(DateTime day);

  /// 读取指定日期区间内的记录。
  ///
  /// 供时光轴的周 / 月 / 年视图聚合使用（PRD Tab2）。
  Future<List<MoodEntry>> loadBetween(DateTime start, DateTime end);

  /// 新增或覆盖一条记录（按 id 去重）。
  Future<void> save(MoodEntry entry);

  /// 批量覆盖写入。
  Future<void> saveAll(List<MoodEntry> entries);

  /// 按 id 删除记录。
  Future<void> remove(String id);

  /// 清空全部记录。用于「隐私与数据设置」中的数据清除入口（PRD Tab4）。
  Future<void> clear();
}
