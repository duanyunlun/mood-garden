import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mood_garden/data/datasources/encrypted_local_store.dart';
import 'package:mood_garden/data/datasources/local_store.dart';
import 'package:mood_garden/data/datasources/secret_envelope.dart';
import 'package:mood_garden/data/datasources/secure_master_key_provider.dart';
import 'package:mood_garden/data/datasources/storage_bootstrap.dart';

/// 加密持久化层测试（PRD 第 10 章「数据安全与隐私」）。
///
/// 这组测试在真实文件系统上跑真实的 AES-256-GCM，不使用任何内存替身：
/// 「数据落盘」与「磁盘上读不出明文」这两条承诺，只有真的读写磁盘才算被验证。
void main() {
  late Directory dir;
  late File vaultFile;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('mood_garden_store_test');
    vaultFile = File('${dir.path}/$storeFileName');
  });

  tearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  /// 测试用固定主密钥。生产环境由系统安全区托管（见下面的分组）。
  List<int> fixedKey([int seed = 7]) =>
      List<int>.filled(masterKeyLengthInBytes, seed);

  EncryptedLocalStore buildStore({List<int>? key}) => EncryptedLocalStore(
        directory: dir,
        masterKey: key ?? fixedKey(),
      );

  group('加密落盘（PRD 第 10 章）', () {
    test('写入后能读回', () async {
      final store = buildStore();
      await store.write('k', 'v');

      expect(await store.read('k'), 'v');
      expect(await store.read('不存在的键'), isNull);
    });

    test('新实例能读回旧数据（模拟杀进程重启）', () async {
      final key = fixedKey();
      final first = EncryptedLocalStore(directory: dir, masterKey: key);
      await first.write(StoreKeys.entries, '今天遇见一只很亲人的橘猫');
      await first.write(StoreKeys.gardenState, '{"nutrientValue":42}');

      // 同一目录、同一主密钥、全新实例 —— 相当于 App 被杀死后重新启动
      final second = EncryptedLocalStore(directory: dir, masterKey: key);

      expect(await second.read(StoreKeys.entries), '今天遇见一只很亲人的橘猫');
      expect(await second.read(StoreKeys.gardenState), '{"nutrientValue":42}');
      expect(
        await second.keys(),
        <String>{StoreKeys.entries, StoreKeys.gardenState},
      );
    });

    test('磁盘上是密文，不含任何明文片段', () async {
      final store = buildStore();
      const secret = '今天在便利店遇见了一只很亲人的橘猫';
      await store.write(StoreKeys.entries, secret);

      expect(vaultFile.existsSync(), isTrue);
      final raw = await vaultFile.readAsString();

      expect(raw.contains(secret), isFalse, reason: '明文不得出现在磁盘上');
      expect(raw.contains('entries'), isFalse, reason: '键名同样属于敏感元数据');

      // 信封仍是合法 JSON，格式才可演进
      final envelope = Map<String, Object?>.from(jsonDecode(raw) as Map);
      expect(envelope['v'], SecretEnvelope.formatVersion);
      expect(envelope['alg'], 'AES-256-GCM');
      expect(envelope['nonce'], isA<String>());
    });

    test('主密钥变化时读不出旧数据，且原文件被隔离保留', () async {
      final first = EncryptedLocalStore(directory: dir, masterKey: fixedKey(1));
      await first.write(StoreKeys.entries, '旧日记');

      final second = EncryptedLocalStore(directory: dir, masterKey: fixedKey(2));
      expect(await second.read(StoreKeys.entries), isNull, reason: '换密钥就该解不开');

      // 关键：原文件不是被删除，而是改名保留，用户仍有恢复机会
      final quarantined = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('.unreadable-'))
          .toList(growable: false);

      expect(quarantined, hasLength(1), reason: '不可读的文件应被隔离保留而非删除');
      expect(second.quarantinedPath, isNotNull);
      expect(File(second.quarantinedPath!).existsSync(), isTrue);
      expect(
        await File(second.quarantinedPath!).readAsString(),
        isNotEmpty,
        reason: '隔离文件应保留原始密文内容',
      );
    });

    test('密文被篡改时不会读出脏数据（AES-GCM 认证）', () async {
      final key = fixedKey(9);
      final store = EncryptedLocalStore(directory: dir, masterKey: key);
      await store.write(StoreKeys.entries, '原始内容');

      // 翻转密文首字节，模拟有人手工改存储文件
      final envelope = Map<String, Object?>.from(
        jsonDecode(await vaultFile.readAsString()) as Map,
      );
      final data = base64Decode(envelope['data'] as String);
      data[0] = data[0] ^ 0xFF;
      envelope['data'] = base64Encode(data);
      await vaultFile.writeAsString(jsonEncode(envelope));

      final reopened = EncryptedLocalStore(directory: dir, masterKey: key);
      expect(
        await reopened.read(StoreKeys.entries),
        isNull,
        reason: '认证标签校验失败时不得返回被篡改的内容',
      );
      expect(reopened.quarantinedPath, isNotNull);
    });

    test('delete 只移除指定键并落盘', () async {
      final store = buildStore();
      await store.write('a', '1');
      await store.write('b', '2');

      await store.delete('a');
      expect(await store.keys(), <String>{'b'});

      // 重新打开确认删除已落盘，而不只是改了内存
      final reopened = buildStore();
      expect(await reopened.read('a'), isNull);
      expect(await reopened.read('b'), '2');
    });

    test('wipe 清空全部键与磁盘文件', () async {
      final store = buildStore();
      await store.write('a', '1');
      await store.write('b', '2');
      expect(vaultFile.existsSync(), isTrue);

      await store.wipe();

      expect(await store.keys(), isEmpty);
      expect(vaultFile.existsSync(), isFalse, reason: '一键清除应删除磁盘上的密文');
    });

    test('写入采用原子替换，不残留临时文件', () async {
      final store = buildStore();
      await store.write('a', '1');
      await store.write('a', '2');
      await store.write('a', '3');

      final leftovers = dir
          .listSync()
          .map((e) => e.path.split(Platform.pathSeparator).last)
          .where((name) => name.endsWith('.tmp'))
          .toList(growable: false);

      expect(leftovers, isEmpty);
      expect(await store.read('a'), '3');
    });

    test('目录不存在时自动创建', () async {
      final nested = Directory('${dir.path}/nested/deeper');
      final store = EncryptedLocalStore(
        directory: nested,
        masterKey: fixedKey(3),
      );

      await store.write('a', '1');

      expect(await store.read('a'), '1');
      expect(nested.existsSync(), isTrue);
    });

    test('空文件视为空存储，而不是解密失败', () async {
      await vaultFile.writeAsString('   ');
      final store = buildStore();

      expect(await store.keys(), isEmpty);
      expect(store.quarantinedPath, isNull, reason: '空文件不该被当成损坏数据隔离');
    });

    test('主密钥长度不是 32 字节时直接拒绝', () {
      expect(
        () => EncryptedLocalStore(directory: dir, masterKey: <int>[1, 2, 3]),
        throwsArgumentError,
      );
    });
  });

  group('主密钥托管（Keychain / Keystore 落点）', () {
    late Map<String, String> vault;

    setUp(() {
      vault = <String, String>{};
      FlutterSecureStoragePlatform.instance =
          TestFlutterSecureStoragePlatform(vault);
    });

    test('首次调用生成 32 字节密钥并写入安全区', () async {
      final key = await SecureStorageMasterKeyProvider().loadOrCreate();

      expect(key, hasLength(masterKeyLengthInBytes));
      expect(vault.keys, contains('mood_garden_master_key'));
    });

    test('二次调用返回同一把密钥（保证重启后仍能解密）', () async {
      final first = await SecureStorageMasterKeyProvider().loadOrCreate();
      // 新实例模拟下一次启动
      final second = await SecureStorageMasterKeyProvider().loadOrCreate();

      expect(second, first, reason: '密钥必须稳定，否则历史记录将永久无法解密');
    });

    test('安全区内容损坏时重新生成而不是抛异常', () async {
      vault['mood_garden_master_key'] = '这不是合法的 base64!!';

      final key = await SecureStorageMasterKeyProvider().loadOrCreate();

      expect(key, hasLength(masterKeyLengthInBytes));
    });

    test('安全区里是长度异常的合法 base64 时也重新生成', () async {
      vault['mood_garden_master_key'] = base64Encode(<int>[1, 2, 3]);

      final key = await SecureStorageMasterKeyProvider().loadOrCreate();

      expect(key, hasLength(masterKeyLengthInBytes));
    });
  });

  group('存储装配与降级', () {
    test('平台不可用时降级为内存存储，而不是让 App 打不开', () async {
      // flutter test 环境没有 path_provider 平台实现，
      // getApplicationDocumentsDirectory() 会失败——装配层必须把它转成降级。
      final bootstrap = await bootstrapLocalStore();

      expect(bootstrap.kind, StorageKind.memory);
      expect(bootstrap.isPersistent, isFalse);
      expect(bootstrap.isDegraded, isTrue);
      expect(bootstrap.degradedReason, isNotNull);

      // 降级后的存储仍须可正常读写，不能是个坏对象
      await bootstrap.store.write('a', '1');
      expect(await bootstrap.store.read('a'), '1');
    });
  });
}
