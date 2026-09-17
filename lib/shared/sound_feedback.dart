import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../application/settings_controller.dart';
import '../domain/repositories/sound_player.dart';

/// 按用户设置播放一次仪式音效。
///
/// 刻意不 `await`：音效是氛围，不该让动画等它。播放失败也不会影响主流程
/// ——失败处理在 `SoundPlayer` 的实现里，调用方不需要 try/catch。
///
/// 抽成函数是为了让「先看开关、再放音」这条规则只有一处实现：
/// 散在各页面里写，早晚会漏掉一处开关判断。
void playFeedback(
  BuildContext context,
  Future<void> Function(SoundPlayer player) play,
) {
  final settings = context.read<SettingsController>().settings;
  if (!settings.soundEnabled) {
    return;
  }

  unawaited(play(context.read<SoundPlayer>()));
}
