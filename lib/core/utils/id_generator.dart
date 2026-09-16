import 'dart:math';

/// 唯一标识生成器。
///
/// 采用「时间戳 + 随机数」的 base36 组合：单机场景下碰撞概率可忽略，
/// 且天然按时间递增，便于排查问题。骨架期不引入 `uuid` 依赖以保持依赖精简。
abstract final class IdGenerator {
  static final Random _random = Random();

  /// 生成一个新的唯一标识。
  ///
  /// [prefix] 用于让 id 自带语义，例如 `happy_xxx`、`unhappy_xxx`、`flower_xxx`。
  static String next([String prefix = '']) {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final random = _random.nextInt(1 << 32).toRadixString(36).padLeft(7, '0');
    final body = '$timestamp$random';
    return prefix.isEmpty ? body : '${prefix}_$body';
  }
}
