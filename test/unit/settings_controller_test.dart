import 'package:flutter_test/flutter_test.dart';
import 'package:mood_garden/application/settings_controller.dart';
import 'package:mood_garden/core/constants/app_constants.dart';
import 'package:mood_garden/data/datasources/local_store.dart';
import 'package:mood_garden/data/repositories/local_settings_repository.dart';
import 'package:mood_garden/domain/entities/flower_species.dart';
import 'package:mood_garden/domain/entities/mood_tag.dart';
import 'package:mood_garden/domain/repositories/reminder_service.dart';

/// 可控的提醒服务替身，用来验证「没授权就不算开启」这条规则。
class _FakeReminderService implements ReminderService {
  /// 默认已授权；需要验证未授权路径时在测试里直接改成 false。
  bool granted = true;
  int scheduleCount = 0;
  int cancelCount = 0;
  int? lastHour;
  int? lastMinute;

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<void> scheduleDaily({required int hour, required int minute}) async {
    scheduleCount++;
    lastHour = hour;
    lastMinute = minute;
  }

  @override
  Future<void> cancel() async => cancelCount++;
}

void main() {
  late InMemoryLocalStore store;
  late _FakeReminderService reminder;

  SettingsController buildController() => SettingsController(
        repository: LocalSettingsRepository(store),
        reminder: reminder,
      );

  setUp(() {
    store = InMemoryLocalStore();
    reminder = _FakeReminderService();
  });

  group('加载与持久化', () {
    test('首次加载得到默认设置', () async {
      final controller = buildController();
      await controller.load();

      expect(controller.textScale, 1.0);
      expect(controller.settings.customTags, isEmpty);
      expect(controller.settings.reminderEnabled, isFalse);
      expect(controller.allTags, hasLength(MoodTag.presets.length));
    });

    test('改动会落盘，新实例能读回', () async {
      final first = buildController();
      await first.load();
      await first.setTextScale(1.3);

      final second = buildController();
      await second.load();

      expect(second.textScale, closeTo(1.3, 0.001));
    });
  });

  group('字体大小（无障碍）', () {
    test('超出区间时被夹到边界', () async {
      final controller = buildController();
      await controller.load();

      await controller.setTextScale(5.0);
      expect(controller.textScale, AppConstants.textScaleMax);

      await controller.setTextScale(0.1);
      expect(controller.textScale, AppConstants.textScaleMin);
    });

    test('设成 1.0 表示跟随系统', () async {
      final controller = buildController();
      await controller.load();

      await controller.setTextScale(1.4);
      await controller.setTextScale(1.0);

      expect(controller.textScale, 1.0);
    });
  });

  group('快捷标签管理', () {
    test('新增自定义标签后出现在 allTags 末尾', () async {
      final controller = buildController();
      await controller.load();

      final tag = await controller.addCustomTag(
        label: '散步',
        emoji: '🌙',
        speciesId: FlowerSpeciesId.clover,
      );

      expect(tag, isNotNull);
      expect(tag!.isCustom, isTrue);
      expect(controller.allTags.last.label, '散步');
      expect(controller.allTags.length, MoodTag.presets.length + 1);
    });

    test('空名字被拒绝', () async {
      final controller = buildController();
      await controller.load();

      expect(
        await controller.addCustomTag(
          label: '   ',
          emoji: '🌱',
          speciesId: FlowerSpeciesId.sunflower,
        ),
        isNull,
      );
      expect(controller.settings.customTags, isEmpty);
    });

    test('与已有标签重名被拒绝', () async {
      final controller = buildController();
      await controller.load();

      expect(
        await controller.addCustomTag(
          label: '感恩', // 预设里已有
          emoji: '🌱',
          speciesId: FlowerSpeciesId.sunflower,
        ),
        isNull,
      );
    });

    test('只能删除自定义标签，预设删不掉', () async {
      final controller = buildController();
      await controller.load();
      final tag = await controller.addCustomTag(
        label: '通勤',
        emoji: '🎧',
        speciesId: FlowerSpeciesId.wheat,
      );

      await controller.removeCustomTag(tag!.id);
      expect(controller.settings.customTags, isEmpty);

      // 传预设 id 不会造成任何变化
      await controller.removeCustomTag(MoodTagId.gratitude);
      expect(controller.allTags, hasLength(MoodTag.presets.length));
    });
  });

  group('每日提醒', () {
    test('未授权时不改成已开启，并返回 false', () async {
      reminder.granted = false;
      final controller = buildController();
      await controller.load();

      final ok = await controller.setReminder(enabled: true, hour: 21, minute: 0);

      expect(ok, isFalse);
      expect(
        controller.settings.reminderEnabled,
        isFalse,
        reason: '一个显示为开、实际永远不响的开关比关着更糟',
      );
      expect(reminder.scheduleCount, 0);
    });

    test('授权后保存时刻并真的排期', () async {
      final controller = buildController();
      await controller.load();

      final ok = await controller.setReminder(enabled: true, hour: 8, minute: 30);

      expect(ok, isTrue);
      expect(controller.settings.reminderEnabled, isTrue);
      expect(controller.reminderTimeLabel, '08:30');
      expect(reminder.scheduleCount, 1);
      expect(reminder.lastHour, 8);
      expect(reminder.lastMinute, 30);
    });

    test('关闭会取消已排期的提醒', () async {
      final controller = buildController();
      await controller.load();
      await controller.setReminder(enabled: true, hour: 21, minute: 0);

      await controller.setReminder(enabled: false);

      expect(controller.settings.reminderEnabled, isFalse);
      expect(reminder.cancelCount, 1);
    });

    test('时刻越界会被夹到合法范围', () async {
      final controller = buildController();
      await controller.load();

      await controller.setReminder(enabled: true, hour: 99, minute: 99);

      expect(reminder.lastHour, 23);
      expect(reminder.lastMinute, 59);
    });
  });

  group('重置', () {
    test('reset 后回到默认设置', () async {
      final controller = buildController();
      await controller.load();
      await controller.setTextScale(1.5);
      await controller.addCustomTag(
        label: '夜跑',
        emoji: '🏃',
        speciesId: FlowerSpeciesId.clover,
      );

      await controller.reset();

      expect(controller.textScale, 1.0);
      expect(controller.settings.customTags, isEmpty);
    });
  });
}
