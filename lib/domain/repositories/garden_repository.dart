import '../entities/garden_state.dart';

/// 花园状态仓库接口（领域层契约）。
abstract interface class GardenRepository {
  /// 读取花园聚合状态。首次使用返回 [GardenState.empty]。
  Future<GardenState> load();

  /// 持久化花园状态。
  Future<void> save(GardenState state);

  /// 清空花园。用于「隐私与数据设置」中的数据清除入口（PRD Tab4）。
  Future<void> clear();
}
