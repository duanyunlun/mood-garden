/// 仪式动作的轻音效（PRD 7.2.2：燃烧动画「配合动效与轻音效」）。
///
/// 抽成接口的两个理由：
/// - 上层不必知道用的是哪个音频库；
/// - 测试与不支持音频的端可以注入 [NoopSoundPlayer]，调用方无需写分支。
///
/// 注意「播放」与「是否该播放」是两件事：开关判断由调用方按用户设置决定，
/// 这一层只管放音。
abstract interface class SoundPlayer {
  /// 划火柴 / 点燃纸卷。
  Future<void> playIgnite();

  /// 种子入土 / 一件事被好好收下。
  Future<void> playSeedLanded();

  /// 释放底层资源。
  Future<void> dispose();
}

/// 什么都不做的实现。用于测试、以及音频不可用的端。
class NoopSoundPlayer implements SoundPlayer {
  const NoopSoundPlayer();

  @override
  Future<void> playIgnite() async {}

  @override
  Future<void> playSeedLanded() async {}

  @override
  Future<void> dispose() async {}
}
