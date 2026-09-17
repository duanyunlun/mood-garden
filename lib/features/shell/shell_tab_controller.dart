import 'package:flutter/foundation.dart';

/// 一级 Tab 的当前索引。
///
/// 为什么要一个共享的 notifier，而不是把回调层层透传：
/// 记录首页（Tab1）右上角有个直达「我的」（Tab4）的入口，
/// 而两者之间隔着 `MainShell`。透传回调会把 MainShell 变成
/// 一个纯粹的消息中转站；用一个小 notifier 更直接。
///
/// 索引与 `MainShell` 的页面顺序绑定：0 记录 / 1 时光 / 2 花园 / 3 我的。
class ShellTabController extends ValueNotifier<int> {
  ShellTabController() : super(record);

  /// 记录（首页）。
  static const int record = 0;

  /// 时光。
  static const int days = 1;

  /// 花园。
  static const int garden = 2;

  /// 我的。
  static const int profile = 3;

  /// 切到「我的」。
  void goToProfile() => value = profile;

  /// 切到「花园」。
  void goToGarden() => value = garden;

  /// 切到「记录」。
  void goToRecord() => value = record;
}
