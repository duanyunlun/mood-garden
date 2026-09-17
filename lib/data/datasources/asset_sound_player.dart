import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../domain/repositories/sound_player.dart';

/// 播放打包在 assets 里的音效。
///
/// 素材是 `tool/generate_audio_assets.py` 合成的**占位音**，不是正式音效设计。
/// 替换时只要保持文件名不变，这里零改动。
///
/// 实现上的两个要点：
/// - **两个独立 player**：同一条链路里先响火柴再响完成音，
///   共用一个 player 会让后一声打断前一声；
/// - **失败静默**：音频设备被占用、格式不支持、桌面端没有音频后端……
///   这些都不该让记录流程中断。音效是锦上添花，不是主流程。
class AssetSoundPlayer implements SoundPlayer {
  AssetSoundPlayer({AudioPlayer? ignitePlayer, AudioPlayer? seedPlayer})
      : _ignitePlayer = ignitePlayer ?? AudioPlayer(),
        _seedPlayer = seedPlayer ?? AudioPlayer();

  /// 与 `assets/audio/` 下的文件名保持一致。
  static const String igniteAsset = 'audio/match_strike.wav';
  static const String seedAsset = 'audio/seed_landing.wav';

  /// 音量压得较低：日记应用里音效是氛围，不是提示。
  static const double _igniteVolume = 0.45;
  static const double _seedVolume = 0.35;

  final AudioPlayer _ignitePlayer;
  final AudioPlayer _seedPlayer;

  @override
  Future<void> playIgnite() =>
      _play(_ignitePlayer, igniteAsset, _igniteVolume);

  @override
  Future<void> playSeedLanded() =>
      _play(_seedPlayer, seedAsset, _seedVolume);

  Future<void> _play(AudioPlayer player, String asset, double volume) async {
    try {
      // ReleaseMode.stop：放完就释放，短音效不需要常驻播放器状态。
      await player.setReleaseMode(ReleaseMode.stop);
      await player.stop();
      await player.play(AssetSource(asset), volume: volume);
    } catch (error) {
      // 放不出声不影响记录本身，只记一条调试信息。
      debugPrint('音效播放失败（不影响记录）：$error');
    }
  }

  @override
  Future<void> dispose() async {
    await _ignitePlayer.dispose();
    await _seedPlayer.dispose();
  }
}
