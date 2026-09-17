import '../entities/app_settings.dart';

/// 应用设置的仓库契约。
///
/// 与 [EntryRepository]、[GardenRepository] 平级：设置同样是用户数据，
/// 同样要加密落盘，只是变更频率低、体积小。
abstract interface class SettingsRepository {
  /// 读取设置。从未保存过时返回 [AppSettings.defaults]。
  Future<AppSettings> load();

  /// 覆盖保存。
  Future<void> save(AppSettings settings);

  /// 清空设置，回到默认值。用于「清除全部数据」。
  Future<void> clear();
}
