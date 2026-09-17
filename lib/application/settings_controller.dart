import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/id_generator.dart';
import '../domain/entities/app_settings.dart';
import '../domain/entities/flower_species.dart';
import '../domain/entities/mood_tag.dart';
import '../domain/repositories/reminder_service.dart';
import '../domain/repositories/settings_repository.dart';

/// 设置控制器。
///
/// 与 `MoodGardenController` 分开，是因为两者关注点不同：
/// 前者管「用户希望怎么用这个 App」，后者管「花园里发生了什么」。
/// `docs/ARCHITECTURE.md` 第 3 节预告过这次拆分——当设置类功能真正接入时，
/// 继续塞进主控制器会让它同时承担两件不相关的事。
class SettingsController extends ChangeNotifier {
  SettingsController({
    required SettingsRepository repository,
    ReminderService reminder = const NoopReminderService(),
  })  : _repository = repository,
        _reminder = reminder;

  final SettingsRepository _repository;
  final ReminderService _reminder;

  bool _isLoading = true;
  AppSettings _settings = AppSettings.defaults;

  bool get isLoading => _isLoading;
  AppSettings get settings => _settings;

  /// 应用内字体缩放，供 `MaterialApp.builder` 读取。
  double get textScale => _settings.textScale;

  /// 预设 + 自定义，界面上一律用这个列表。
  List<MoodTag> get allTags => _settings.allTags;

  /// 从存储加载。App 启动时调用一次。
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    try {
      _settings = await _repository.load();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 无障碍：字体大小（PRD 第 10 章）
  // ---------------------------------------------------------------------------

  /// 调整应用内字体缩放。会被夹到合法区间内。
  Future<void> setTextScale(double scale) async {
    final clamped = scale.clamp(
      AppConstants.textScaleMin,
      AppConstants.textScaleMax,
    );
    if (clamped == _settings.textScale) {
      return;
    }
    await _update(_settings.copyWith(textScale: clamped));
  }

  // ---------------------------------------------------------------------------
  // 快捷标签管理（PRD Tab4）
  // ---------------------------------------------------------------------------

  /// 新增一个自定义标签。
  ///
  /// 返回新标签；标签名为空时返回 `null`（调用方据此提示用户）。
  /// 同名标签也拒绝，避免选择器里出现两个看起来一样的选项。
  Future<MoodTag?> addCustomTag({
    required String label,
    required String emoji,
    required String speciesId,
  }) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (_settings.allTags.any((tag) => tag.label == trimmed)) {
      return null;
    }

    final tag = MoodTag(
      id: IdGenerator.next(MoodTagId.customPrefix),
      label: trimmed,
      emoji: emoji,
      speciesId: speciesId,
      isCustom: true,
    );

    await _update(
      _settings.copyWith(
        customTags: <MoodTag>[..._settings.customTags, tag],
      ),
    );
    return tag;
  }

  /// 删除一个自定义标签。预设标签不可删。
  Future<void> removeCustomTag(String id) async {
    final next = _settings.customTags
        .where((tag) => tag.id != id)
        .toList(growable: false);
    if (next.length == _settings.customTags.length) {
      return;
    }
    await _update(_settings.copyWith(customTags: next));
  }

  // ---------------------------------------------------------------------------
  // 每日提醒（PRD Tab4 P1）
  // ---------------------------------------------------------------------------

  /// 开关每日提醒，并可同时调整时刻。
  ///
  /// 返回**是否真的生效**：没拿到通知权限时开关不会被记成「已开启」——
  /// 一个显示为开、实际永远不响的开关，比关着更糟。
  Future<bool> setReminder({
    required bool enabled,
    int? hour,
    int? minute,
  }) async {
    final hour24 = (hour ?? _settings.reminderHour).clamp(0, 23);
    final minute60 = (minute ?? _settings.reminderMinute).clamp(0, 59);

    if (!enabled) {
      await _reminder.cancel();
      await _update(
        _settings.copyWith(
          reminderEnabled: false,
          reminderHour: hour24,
          reminderMinute: minute60,
        ),
      );
      return true;
    }

    final granted = await _reminder.requestPermission();
    if (!granted) {
      // 没授权就不改状态，界面会据此提示用户去系统设置里打开通知。
      return false;
    }

    await _reminder.scheduleDaily(hour: hour24, minute: minute60);
    await _update(
      _settings.copyWith(
        reminderEnabled: true,
        reminderHour: hour24,
        reminderMinute: minute60,
      ),
    );
    return true;
  }

  // ---------------------------------------------------------------------------
  // 仪式音效（PRD 7.2.2）
  // ---------------------------------------------------------------------------

  /// 开关仪式音效。
  Future<void> setSoundEnabled(bool enabled) async {
    if (enabled == _settings.soundEnabled) {
      return;
    }
    await _update(_settings.copyWith(soundEnabled: enabled));
  }

  /// 提醒时刻的展示文案，例如「21:05」。
  String get reminderTimeLabel =>
      '${_settings.reminderHour.toString().padLeft(2, '0')}:'
      '${_settings.reminderMinute.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------------------
  // 共用
  // ---------------------------------------------------------------------------

  /// 清空设置，回到默认值。供「清除全部数据」调用。
  Future<void> reset() async {
    await _repository.clear();
    _settings = AppSettings.defaults;
    notifyListeners();
  }

  Future<void> _update(AppSettings next) async {
    _settings = next;
    await _repository.save(next);
    notifyListeners();
  }
}

/// 自定义标签可选的花种（PRD 7.1.1：标签与花种一一对应）。
///
/// 只列常规花种：进化款与隐藏款应当靠收集解锁，而不是让用户直接指定。
List<FlowerSpecies> get plantableSpecies => FlowerSpecies.catalog
    .where((species) => species.rarity == SpeciesRarity.common)
    .toList(growable: false);
