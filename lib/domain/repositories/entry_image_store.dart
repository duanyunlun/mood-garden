import 'dart:typed_data';

/// 记录附图（照片）的存储契约。
///
/// 放在领域层而不是数据层，是为了让 `application` 层只依赖抽象——
/// 与 [EntryRepository]、[GardenRepository] 的处理保持一致
/// （见 `docs/ARCHITECTURE.md` 第 1 节的分层结构）。
///
/// 图片与文字走**同一套加密承诺**（PRD 第 10 章），但落地方式必须不同：
/// 图片是二进制且体积大，若塞进那个键值 JSON 里，base64 会把每条记录撑大
/// 几十倍，而且每次写一个字都要重新加密整张图。因此实现方应为每张图单独
/// 成文件，复用同一把主密钥与同一套信封格式。
///
/// 对上层只暴露「存 / 取 / 删」并返回 id，不暴露任何文件路径——
/// id 存进 `MoodEntry.imagePaths`。
abstract interface class EntryImageStore {
  /// 保存一张图片，返回其 id。
  Future<String> save(Uint8List bytes);

  /// 读取并解密一张图片。不存在或解密失败返回 `null`。
  ///
  /// 刻意不抛异常：单张图坏掉不该让整页记录打不开。
  Future<Uint8List?> read(String id);

  /// 删除一张图片。
  Future<void> delete(String id);

  /// 批量删除。**纸卷燃烧时用它落实「不可恢复」**（PRD 7.2.3）：
  /// 记录对象里的图片引用被清空的同时，磁盘上的图片也必须一起消失，
  /// 否则「原文不可恢复」这条承诺在图片上就是空的。
  Future<void> deleteAll(Iterable<String> ids);

  /// 当前已保存的图片数量，用于诊断与测试断言。
  Future<int> count();

  /// 清空全部图片，供「清除全部数据」使用。
  Future<void> wipe();
}
