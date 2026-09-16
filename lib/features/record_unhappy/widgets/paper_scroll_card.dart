import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 情绪纸卷卡片（PRD 7.2.1 步骤 2）。
///
/// PRD 原文：
/// > 将不开心的事写进纸卷，支持文字 + 图片输入；纸卷 UI 采用做旧纹理造型，
/// > 视觉上区别于开心事记录卡片，强化「待释放」的心理暗示。
///
/// 视觉差异化手段：
/// - 用雾雾灰粉体系而非暖橘黄，与开心事卡片形成明确区分；
/// - 顶部与底部增加卷边造型（[_ScrollEdge]），让矩形读起来像一卷纸；
/// - 内层用极淡的横向纹理线模拟纸张纹路。
///
/// 注意：这里刻意不使用「垃圾桶」「删除」等语义符号，
/// 纸卷的终点是「转化」而不是「丢弃」（PRD 7.2.3 的价值观）。
class PaperScrollCard extends StatelessWidget {
  const PaperScrollCard({
    required this.child,
    super.key,
    this.rollProgress = 0.0,
  });

  /// 纸卷内容。
  final Widget child;

  /// 燃烧进度。`0.0` 为完整纸卷，`1.0` 为完全烧尽。
  final double rollProgress;

  @override
  Widget build(BuildContext context) {
    // 燃烧过程中纸卷整体缩短并变暗
    final shrink = 1.0 - rollProgress * 0.55;

    return Column(
      children: <Widget>[
        const _ScrollEdge(isTop: true),
        ClipRect(
          child: Align(
            heightFactor: shrink.clamp(0.0, 1.0),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Color.lerp(
                  Colors.transparent,
                  AppColors.ash,
                  rollProgress * 0.85,
                )!,
                BlendMode.multiply,
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      AppColors.mistyRoseTint,
                      Color(0xFFF6EBE9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: AppColors.shadowSoft,
                      blurRadius: 16,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Stack(
                  children: <Widget>[
                    // 纸张纹理
                    Positioned.fill(
                      child: CustomPaint(painter: _PaperTexturePainter()),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
                      child: child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const _ScrollEdge(isTop: false),
      ],
    );
  }
}

/// 纸卷的卷边造型。用带阴影的渐变小条模拟卷起的纸边。
class _ScrollEdge extends StatelessWidget {
  const _ScrollEdge({required this.isTop});

  final bool isTop;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 9,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
          end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
          colors: const <Color>[
            Color(0xFFEAD9D7),
            AppColors.mistyRoseSoft,
          ],
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(isTop ? 10 : 3),
          bottom: Radius.circular(isTop ? 3 : 10),
        ),
      ),
    );
  }
}

/// 纸张纹理绘制。极淡的横向线，营造做旧质感（PRD 7.2.1）。
class _PaperTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.mistyRose.withValues(alpha: 0.07)
      ..strokeWidth = 1;

    // 每 26 逻辑像素一条纹理线，间隔足够稀疏才不会显得脏
    for (var y = 26.0; y < size.height; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PaperTexturePainter oldDelegate) => false;
}

/// 燃烧过程中的火苗遮罩（PRD 7.2.2）。
///
/// PRD 原文：
/// > 火苗从纸卷一端「吃」向另一端，纸卷逐帧卷曲、变黑、缩短，
/// > 直至完全化为灰烬，整个过程配合动效与轻音效，营造沉浸式的释放仪式感。
///
/// ⚠️ 骨架期用渐变遮罩模拟火线推进，正式版需替换为序列帧 / Rive 动画资源，
/// 并接入轻音效（当前未接入音频，避免引入 `audioplayers` 依赖）。
class BurningFlame extends StatelessWidget {
  const BurningFlame({
    required this.progress,
    super.key,
    this.height = 60,
  });

  /// 燃烧进度 `0.0 ~ 1.0`。
  final double progress;

  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: Align(
          // 火线自下而上推进：纸从底部开始被吃掉
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: progress.clamp(0.0, 1.0),
            widthFactor: 1.0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    AppColors.flame.withValues(alpha: 0.0),
                    AppColors.flame.withValues(alpha: 0.55),
                    AppColors.ash.withValues(alpha: 0.85),
                  ],
                ),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Color(0xFFFFD9A0),
                        AppColors.flame,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
