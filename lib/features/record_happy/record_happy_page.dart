import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/mood_garden_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/soft_card.dart';
import 'widgets/mood_tag_selector.dart';
import 'widgets/seed_landing_overlay.dart';

/// 记录开心事页（PRD 7.1.1 输入流程）。
///
/// 严格实现 PRD 的五步流程：
/// 1. 从花园首页「种下开心事」主入口进入（由 `AppRouter` 负责）；
/// 2. 文字输入 + 图片输入（相册选择 / 拍照，支持多图）；
/// 3. 选择一个心情标签，标签与花种一一对应；
/// 4. 日期时间可编辑（支持补记过去某天的开心事）；
/// 5. 点击保存，触发种子落地反馈动画。
class RecordHappyPage extends StatefulWidget {
  const RecordHappyPage({super.key});

  @override
  State<RecordHappyPage> createState() => _RecordHappyPageState();
}

class _RecordHappyPageState extends State<RecordHappyPage> {
  final TextEditingController _textController = TextEditingController();

  String? _selectedTagId;
  DateTime _occurredAt = DateTime.now();
  bool _isSaving = false;

  /// 正在播放种子落地动画。
  bool _isLanding = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool get _hasContent =>
      _textController.text.trim().isNotEmpty || _selectedTagId != null;

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(now.year - 5),
      // 不允许选择未来日期：记录的是已经发生的事
      lastDate: now,
      helpText: '选择这一天',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
      helpText: '选择时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _occurredAt.hour,
        time?.minute ?? _occurredAt.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_selectedTagId == null) {
      _toast('先选一个心情标签吧，它会决定种下什么花');
      return;
    }
    if (!_hasContent) {
      _toast('写点什么，或者至少选一个标签');
      return;
    }

    setState(() => _isSaving = true);

    final controller = context.read<MoodGardenController>();

    try {
      final result = await controller.plantSeed(
        tagId: _selectedTagId!,
        text: _textController.text.trim(),
        occurredAt: _occurredAt,
      );

      if (!mounted) {
        return;
      }

      // 步骤 5 + 7.1.2：播放种子落地反馈动画
      setState(() => _isLanding = true);
      await Future<void>.delayed(SeedLandingOverlay.totalDuration);
      if (!mounted) {
        return;
      }
      setState(() => _isLanding = false);

      // 步骤 8：展示该花种当前收集进度提示
      await _showProgressDialog(result);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// 收集进度提示（PRD 7.1.2）。
  ///
  /// 文案示例：「向日葵第 7 颗种子，再种 3 颗会长出第一朵花」——
  /// 强化用户对「持续记录 = 持续收获」的心理预期。
  Future<void> _showProgressDialog(PlantSeedResult result) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.creamWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              result.species.emoji,
              style: const TextStyle(fontSize: 46),
            ),
            const SizedBox(height: 14),
            Text(
              '种子已经入土',
              style: Theme.of(dialogContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              '${result.species.name}第 ${result.totalSeedsOfSpecies} 颗种子，'
              '再种 ${result.seedsUntilNextBloom} 颗会长出下一朵花',
              textAlign: TextAlign.center,
              style: Theme.of(dialogContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: AppColors.warmApricotTint,
                borderRadius: BorderRadius.circular(AppTheme.pillRadius),
              ),
              child: Text(
                '花园养分 +${result.nutrientGained}',
                style: Theme.of(dialogContext).textTheme.labelMedium?.copyWith(
                      color: AppColors.warmApricotDeep,
                    ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        title: const Text('种下开心事'),
        leading: IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Stack(
        children: <Widget>[
          ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              6,
              AppTheme.pagePadding,
              120,
            ),
            children: <Widget>[
              Text(
                '记下今天让你觉得「谢谢，真好呀」的小事。\n不用写很多，一句话就够。',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 18),

              // 步骤 2：文字输入
              SoftCard(
                child: TextField(
                  controller: _textController,
                  maxLines: 6,
                  minLines: 4,
                  maxLength: AppConstants.maxTextLength,
                  onChanged: (_) => setState(() {}),
                  style: textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: '今天有什么让你觉得，真好呀？',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    counterStyle: textTheme.labelSmall,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 步骤 2：图片输入
              const _ImagePickerStub(),

              const SizedBox(height: 22),

              // 步骤 3：心情标签
              const SectionHeader(
                title: '这是什么心情？',
                emoji: '🏷️',
                subtitle: '标签决定种下什么花',
              ),
              const SizedBox(height: 12),
              MoodTagSelector(
                selectedId: _selectedTagId,
                onSelected: (id) => setState(() => _selectedTagId = id),
              ),

              const SizedBox(height: 22),

              // 步骤 4：日期时间可编辑
              const SectionHeader(
                title: '什么时候的事？',
                emoji: '🗓️',
                subtitle: '想起了过去某天的事，也可以补记',
              ),
              const SizedBox(height: 12),
              SoftCard(
                onTap: _pickDateTime,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            DateFormatter.friendlyDay(_occurredAt),
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${DateFormatter.fullDate(_occurredAt)} · '
                            '${DateFormatter.weekdayWithTime(_occurredAt)}',
                            style: textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.edit_calendar_outlined,
                      size: 20,
                      color: AppColors.inkTertiary,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 步骤 5：保存后播放种子落地动画（PRD 7.1.2）
          if (_isLanding)
            Positioned.fill(
              child: SeedLandingOverlay(
                emoji: _selectedTagId == null
                    ? '🌱'
                    : (MoodTagSelectorEmoji.of(_selectedTagId!)),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          AppTheme.pagePadding,
          8,
          AppTheme.pagePadding,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        child: FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? '正在种下…' : '种下这颗种子'),
        ),
      ),
    );
  }
}

/// 标签 emoji 查表助手。
///
/// 放在此处避免在页面里直接依赖 `MoodTag` 的完整对象。
abstract final class MoodTagSelectorEmoji {
  static String of(String tagId) {
    for (final tag in _presets) {
      if (tag.$1 == tagId) {
        return tag.$2;
      }
    }
    return '🌱';
  }

  static const List<(String, String)> _presets = <(String, String)>[
    ('gratitude', '🌻'),
    ('surprise', '🌷'),
    ('companionship', '💜'),
    ('achievement', '🌾'),
    ('food', '🌸'),
    ('calm', '🍀'),
  ];
}

/// 图片选择占位组件（PRD 7.1.1 步骤 2：相册选择 / 拍照，支持多图）。
///
/// ⚠️ 骨架期未接入 `image_picker`，点击仅提示。
/// 正式实现需要同时解决「图片加密存储」问题（PRD 第 10 章），
/// 因此这里刻意留白而不做半成品实现。
class _ImagePickerStub extends StatelessWidget {
  const _ImagePickerStub();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SoftCard(
      onTap: () {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('图片选择待接入相册权限与加密存储后开放'),
            ),
          );
      },
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: <Widget>[
          const Text('🖼️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('加张照片', style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '最多 ${AppConstants.maxImagesPerEntry} 张',
                  style: textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.add_circle_outline,
            size: 22,
            color: AppColors.warmApricot,
          ),
        ],
      ),
    );
  }
}
