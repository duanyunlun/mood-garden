/// 本地持久化抽象。
///
/// 对齐 PRD 第 10 章「数据安全与隐私」：
/// > 情绪记录文字、图片等属于用户敏感数据，需考虑本地存储加密方案，
/// > 云同步功能需明确用户授权机制与隐私保护措施。
///
/// 因此这里刻意把「存储」与「加密」拆成两层：
/// - [LocalStore] 只负责键值存取，不关心内容形态；
/// - `Cipher` 负责加解密，由实现方注入。
///
/// 骨架期使用 [InMemoryLocalStore]（进程内、不落盘），
/// 正式实现应替换为 SQLCipher / 系统安全区托管的加密存储，
/// 且密钥需交由 iOS Keychain 托管（见 `AppConstants.encryptionKeyAlias`）。
abstract interface class LocalStore {
  /// 读取指定键的原始字符串内容。不存在返回 `null`。
  Future<String?> read(String key);

  /// 写入指定键的原始字符串内容。
  Future<void> write(String key, String value);

  /// 删除指定键。
  Future<void> delete(String key);

  /// 清空全部键。用于「隐私与数据设置」中的一键清除。
  Future<void> wipe();

  /// 当前已存储的全部键，用于调试与存储用量展示。
  Future<Set<String>> keys();
}

/// 存储键常量表。
abstract final class StoreKeys {
  /// 全部情绪记录（开心事 + 纸卷）的序列化集合。
  static const String entries = 'mood_entries';

  /// 花园聚合状态。
  static const String gardenState = 'garden_state';

  /// 用户设置（主题、提醒、标签、无障碍）。
  static const String settings = 'user_settings';
}

/// 内存实现。
///
/// ⚠️ 骨架期占位实现：数据仅存活于进程内存，App 重启即丢失，
/// **不具备** PRD 第 10 章要求的加密与持久化能力。
/// 替换为真实实现前，不应对外发布使用。
///
/// 之所以先提供它，是为了让上层业务代码（Controller / UI）能够
/// 在真实存储方案定案前就完整跑通，且切换实现时无需改动任何调用方。
class InMemoryLocalStore implements LocalStore {
  final Map<String, String> _memory = <String, String>{};

  @override
  Future<String?> read(String key) async => _memory[key];

  @override
  Future<void> write(String key, String value) async {
    _memory[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _memory.remove(key);
  }

  @override
  Future<void> wipe() async {
    _memory.clear();
  }

  @override
  Future<Set<String>> keys() async => _memory.keys.toSet();
}
