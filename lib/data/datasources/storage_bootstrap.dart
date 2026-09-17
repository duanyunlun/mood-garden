import 'package:path_provider/path_provider.dart';

import '../../domain/repositories/entry_image_store.dart';
import 'encrypted_image_store.dart';
import 'encrypted_local_store.dart';
import 'local_store.dart';
import 'secure_master_key_provider.dart';

/// 密文文件名。
const String storeFileName = 'mood_garden.store';

/// 图片密文目录名。
const String imageFolderName = 'mood_garden_images';

/// 存储形态。
enum StorageKind {
  /// 加密文件 + 系统安全区托管的密钥。正式版本的目标形态。
  encryptedFile,

  /// 内存存储。数据不落盘，进程结束即丢失——仅用于降级与测试。
  memory,
}

/// 存储装配结果。
///
/// 把「用哪种存储、是否降级、为什么降级」显式带到 UI 层：用户应当在设置里
/// 看到数据到底有没有真正落盘，而不是自己发现「记了半天，重开全没了」。
class StorageBootstrap {
  const StorageBootstrap({
    required this.store,
    required this.images,
    required this.kind,
    this.degradedReason,
  });

  /// 供仓库层使用的键值存储实例（文字记录与花园状态）。
  final LocalStore store;

  /// 附图存储实例。与 [store] 共用同一把主密钥。
  final EntryImageStore images;

  /// 实际生效的存储形态。
  final StorageKind kind;

  /// 降级原因。仅在 [kind] 为 [StorageKind.memory] 时非空。
  final String? degradedReason;

  /// 数据是否会真正落盘。
  bool get isPersistent => kind == StorageKind.encryptedFile;

  /// 是否因为故障而退化为内存存储。
  bool get isDegraded => kind == StorageKind.memory;
}

/// 装配本地存储：**加密文件 + 系统安全区托管的密钥**。
///
/// 完整落地 PRD 第 10 章「数据安全与隐私」的两条要求：
/// 1. 密文写入 App 私有沙盒（[getApplicationDocumentsDirectory]）；
/// 2. 主密钥交由 Keychain / Keystore 托管，不与密文同处存放
///    （见 `docs/ARCHITECTURE.md` 第 5 节）。
///
/// 文字与图片共用同一把主密钥、同一套信封格式，只是图片各自单独成文件。
///
/// ⚠️ 任何一步失败都**降级为内存存储**而不是抛出：
/// 「安全区不可用」不该变成「App 打不开」。降级原因回传给 UI 显式展示，
/// 让用户知道这一轮记录不会留存。
Future<StorageBootstrap> bootstrapLocalStore({
  MasterKeyProvider? keyProvider,
}) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final masterKey = await (keyProvider ?? SecureStorageMasterKeyProvider())
        .loadOrCreate();

    return StorageBootstrap(
      store: EncryptedLocalStore(
        directory: directory,
        masterKey: masterKey,
        fileName: storeFileName,
      ),
      images: EncryptedFileEntryImageStore(
        directory: directory,
        masterKey: masterKey,
        folderName: imageFolderName,
      ),
      kind: StorageKind.encryptedFile,
    );
  } catch (error) {
    // 降级时文字与图片一起退化为内存，保持两者形态一致——
    // 否则会出现「文字落盘了、图片却没有」这种更难解释的半持久状态。
    return StorageBootstrap(
      store: InMemoryLocalStore(),
      images: InMemoryEntryImageStore(),
      kind: StorageKind.memory,
      degradedReason: '$error',
    );
  }
}
