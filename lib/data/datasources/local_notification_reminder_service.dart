import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/repositories/reminder_service.dart';

/// 基于 `flutter_local_notifications` 的实现。
class LocalNotificationReminderService implements ReminderService {
  LocalNotificationReminderService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// 固定的通知 id：重复安排时覆盖旧的，不会堆出一串提醒。
  static const int notificationId = 1001;

  /// Android 通知渠道 id。
  static const String channelId = 'mood_garden_daily_reminder';

  final FlutterLocalNotificationsPlugin _plugin;

  bool _ready = false;

  @override
  Future<bool> requestPermission() async {
    await _ensureReady();

    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    final macOS = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    if (macOS != null) {
      return await macOS.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return false;
  }

  @override
  Future<void> scheduleDaily({required int hour, required int minute}) async {
    await _ensureReady();
    await cancel();

    await _plugin.zonedSchedule(
      id: notificationId,
      title: '来看看你的花园',
      body: _reminderBody(),
      scheduledDate: _nextOccurrence(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          '每日提醒',
          channelDescription: '温柔地提醒你记录今天的心情',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      // 刻意用 inexact 而不是 exact：日记提醒早几分钟晚几分钟都无所谓，
      // 而 exact 需要 SCHEDULE_EXACT_ALARM 权限——那个权限是给闹钟和日历用的，
      // 用在这里既浪费又会在部分应用商店触发额外审核。
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // 每天同一时刻重复。
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancel() => _plugin.cancel(id: notificationId);

  /// 初始化时区与插件。只做一次。
  Future<void> _ensureReady() async {
    if (_ready) {
      return;
    }

    tz_data.initializeTimeZones();
    await _useDeviceTimezone();

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // 权限在用户真正打开开关时才请求，不在启动时就弹框。
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    _ready = true;
  }

  /// 把 `timezone` 的本地时区设成设备真实时区。
  ///
  /// 不做这一步，`tz.local` 默认是 UTC，提醒会在完全不对的时间响——
  /// 这是这类功能最常见也最难当场发现的 bug。
  Future<void> _useDeviceTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // 平台返回了时区库里没有的名字时保持默认，至少不崩溃。
      // 真正的影响是提醒时刻可能偏移，会在「我的 → 每日提醒」里显示出来。
    }
  }

  /// 下一次该响的时刻。若今天这个点已过，则顺延到明天。
  tz.TZDateTime _nextOccurrence(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    final today = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  }

  /// 提醒文案。
  ///
  /// PRD 要求「温柔而不打扰」，所以刻意不写「你已经 N 天没记录了」
  /// 这类带催促和亏欠感的句子——那正是打卡类产品的语气。
  static String _reminderBody() {
    const lines = <String>[
      '今天有什么让你觉得「谢谢，真好呀」的小事吗？',
      '花园里还有一块空地，等你种下今天的好心情。',
      '不开心的事也可以写下来烧掉，它会变成养分。',
      '来看看你的花，它们又长大了一点。',
    ];
    return lines[DateTime.now().day % lines.length];
  }
}
