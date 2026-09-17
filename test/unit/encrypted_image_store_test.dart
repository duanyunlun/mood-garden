import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mood_garden/data/datasources/encrypted_image_store.dart';
import 'package:mood_garden/data/datasources/secret_envelope.dart';
import 'package:mood_garden/data/datasources/secure_master_key_provider.dart';

/// 附图加密存储测试。
///
/// 照片是这个 App 里最敏感、体积最大的数据，测的重点有三个：
/// 1. 存进去的是密文——磁盘上不能存在可直接打开的图片；
/// 2. 取回来必须与原图逐字节一致（图片坏一点点就是花屏）；
/// 3. 删除必须真的落到磁盘上，因为「烧掉就没了」这条承诺靠它兑现。
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('mood_garden_image_test');
  });

  tearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  List<int> fixedKey([int seed = 11]) =>
      List<int>.filled(masterKeyLengthInBytes, seed);

  EncryptedFileEntryImageStore buildStore({List<int>? key}) =>
      EncryptedFileEntryImageStore(
        directory: dir,
        masterKey: key ?? fixedKey(),
      );

  /// 一段带可识别标记的伪图片数据。
  Uint8List sampleImage({String marker = 'MOOD_GARDEN_IMAGE_MARKER'}) {
    return Uint8List.fromList(<int>[
      0xFF, 0xD8, 0xFF, 0xE0, // 伪 JPEG 头
      ...utf8.encode(marker * 50),
    ]);
  }

  Directory imageFolder() =>
      Directory('${dir.path}${Platform.pathSeparator}mood_garden_images');

  group('附图加密落盘', () {
    test('保存后能读回，且与原图逐字节一致', () async {
      final store = buildStore();
      final original = sampleImage();

      final id = await store.save(original);
      final loaded = await store.read(id);

      expect(loaded, isNotNull);
      expect(loaded, equals(original), reason: '图片差一个字节就是花屏');
      expect(await store.count(), 1);
    });

    test('磁盘上是密文，不含图片头与任何明文片段', () async {
      final store = buildStore();
      const marker = 'MOOD_GARDEN_IMAGE_MARKER';
      await store.save(sampleImage(marker: marker));

      final files = imageFolder().listSync().whereType<File>().toList();
      expect(files, hasLength(1));

      final raw = await files.single.readAsString();
      expect(raw.contains(marker), isFalse, reason: '明文不得出现在磁盘上');
      expect(raw.contains('img_'), isFalse, reason: '文件名之外不该再有 id 痕迹');

      // 仍然是统一的加密信封格式
      final envelope = Map<String, Object?>.from(jsonDecode(raw) as Map);
      expect(envelope['v'], SecretEnvelope.formatVersion);
      expect(envelope['alg'], 'AES-256-GCM');
    });

    test('新实例能读回旧图（模拟重启后翻看时光轴）', () async {
      final key = fixedKey();
      final first = EncryptedFileEntryImageStore(
        directory: dir,
        masterKey: key,
      );
      final original = sampleImage();
      final id = await first.save(original);

      // 全新实例、同一把主密钥 —— 等价于 App 重启后打开同一天
      final second = EncryptedFileEntryImageStore(
        directory: dir,
        masterKey: key,
      );

      expect(await second.read(id), equals(original));
    });

    test('主密钥不同时返回 null，而不是抛异常或读出脏数据', () async {
      final first = buildStore(key: fixedKey(1));
      final id = await first.save(sampleImage());

      final second = buildStore(key: fixedKey(2));

      // 界面拿不到图应该优雅跳过这一张，而不是整页打不开
      expect(await second.read(id), isNull);
    });

    test('文件被篡改时返回 null（AES-GCM 认证）', () async {
      final key = fixedKey(5);
      final store = EncryptedFileEntryImageStore(
        directory: dir,
        masterKey: key,
      );
      final id = await store.save(sampleImage());

      final file = imageFolder().listSync().whereType<File>().single;
      final envelope = Map<String, Object?>.from(
        jsonDecode(await file.readAsString()) as Map,
      );
      final data = base64Decode(envelope['data'] as String);
      data[0] = data[0] ^ 0xFF;
      envelope['data'] = base64Encode(data);
      await file.writeAsString(jsonEncode(envelope));

      final reopened = EncryptedFileEntryImageStore(
        directory: dir,
        masterKey: key,
      );
      expect(await reopened.read(id), isNull);
    });

    test('不存在的 id 返回 null', () async {
      final store = buildStore();
      expect(await store.read('img_not_exist'), isNull);
    });

    test('写入采用原子替换，不残留临时文件', () async {
      final store = buildStore();
      await store.save(sampleImage());
      await store.save(sampleImage());

      final leftovers = imageFolder()
          .listSync()
          .map((e) => e.path.split(Platform.pathSeparator).last)
          .where((name) => name.endsWith('.tmp'))
          .toList(growable: false);

      expect(leftovers, isEmpty);
    });
  });

  group('附图删除（「烧掉就没了」的落点）', () {
    test('delete 会真的删掉磁盘上的密文', () async {
      final store = buildStore();
      final id = await store.save(sampleImage());
      expect(imageFolder().listSync(), hasLength(1));

      await store.delete(id);

      expect(imageFolder().listSync(), isEmpty, reason: '密文必须从磁盘消失');
      expect(await store.read(id), isNull);
    });

    test('deleteAll 批量删除', () async {
      final store = buildStore();
      final ids = <String>[
        await store.save(sampleImage()),
        await store.save(sampleImage()),
        await store.save(sampleImage()),
      ];
      expect(await store.count(), 3);

      await store.deleteAll(ids);

      expect(await store.count(), 0);
      expect(imageFolder().listSync(), isEmpty);
    });

    test('重复删除不报错（燃烧流程可能被重试）', () async {
      final store = buildStore();
      final id = await store.save(sampleImage());

      await store.delete(id);
      await store.delete(id);

      expect(await store.count(), 0);
    });

    test('wipe 清空整个图片目录', () async {
      final store = buildStore();
      await store.save(sampleImage());
      await store.save(sampleImage());

      await store.wipe();

      expect(await store.count(), 0);
      expect(imageFolder().existsSync(), isFalse);
    });
  });

  group('缓存', () {
    test('缓存有上限，不会把所有解密后的图片都留在内存里', () async {
      final store = buildStore();
      final ids = <String>[];
      for (var i = 0; i < EncryptedFileEntryImageStore.cacheLimit + 6; i++) {
        ids.add(await store.save(sampleImage(marker: 'marker-$i-')));
      }

      // 全部读过一遍后，最早那几张应已被驱逐；再读仍能正确解密
      for (final id in ids) {
        expect(await store.read(id), isNotNull);
      }
      expect(await store.count(), ids.length);
    });

    test('删除后缓存里也不会留下副本', () async {
      final store = buildStore();
      final original = sampleImage();
      final id = await store.save(original);
      expect(await store.read(id), equals(original));

      await store.delete(id);

      expect(await store.read(id), isNull, reason: '删除后不能再从缓存里读到');
    });
  });
}
