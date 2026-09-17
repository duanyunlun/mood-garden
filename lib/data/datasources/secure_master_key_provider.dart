import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';

/// 主密钥长度：AES-256-GCM 要求 32 字节（PRD 第 10 章）。
const int masterKeyLengthInBytes = 32;

/// 生成一枚 32 字节主密钥。
///
/// 使用 [Random.secure]，其熵源来自操作系统，不可预测也不可复现。
List<int> generateMasterKey() {
  final random = Random.secure();
  return List<int>.generate(
    masterKeyLengthInBytes,
    (_) => random.nextInt(256),
    growable: false,
  );
}

/// 构造平台适配的安全存储实例。
///
/// macOS 与 iOS 都走 Keychain，但** entitlement 要求不同**，
/// 这一点是 `flutter_secure_storage_darwin` 的 README 明确写着的，
/// 而且失败方式很隐蔽：密钥会「看起来写成功、实际没写进去」，
/// 于是本次运行一切正常，**下次启动却解不开旧密文**。所以必须区别对待：
///
/// - **iOS**：需要 `Runner/DebugProfile.entitlements` 与
///   `Release.entitlements` 里的 `keychain-access-groups`，它随
///   provisioning profile 生效。本仓库已补齐这两个文件。
/// - **macOS**：加同一个 entitlement 会要求 provisioning profile，
///   导致打出来的 `.app` 只能在构建它的机器上启动。本项目不需要
///   Keychain Sharing（没有 App Group、也不与其它 App 共享条目），
///   因此按插件文档回退到 legacy Keychain，从而免掉 entitlement 与 profile。
FlutterSecureStorage createSecureStorage() {
  if (Platform.isMacOS) {
    return const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    );
  }
  return const FlutterSecureStorage();
}

/// 主密钥提供方。
///
/// 对齐 PRD 第 10 章「数据安全与隐私」与 `docs/ARCHITECTURE.md` 第 5 节：
/// 加密密钥**不得**与密文存放在一起，必须交由系统安全区托管
/// （iOS / macOS → Keychain，Android → Keystore，别名见
/// [AppConstants.encryptionKeyAlias]）。
///
/// 之所以抽成接口：让存储层能脱离平台通道被测试——
/// 单元测试注入固定密钥即可，无需真实 Keychain / Keystore。
abstract interface class MasterKeyProvider {
  /// 读取已托管的主密钥；不存在时生成并托管。返回 32 字节原始密钥。
  Future<List<int>> loadOrCreate();
}

/// 基于系统安全区（Keychain / Keystore）的实现。正式版本使用它。
class SecureStorageMasterKeyProvider implements MasterKeyProvider {
  SecureStorageMasterKeyProvider({
    FlutterSecureStorage? storage,
    this.keyAlias = AppConstants.encryptionKeyAlias,
  }) : _storage = storage ?? createSecureStorage();

  final FlutterSecureStorage _storage;

  /// 主密钥在系统安全区中的别名，取自 [AppConstants.encryptionKeyAlias]。
  final String keyAlias;

  @override
  Future<List<int>> loadOrCreate() async {
    final String? stored = await _storage.read(key: keyAlias);
    if (stored != null) {
      final decoded = _tryDecode(stored);
      if (decoded != null && decoded.length == masterKeyLengthInBytes) {
        return decoded;
      }
      // 托管内容已损坏（非法 base64 或长度异常）：重新生成。
      // 旧密文将无法解密，由 EncryptedLocalStore 隔离保留而非删除，
      // 因此这里不会造成数据的静默销毁。
    }

    final generated = generateMasterKey();
    await _storage.write(key: keyAlias, value: base64Encode(generated));
    return generated;
  }

  /// 宽容解码：非法 base64 返回 `null` 而不是抛异常，
  /// 让「安全区里的值坏了」不至于变成「App 打不开」。
  static List<int>? _tryDecode(String value) {
    try {
      return base64Decode(value);
    } on FormatException {
      return null;
    }
  }
}

/// 进程内临时密钥。仅用于「安全区不可用」时的降级路径与测试。
///
/// ⚠️ 不托管、不持久：进程结束即失效，下次启动无法解密上次的数据。
/// 它的存在是为了让安全区故障不至于变成「App 打不开」，
/// 而不是一个可用于发布的选择。
class EphemeralMasterKeyProvider implements MasterKeyProvider {
  EphemeralMasterKeyProvider() : _key = generateMasterKey();

  final List<int> _key;

  @override
  Future<List<int>> loadOrCreate() async => _key;
}
