import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/mood_garden_controller.dart';
import '../../application/settings_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/tag_catalog.dart';
import '../../shared/sound_feedback.dart';
import '../../shared/widgets/entry_image_field.dart';
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

  /// 选中的标签（含花种）。进化款、隐藏款、自定义标签的花种都由它携带。
  SelectableTag? _selectedTag;
  DateTime _occurredAt = DateTime.now();
  bool _isSaving = false;

  /// 用户新选的图片字节。保存时才交给控制器加密落盘。
  List<Uint8List> _images = <Uint8List>[];

  /// 正在播放种子落地动画。
  bool _isLanding = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool get _hasContent =>
      _textController.text.trim().isNotEmpty || _selectedTag != null;

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
    final selected = _selectedTag;
    if (selected == null) {
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
        tagId: selected.tag.id,
        // 显式带上花种：进化款与自定义标签的对应关系不在预设表里。
        speciesId: selected.tag.speciesId,
        text: _textController.text.trim(),
        images: _images,
        occurredAt: _occurredAt,
      );

      if (!mounted) {
        return;
      }

      // 声音与动画同时起：种子入土这一下要有回响（PRD 7.2.2 的「轻音效」）
      playFeedback(context, (player) => player.playSeedLanded());

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

  /// 收集进度提示（PRD 7.1.2 + 7.1.3）。
  ///
  /// 文案示例：「向日葵第 7 颗种子，再种 3 颗会长出第一朵花」——
  /// 强化用户对「持续记录 = 持续收获」的心理预期。
  ///
  /// 若这一次恰好凑够阈值，额外给一段解锁提示：**解锁了却不说，
  /// 等于没解锁**——用户根本不会知道图鉴里多了一种花。
  Future<void> _showProgressDialog(PlantSeedResult result) {
    final unlocked = result.unlockedSpecies;

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
              result.flower != null
                  ? (result.bloomedSpecies?.emoji ?? result.species.emoji)
                  : (result.petalEarned ? '🌸' : result.species.emoji),
              style: const TextStyle(fontSize: 46),
            ),
            const SizedBox(height: 14),
            Text(
              _feedbackTitle(result, unlocked.isNotEmpty),
              style: Theme.of(dialogContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              _feedbackDetail(result),
              textAlign: TextAlign.center,
              style: Theme.of(dialogContext).textTheme.bodyMedium,
            ),
            if (unlocked.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.sageGreenTint,
                  borderRadius: BorderRadius.circular(AppTheme.controlRadius),
                ),
                child: Column(
                  children: <Widget>[
                    for (final species in unlocked) ...<Widget>[
                      Text(
                        '${species.emoji} 解锁了${species.name}',
                        style: Theme.of(dialogContext)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: AppColors.sageGreenDeep),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '同类心情攒够了，下次记录可以选它的进化形态',
                        textAlign: TextAlign.center,
                        style: Theme.of(dialogContext).textTheme.labelSmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
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
    // 标签列表要同时看花园进度（进化款 / 隐藏款是否解锁）与设置（自定义标签），
    // 所以两个控制器都要订阅。
    final controller = context.watch<MoodGardenController>();
    final settings = context.watch<SettingsController>();
    final selected = _selectedTag;

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

              // 步骤 2：文字输入 + 图片输入
              // 两者放在同一张卡片里：它们共同构成「这次记录」，
              // 拆成两张卡会让页面读起来像两个无关的表单。
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextField(
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
                    const SizedBox(height: 12),
                    EntryImageField(
                      images: _images,
                      onChanged: (images) => setState(() => _images = images),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // 步骤 3：心情标签
              const SectionHeader(
                title: '这是什么心情？',
                emoji: '🏷️',
                subtitle: '标签决定种下什么花',
              ),
              const SizedBox(height: 12),
              MoodTagSelector(
                // 可选标签由花园进度推导：进化款、隐藏款、季节可用性都在里面。
                // 自定义标签来自设置，因此这里要把两个来源合起来。
                tags: controller.availableTags(
                  customTags: settings.settings.customTags,
                ),
                selectedId: _selectedTag?.tag.id,
                onSelected: (item) => setState(() => _selectedTag = item),
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
                emoji: selected?.tag.species?.emoji ?? '🌱',
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
          child: Text(_isSaving ? '正在种下…' : '收进花园'),
        ),
      ),
    );
  }
}

/// 反馈标题。对应原型记录流程的三种结果：小确幸 / 花瓣 / 绽放。
///
/// 一次记录只会有三种结局之一，且**大多数记录属于第一种**——
/// 按原型的规则，一天要记满 3 件才产出一片花瓣。
/// 因此这里绝不能把「没得到花瓣」写成遗憾的口气。
String _feedbackTitle(PlantSeedResult result, bool evolved) {
  if (evolved) {
    return '它进化了';
  }
  if (result.flower != null) {
    return '开出了一朵花';
  }
  if (result.petalEarned) {
    return '收获了一片花瓣';
  }
  return '记下了一件小确幸';
}

/// 反馈正文。始终告诉用户**下一步还差多少**，而不是只报一个结果。
String _feedbackDetail(PlantSeedResult result) {
  if (result.flower != null) {
    final name = result.bloomedSpecies?.name ?? result.species.name;
    return '$name 绽放了。花苞重新开始攒，再攒 '
        '${AppConstants.petalsPerBloom} 片又是一朵。';
  }
  if (result.petalEarned) {
    return '花苞拼合 ${result.budProgress}/${AppConstants.petalsPerBloom} · '
        '再攒 ${result.petalsUntilBloom} 片，就拼成一朵花';
  }
  return '再记 ${result.thingsUntilPetal} 件，今天就能收获一片花瓣';
}
