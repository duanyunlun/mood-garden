import 'dart:io';
import 'dart:typed_data';

import '../../core/utils/id_generator.dart';
import '../../domain/repositories/entry_image_store.dart';
import 'secret_envelope.dart';

/// [EntryImageStore] 的加密文件实现 —— 正式版本使用它。
///
/// 每张图一个文件，用与文字存储相同的 [SecretEnvelope] 加密；
/// 写入同样是「临时文件 + 原子重命名」，避免写一半被杀进程留下半张图。
class EncryptedFileEntryImageStore implements EntryImageStore {
  EncryptedFileEntryImageStore({
    required Directory directory,
    required List<int> masterKey,
    this.folderName = 'mood_garden_images',
  })  : _directory = directory,
        _envelope = SecretEnvelope(masterKey: masterKey);

  /// 解密后字节的缓存条数上限。
  ///
  /// 必须设上限：一张手机照片解密后有好几 MB，把用户所有图片都留在内存里，
  /// 在花园与时光轴之间翻几页就会把内存吃光。
  static const int cacheLimit = 24;

  /// 图片目录的父目录（App 私有沙盒）。
  final Directory _directory;

  /// 图片目录名。
  final String folderName;

  final SecretEnvelope _envelope;

  /// 插入序缓存，超出上限时淘汰最早的条目。
  final Map<String, Uint8List> _cache = <String, Uint8List>{};

  Directory get _folder =>
      Directory('${_directory.path}${Platform.pathSeparator}$folderName');

  File _fileOf(String id) =>
      File('${_folder.path}${Platform.pathSeparator}$id.img');

  @override
  Future<String> save(Uint8List bytes) async {
    final folder = _folder;
    if (!folder.existsSync()) {
      await folder.create(recursive: true);
    }

    final id = IdGenerator.next('img');
    final target = _fileOf(id);
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(await _envelope.seal(bytes), flush: true);
    await temp.rename(target.path);

    _remember(id, bytes);
    return id;
  }

  @override
  Future<Uint8List?> read(String id) async {
    final cached = _cache[id];
    if (cached != null) {
      return cached;
    }

    final file = _fileOf(id);
    if (!file.existsSync()) {
      return null;
    }

    try {
      final bytes = Uint8List.fromList(
        await _envelope.open(await file.readAsString()),
      );
      _remember(id, bytes);
      return bytes;
    } catch (_) {
      // 单张图解不开（密钥变更 / 文件损坏）不该让整页打不开，也不删文件：
      // 与文字存储同一取向——宁可留着等人工恢复，也不静默销毁。
      return null;
    }
  }

  @override
  Future<void> delete(String id) async {
    _cache.remove(id);

    final file = _fileOf(id);
    if (file.existsSync()) {
      await file.delete();
    }
    final temp = File('${file.path}.tmp');
    if (temp.existsSync()) {
      await temp.delete();
    }
  }

  @override
  Future<void> deleteAll(Iterable<String> ids) async {
    for (final id in ids) {
      await delete(id);
    }
  }

  @override
  Future<int> count() async {
    final folder = _folder;
    if (!folder.existsSync()) {
      return 0;
    }
    return folder
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.img'))
        .length;
  }

  @override
  Future<void> wipe() async {
    _cache.clear();
    final folder = _folder;
    if (folder.existsSync()) {
      await folder.delete(recursive: true);
    }
  }

  void _remember(String id, Uint8List bytes) {
    _cache[id] = bytes;
    while (_cache.length > cacheLimit) {
      _cache.remove(_cache.keys.first);
    }
  }
}

/// 内存实现。用于存储降级路径与测试。
class InMemoryEntryImageStore implements EntryImageStore {
  final Map<String, Uint8List> _images = <String, Uint8List>{};

  @override
  Future<String> save(Uint8List bytes) async {
    final id = IdGenerator.next('img');
    _images[id] = bytes;
    return id;
  }

  @override
  Future<Uint8List?> read(String id) async => _images[id];

  @override
  Future<void> delete(String id) async {
    _images.remove(id);
  }

  @override
  Future<void> deleteAll(Iterable<String> ids) async {
    for (final id in ids) {
      _images.remove(id);
    }
  }

  @override
  Future<int> count() async => _images.length;

  @override
  Future<void> wipe() async => _images.clear();
}
