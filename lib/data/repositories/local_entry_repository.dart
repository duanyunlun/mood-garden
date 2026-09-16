import '../../domain/entities/mood_entry.dart';
import '../../domain/repositories/entry_repository.dart';
import '../datasources/local_store.dart';
import '../models/mood_entry_codec.dart';

/// 基于 [LocalStore] 的记录仓库实现。
///
/// 采用「读时缓存 + 写时整体回写」策略：骨架期的记录量级（个人日记）下，
/// 全量读写完全够用，且实现简单、不易出错。数据量增长后可平滑替换为
/// 增量持久化实现，领域层接口不变。
class LocalEntryRepository implements EntryRepository {
  LocalEntryRepository(this._store);

  final LocalStore _store;

  /// 进程内缓存。`null` 表示尚未从存储加载过。
  List<MoodEntry>? _cache;

  Future<List<MoodEntry>> _ensureLoaded() async {
    final cached = _cache;
    if (cached != null) {
      return cached;
    }
    final raw = await _store.read(StoreKeys.entries);
    final loaded = raw == null ? <MoodEntry>[] : MoodEntryCodec.decodeList(raw);
    _cache = loaded;
    return loaded;
  }

  Future<void> _flush(List<MoodEntry> entries) async {
    _cache = entries;
    await _store.write(StoreKeys.entries, MoodEntryCodec.encodeList(entries));
  }

  @override
  Future<List<MoodEntry>> loadAll() async {
    final entries = await _ensureLoaded();
    final sorted = List<MoodEntry>.of(entries)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return sorted;
  }

  @override
  Future<List<MoodEntry>> loadByDay(DateTime day) async {
    final entries = await _ensureLoaded();
    final target = DateTime(day.year, day.month, day.day);
    return entries
        .where((e) => e.occurredDay == target)
        .toList(growable: false)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  @override
  Future<List<MoodEntry>> loadBetween(DateTime start, DateTime end) async {
    final entries = await _ensureLoaded();
    return entries
        .where(
          (e) =>
              !e.occurredAt.isBefore(start) && !e.occurredAt.isAfter(end),
        )
        .toList(growable: false)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  @override
  Future<void> save(MoodEntry entry) async {
    final entries = List<MoodEntry>.of(await _ensureLoaded());
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      entries[index] = entry;
    } else {
      entries.add(entry);
    }
    await _flush(entries);
  }

  @override
  Future<void> saveAll(List<MoodEntry> entries) async {
    final existing = List<MoodEntry>.of(await _ensureLoaded());
    for (final entry in entries) {
      final index = existing.indexWhere((e) => e.id == entry.id);
      if (index >= 0) {
        existing[index] = entry;
      } else {
        existing.add(entry);
      }
    }
    await _flush(existing);
  }

  @override
  Future<void> remove(String id) async {
    final entries = List<MoodEntry>.of(await _ensureLoaded())
      ..removeWhere((e) => e.id == id);
    await _flush(entries);
  }

  @override
  Future<void> clear() async {
    _cache = <MoodEntry>[];
    await _store.delete(StoreKeys.entries);
  }
}
