/// 每日提醒的调度契约（PRD Tab4 P1）。
///
/// 放在领域层，让 `application` 只依赖抽象——与 [EntryRepository] 等一致。
/// 抽成接口还有一个实际好处：桌面端与测试可以注入 [NoopReminderService]，
/// 上层不必为「这台设备能不能发通知」写分支。
abstract interface class ReminderService {
  /// 请求通知权限。返回是否已获授权。
  Future<bool> requestPermission();

  /// 安排每天 [hour]:[minute] 的提醒（本地时间）。重复调用会覆盖旧的。
  Future<void> scheduleDaily({required int hour, required int minute});

  /// 取消提醒。
  Future<void> cancel();
}

/// 什么都不做的实现。
///
/// 用于平台不支持通知、或调用方不关心提醒的场景。它不抛异常，
/// 因此上层不需要为了「提醒功能是否可用」写分支。
class NoopReminderService implements ReminderService {
  const NoopReminderService();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleDaily({required int hour, required int minute}) async {}

  @override
  Future<void> cancel() async {}
}
