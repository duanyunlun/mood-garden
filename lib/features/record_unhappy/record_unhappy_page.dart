import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/mood_garden_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/soft_card.dart';
import 'widgets/ash_scatter_overlay.dart';
import 'widgets/ignite_button.dart';
import 'widgets/paper_scroll_card.dart';

/// 纸卷的当前阶段。
enum _BurnPhase {
  /// 编辑中，可自由修改内容。
  editing,

  /// 燃烧动画播放中。
  burning,

  /// 灰烬飘散中。
  scattering,
}

/// 记录不开心事 —— 情绪纸卷页（PRD 7.2.1 输入流程 / 7.2.2 点燃与燃烧）。
///
/// 完整实现 PRD 7.2 的仪式链路：
/// 写入 → 长按点燃 → 火苗蔓延 → 化为灰烬 → 灰烬入土 → 转化为养分。
///
/// 三条刻意的产品约束在本页被显式执行：
/// 1. **没有「放弃/删除」入口**——纸卷只有「点燃」一个出路（PRD 7.2.2：
///    不设置其他分支选项，保持机制单一纯粹，避免在释放这一关键情绪节点上
///    产生决策负担）；
/// 2. **松手不清零**——长按中断只是回退进度，不产生任何副作用，
///    让「划火柴」这件事没有失败感；
/// 3. **燃烧不可逆**——动画结束后立即在模型层擦除原文与图片引用（PRD 7.2.3）。
class RecordUnhappyPage extends StatefulWidget {
  const RecordUnhappyPage({super.key});

  @override
  State<RecordUnhappyPage> createState() => _RecordUnhappyPageState();
}

class _RecordUnhappyPageState extends State<RecordUnhappyPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();

  late final AnimationController _burnController;

  DateTime _occurredAt = DateTime.now();
  _BurnPhase _phase = _BurnPhase.editing;
  int _nutrientGained = 0;

  @override
  void initState() {
    super.initState();
    _burnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _burnController.dispose();
    super.dispose();
  }

  bool get _hasContent => _textController.text.trim().isNotEmpty;

  bool get _isBurning => _phase != _BurnPhase.editing;

  /// 执行点燃流程（PRD 7.2.2 + 7.2.3）。
  Future<void> _ignite() async {
    if (!_hasContent || _isBurning) {
      return;
    }

    final controller = context.read<MoodGardenController>();

    setState(() => _phase = _BurnPhase.burning);

    // 先把当前内容落库为草稿，再由 burnScroll 完成不可逆的擦除结算。
    final draft = await controller.saveScrollDraft(
      text: _textController.text.trim(),
      occurredAt: _occurredAt,
    );

    // 燃烧动画：火苗从纸卷一端吃向另一端
    await _burnController.forward(from: 0);
    if (!mounted) {
      return;
    }

    // 动画播完，执行真正的擦除与养分转化（PRD 7.2.3）
    final result = await controller.burnScroll(draft);
    if (!mounted) {
      return;
    }

    _nutrientGained = result.nutrientGained;
    setState(() => _phase = _BurnPhase.scattering);

    // 灰烬飘入花园土壤
    await Future<void>.delayed(AshScatterOverlay.totalDuration);
    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _pickDateTime() async {
    if (_isBurning) {
      return;
    }
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: '选择这一天',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (date == null || !mounted) {
      return;
    }
    setState(() {
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        _occurredAt.hour,
        _occurredAt.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.mistyRoseTint,
      appBar: AppBar(
        backgroundColor: AppColors.mistyRoseTint,
        title: const Text('情绪纸卷'),
        leading: IconButton(
          icon: const Icon(Icons.close, size: 20),
          // 燃烧开始后不允许中途退出，避免用户错过灰烬入土的反馈
          onPressed: _isBurning
              ? null
              : () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Stack(
        children: <Widget>[
          ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              6,
              AppTheme.pagePadding,
              130,
            ),
            children: <Widget>[
              Text(
                '把不开心的事写下来，然后烧掉它。\n烧完之后内容不会留下，只会变成花园的养分。',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 18),

              // 纸卷本体（PRD 7.2.1 步骤 2：做旧纹理造型）
              Stack(
                children: <Widget>[
                  AnimatedBuilder(
                    animation: _burnController,
                    builder: (context, child) {
                      return PaperScrollCard(
                        rollProgress: _burnController.value,
                        child: child!,
                      );
                    },
                    child: _ScrollContent(
                      controller: _textController,
                      enabled: !_isBurning,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  // 燃烧时的火苗遮罩
                  if (_phase == _BurnPhase.burning)
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _burnController,
                        builder: (context, _) => BurningFlame(
                          progress: _burnController.value,
                          height: 320,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 22),

              const SectionHeader(
                title: '什么时候的事？',
                emoji: '🗓️',
              ),
              const SizedBox(height: 12),
              SoftCard(
                onTap: _pickDateTime,
                color: Colors.white,
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
                            DateFormatter.weekdayWithTime(_occurredAt),
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

              const SizedBox(height: 18),

              // 机制说明：用温和的方式解释「为什么烧掉就看不到了」
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.ashSoft,
                  borderRadius: BorderRadius.circular(AppTheme.controlRadius),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('🕊️', style: TextStyle(fontSize: 17)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '烧掉之后，这段文字不会被保存，也不会出现在时光轴里。'
                        '你只会看到一句「已转化为养分」——'
                        '没有一种情绪是被浪费的。',
                        style: textTheme.labelSmall?.copyWith(height: 1.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 灰烬飘散（PRD 7.2.2 步骤 8）
          if (_phase == _BurnPhase.scattering)
            Positioned.fill(
              child: AshScatterOverlay(nutrientGained: _nutrientGained),
            ),
        ],
      ),
      bottomNavigationBar: _isBurning
          ? null
          : Padding(
              padding: EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                8,
                AppTheme.pagePadding,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: IgniteButton(
                enabled: _hasContent,
                onCompleted: _ignite,
              ),
            ),
    );
  }
}

/// 纸卷内部内容：文字输入 + 图片占位。
class _ScrollContent extends StatelessWidget {
  const _ScrollContent({
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '写给自己的话',
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.mistyRoseDeep,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: 10,
          minLines: 7,
          maxLength: AppConstants.maxTextLength,
          onChanged: (_) => onChanged(),
          style: textTheme.bodyLarge?.copyWith(height: 1.9),
          decoration: InputDecoration(
            hintText: '发生了什么？当时是什么感觉？\n写下来就好，不用修饰。',
            hintStyle: textTheme.bodyMedium?.copyWith(
              color: AppColors.mistyRose.withValues(alpha: 0.8),
              height: 1.9,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            filled: false,
            counterStyle: textTheme.labelSmall,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            const Text('🖼️', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 7),
            Text(
              '图片（待接入相册与加密存储）',
              style: textTheme.labelSmall,
            ),
          ],
        ),
      ],
    );
  }
}
