import '../../domain/entities/garden_state.dart';
import '../../domain/repositories/garden_repository.dart';
import '../datasources/local_store.dart';
import '../models/garden_state_codec.dart';

/// 基于 [LocalStore] 的花园状态仓库实现。
class LocalGardenRepository implements GardenRepository {
  LocalGardenRepository(this._store);

  final LocalStore _store;

  GardenState? _cache;

  @override
  Future<GardenState> load() async {
    final cached = _cache;
    if (cached != null) {
      return cached;
    }
    final raw = await _store.read(StoreKeys.gardenState);
    final loaded = raw == null ? GardenState.empty : GardenStateCodec.decode(raw);
    _cache = loaded;
    return loaded;
  }

  @override
  Future<void> save(GardenState state) async {
    _cache = state;
    await _store.write(StoreKeys.gardenState, GardenStateCodec.encode(state));
  }

  @override
  Future<void> clear() async {
    _cache = GardenState.empty;
    await _store.delete(StoreKeys.gardenState);
  }
}
