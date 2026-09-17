import 'dart:convert';
import 'dart:io';

import 'local_store.dart';
import 'secret_envelope.dart';
import 'secure_master_key_provider.dart';

/// 加密文件存储 —— [LocalStore] 的真实实现。
///
/// 对齐 PRD 第 10 章「数据安全与隐私」与 `docs/ARCHITECTURE.md` 2.7 / 第 5 节：
/// - 对外只暴露键值读写，加密完全在本实现内部完成，调用方零感知；
/// - 密文使用 **AES-256-GCM**：带认证标签，文件被篡改会解密失败而不是读出脏数据；
/// - 主密钥不写在本文件里，由 `MasterKeyProvider` 托管在系统安全区。
///
/// 加解密本身交给 [SecretEnvelope]，与图片存储共用同一套信封格式。
///
/// 写入采用「临时文件 + 原子重命名」：即使写到一半被杀进程，磁盘上要么是旧的
/// 完整版本、要么是新的完整版本，不会留下半截文件（PRD 第 10 章「稳定性」）。
class EncryptedLocalStore implements LocalStore {
  EncryptedLocalStore({
    required Directory directory,
    required List<int> masterKey,
    this.fileName = 'mood_garden.store',
  })  : _directory = directory,
        _envelope = SecretEnvelope(masterKey: masterKey) {
    if (masterKey.length != masterKeyLengthInBytes) {
      throw ArgumentError.value(
        masterKey.length,
        'masterKey',
        '主密钥必须是 $masterKeyLengthInBytes 字节（AES-256-GCM）',
      );
    }
  }

  /// 密文文件所在目录（App 私有沙盒）。
  final Directory _directory;

  /// 密文文件名。
  final String fileName;

  final SecretEnvelope _envelope;

  /// 解密后的键值表缓存。`null` 表示尚未从磁盘加载。
  Map<String, String>? _cache;

  /// 正在进行的加载。避免并发读触发重复解密。
  Future<Map<String, String>>? _pendingLoad;

  /// 最近一次加载时被隔离的不可读文件路径。`null` 表示未发生。
  ///
  /// 暴露出来是为了让「数据读不出来」这件事可被观测与测试，
  /// 而不是悄无声息地退化成一个空花园。
  String? _quarantinedPath;

  File get _vaultFile =>
      File('${_directory.path}${Platform.pathSeparator}$fileName');

  File get _tempFile => File('${_vaultFile.path}.tmp');

  /// 最近一次加载时被隔离的不可读文件路径。
  String? get quarantinedPath => _quarantinedPath;

  /// 密文是否已经真正落盘。
  bool get hasPersistedData => _vaultFile.existsSync();

  /// 密文文件的完整路径。
  ///
  /// 供诊断展示与集成测试断言使用（例如「磁盘上不得出现明文」）。
  String get storeFilePath => _vaultFile.path;

  // ---------------------------------------------------------------------------
  // LocalStore
  // ---------------------------------------------------------------------------

  @override
  Future<String?> read(String key) async => (await _ensureLoaded())[key];

  @override
  Future<void> write(String key, String value) async {
    final values = await _ensureLoaded();
    values[key] = value;
    await _persist(values);
  }

  @override
  Future<void> delete(String key) async {
    final values = await _ensureLoaded();
    if (values.remove(key) == null) {
      // 键本就不存在：不必产生一次无意义的落盘。
      return;
    }
    await _persist(values);
  }

  @override
  Future<void> wipe() async {
    _cache = <String, String>{};
    for (final file in <File>[_vaultFile, _tempFile]) {
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }

  @override
  Future<Set<String>> keys() async => (await _ensureLoaded()).keys.toSet();

  // ---------------------------------------------------------------------------
  // 内部：加载与落盘
  // ---------------------------------------------------------------------------

  Future<Map<String, String>> _ensureLoaded() {
    final cached = _cache;
    if (cached != null) {
      return Future<Map<String, String>>.value(cached);
    }
    return _pendingLoad ??= _loadFromDisk();
  }

  Future<Map<String, String>> _loadFromDisk() async {
    try {
      final file = _vaultFile;
      if (!file.existsSync()) {
        return _cache = <String, String>{};
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return _cache = <String, String>{};
      }

      return _cache = await _decrypt(raw);
    } catch (error) {
      // 解密失败只有三种可能：主密钥变了、文件被篡改、文件损坏。
      // 三者都无法还原明文。此时**隔离保留**原文件而不是删除——
      // 日记类 App 宁可留下一个用户或许能人工恢复的文件，
      // 也不该静默销毁数据（PRD 第 10 章「稳定性」的设计取向）。
      await _quarantine(_vaultFile);
      return _cache = <String, String>{};
    } finally {
      _pendingLoad = null;
    }
  }

  Future<Map<String, String>> _decrypt(String raw) async {
    final clearBytes = await _envelope.open(raw);

    final Object? payload = jsonDecode(utf8.decode(clearBytes));
    if (payload is! Map) {
      throw const FormatException('解密后的内容不是键值表');
    }

    final values = Map<String, Object?>.from(payload);
    return <String, String>{
      for (final MapEntry<String, Object?> entry in values.entries)
        entry.key: entry.value?.toString() ?? '',
    };
  }

  Future<String> _encrypt(Map<String, String> values) =>
      _envelope.seal(utf8.encode(jsonEncode(values)));

  Future<void> _persist(Map<String, String> values) async {
    _cache = values;

    final directory = _directory;
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }

    final temp = _tempFile;
    await temp.writeAsString(await _encrypt(values), flush: true);
    // 原子替换：POSIX 下 rename 是原子操作，不会出现半截文件。
    await temp.rename(_vaultFile.path);
  }

  /// 把无法解密的文件改名保留，避免它阻塞启动，也避免数据被直接销毁。
  Future<void> _quarantine(File file) async {
    if (!file.existsSync()) {
      return;
    }
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '');
    final target = '${file.path}.unreadable-$stamp';
    try {
      await file.rename(target);
      _quarantinedPath = target;
    } catch (_) {
      // 隔离失败不应阻断启动：最坏情况是下次启动再试一次。
    }
  }
}
