import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 灰烬飘散动画（PRD 7.2.2 步骤 8 / 7.2.3）。
///
/// PRD 原文：
/// > 燃烧完成后，灰烬以飘散动画的形式飘入花园土壤——这是灰烬唯一的归宿，
/// > 不设置「随风飘散消失」等其他分支选项，保持机制单一纯粹。
///
/// 因此本动画的粒子**有明确的目的地**：全部向下飘向土壤，没有一个向上散开。
/// 这不是美术选择，而是机制表达——灰烬不会消失，它会变成养分。
///
/// ⚠️ 骨架期用确定性伪随机粒子实现，正式版替换为序列帧动画资源。
class AshScatterOverlay extends StatefulWidget {
  const AshScatterOverlay({
    required this.nutrientGained,
    super.key,
  });

  /// 本次转化获得的养分值。动画尾声展示，完成「灰烬 → 养分」的语义闭环。
  final int nutrientGained;

  /// 动画总时长。
  static const Duration totalDuration = Duration(milliseconds: 1700);

  @override
  State<AshScatterOverlay> createState() => _AshScatterOverlayState();
}

class _AshScatterOverlayState extends State<AshScatterOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// 固定种子，保证每次播放的粒子分布一致（避免闪烁感）。
  final List<_AshParticle> _particles = _buildParticles();

  static List<_AshParticle> _buildParticles() {
    final rng = math.Random(20260316);
    return List<_AshParticle>.generate(26, (index) {
      return _AshParticle(
        startX: rng.nextDouble(),
        delay: rng.nextDouble() * 0.35,
        drift: (rng.nextDouble() - 0.5) * 0.22,
        size: 2.0 + rng.nextDouble() * 3.5,
        spin: (rng.nextDouble() - 0.5) * 6,
      );
    }, growable: false);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AshScatterOverlay.totalDuration,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;

          return ColoredBox(
            color: AppColors.creamWhite.withValues(
              alpha: 0.9 * (t < 0.8 ? 1.0 : (1 - t) / 0.2),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: <Widget>[
                    // 灰烬粒子：全部向下飘入土壤
                    for (final particle in _particles)
                      _buildParticle(particle, t, constraints),

                    // 养分提示
                    if (t > 0.55)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: constraints.maxHeight * 0.16,
                        child: Opacity(
                          opacity: ((t - 0.55) / 0.3).clamp(0.0, 1.0),
                          child: Column(
                            children: <Widget>[
                              const Text(
                                '🕊️',
                                style: TextStyle(fontSize: 34),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '已经变成花园的养分了',
                                style: textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warmApricotTint,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '养分 +${widget.nutrientGained}',
                                  style: textTheme.labelMedium?.copyWith(
                                    color: AppColors.warmApricotDeep,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildParticle(
    _AshParticle particle,
    double t,
    BoxConstraints constraints,
  ) {
    // 每个粒子有各自的延迟，让飘散有先后层次
    final localT = ((t - particle.delay) / (1 - particle.delay)).clamp(0.0, 1.0);
    final eased = Curves.easeInOut.transform(localT);

    // 从纸卷位置（屏幕中部）飘向底部土壤
    final startY = constraints.maxHeight * 0.42;
    final endY = constraints.maxHeight * 0.86;
    final y = startY + (endY - startY) * eased;

    final x = constraints.maxWidth * particle.startX +
        constraints.maxWidth * particle.drift * eased;

    // 飘散过程中逐渐透明、缩小
    final opacity = localT < 0.75 ? 1.0 : (1 - localT) / 0.25;
    final scale = 1.0 - eased * 0.5;

    return Positioned(
      left: x,
      top: y,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: particle.spin * eased,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: particle.size,
              height: particle.size,
              decoration: BoxDecoration(
                color: AppColors.ash.withValues(alpha: 0.75),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 单个灰烬粒子的确定性参数。
class _AshParticle {
  const _AshParticle({
    required this.startX,
    required this.delay,
    required this.drift,
    required this.size,
    required this.spin,
  });

  /// 起始横向位置比例 `0.0 ~ 1.0`。
  final double startX;

  /// 启动延迟比例。
  final double delay;

  /// 横向漂移比例。
  final double drift;

  /// 粒子尺寸。
  final double size;

  /// 旋转弧度。
  final double spin;
}
