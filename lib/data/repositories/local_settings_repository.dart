import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/local_store.dart';
import '../models/app_settings_codec.dart';

/// 基于 [LocalStore] 的设置仓库实现。
///
/// 与其它仓库同一策略：读时缓存、写时整体回写。设置体积很小，
/// 这个策略在这里没有任何压力。
class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository(this._store);

  final LocalStore _store;

  AppSettings? _cache;

  @override
  Future<AppSettings> load() async {
    final cached = _cache;
    if (cached != null) {
      return cached;
    }

    final raw = await _store.read(StoreKeys.settings);
    final loaded =
        raw == null ? AppSettings.defaults : AppSettingsCodec.decode(raw);
    _cache = loaded;
    return loaded;
  }

  @override
  Future<void> save(AppSettings settings) async {
    _cache = settings;
    await _store.write(StoreKeys.settings, AppSettingsCodec.encode(settings));
  }

  @override
  Future<void> clear() async {
    _cache = AppSettings.defaults;
    await _store.delete(StoreKeys.settings);
  }
}
