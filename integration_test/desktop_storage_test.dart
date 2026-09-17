import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mood_garden/data/datasources/encrypted_local_store.dart';
import 'package:mood_garden/data/datasources/local_store.dart';
import 'package:mood_garden/data/datasources/storage_bootstrap.dart';

/// 真实平台后端上的落盘与密钥托管测试（在 macOS 桌面端运行）。
///
/// 与 `test/unit/encrypted_local_store_test.dart` 的区别在于**后端是真实的**：
///
/// | | unit 测试 | 本测试 |
/// | --- | --- | --- |
/// | 目录 | `Directory.systemTemp` | 真实沙盒 Documents（`path_provider`） |
/// | 密钥 | 测试内固定值 | 真实 **Keychain**（`flutter_secure_storage`） |
///
/// 这正好覆盖 iOS 上最不确定的那条路径：
/// macOS 与 iOS 的 `path_provider` 同属 Foundation 目录 API，
/// 密钥托管也同属 Keychain。也就是说，**这条测试通过，
/// 「iOS 上数据能否落盘、密钥能否被系统托管」这个最大的未知就基本排除了**。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('真实后端：加密落盘、Keychain 托管密钥，重建实例后仍能解密', (tester) async {
    // 1. 装配真实存储
    final first = await bootstrapLocalStore();
    expect(
      first.isPersistent,
      isTrue,
      reason: '桌面端应装配出加密文件存储；若降级说明 Keychain 或沙盒目录不可用：'
          '${first.degradedReason}',
    );
    final store = first.store as EncryptedLocalStore;

    // 2. 写入一段可识别的内容
    const marker = '桌面端落盘验证 desktop-persist-marker';
    await store.write(StoreKeys.entries, marker);
    expect(store.hasPersistedData, isTrue, reason: '密文文件应已落盘');

    // 3. 磁盘上不得出现明文
    final raw = await File(store.storeFilePath).readAsString();
    expect(raw.contains(marker), isFalse, reason: '明文不得出现在磁盘上');
    expect(raw.contains(StoreKeys.entries), isFalse, reason: '键名也不应出现');
    expect(raw.contains('AES-256-GCM'), isTrue, reason: '应是加密信封格式');

    // 4. 全新装配 + 重新从 Keychain 取密钥 —— 等价于 App 重启
    final second = await bootstrapLocalStore();
    expect(second.isPersistent, isTrue);
    final reopened = second.store as EncryptedLocalStore;

    expect(
      await reopened.read(StoreKeys.entries),
      marker,
      reason: '重启后必须能用 Keychain 里的同一把密钥解开旧密文',
    );
    expect(
      reopened.quarantinedPath,
      isNull,
      reason: '不应发生解密失败导致的隔离',
    );

    // 5. 清理，避免污染应用容器
    await reopened.wipe();
    expect(reopened.hasPersistedData, isFalse);
  });

  testWidgets('燃烧后写回的内容不含原文（真实后端上的隐私承诺）', (tester) async {
    final bootstrap = await bootstrapLocalStore();
    final store = bootstrap.store as EncryptedLocalStore;

    await store.write(StoreKeys.entries, 'burned-原文-should-vanish');
    await store.wipe();

    // wipe 之后重建，不应还能读到任何东西
    final reopened = (await bootstrapLocalStore()).store as EncryptedLocalStore;
    expect(await reopened.read(StoreKeys.entries), isNull);
    await reopened.wipe();
  });
}
