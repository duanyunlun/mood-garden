import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

/// 花苞：五片花瓣逐片点亮（原型 v5 `.bud-flower`）。
///
/// 参数直接取自原型的 CSS：
/// - 容器 124×124，花瓣 56×56 绕中心均分（360° / 5 = 72°）；
/// - 未点亮的花瓣 `opacity: .16` + 灰度，点亮后恢复本色；
/// - 中心是 30×30 的金色花芯，一片花瓣都没有时呈空心（`.core.hollow`）。
///
/// 这是「花瓣拼合」这个玩法唯一的可视化：进度条只能告诉你「还差几片」，
/// 而一片片亮起来的花苞能告诉你「已经拼到哪一步了」。
///
/// 花瓣用几何形状绘制而不是插画——插画资源到位后替换 [_PetalShape]
/// 的绘制即可，布局与点亮逻辑不受影响。
class PetalBud extends StatelessWidget {
  const PetalBud({
    required this.lit,
    super.key,
    this.petalColor = AppColors.warmApricot,
    this.total = AppConstants.petalsPerBloom,
  });

  /// 已点亮的花瓣数。
  final int lit;

  /// 花瓣本色。由花种决定（原型：标签决定这片花瓣的颜色）。
  final Color petalColor;

  /// 一个花苞由几片花瓣拼成。
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '花苞拼合 $lit / $total',
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            for (var i = 0; i < total; i++) _positionedPetal(context, i),
            _Core(lit: lit),
          ],
        ),
      ),
    );
  }

  /// 第 [index] 片花瓣：绕中心旋转后向外推，形成花朵的放射排布。
  Widget _positionedPetal(BuildContext context, int index) {
    final angle = (2 * math.pi / total) * index;
    final on = index < lit;

    return Transform.rotate(
      angle: angle,
      child: Transform.translate(
        // 沿旋转后的 Y 轴向外推，五片自然围成一圈。
        offset: const Offset(0, -_petalOrbit),
        child: AnimatedOpacity(
          // 原型的过渡是 .45s ease，这里保持一致，让点亮有「慢慢亮起来」的感觉。
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
          opacity: on ? 1 : 0.16,
          child: _PetalShape(
            color: on ? petalColor : AppColors.inkTertiary,
            size: _petalSize,
          ),
        ),
      ),
    );
  }

  /// 容器边长（原型 `.bud-flower` 124px）。
  static const double _size = 124;

  /// 单片花瓣的包围盒边长（原型 `.petal` 56px）。
  static const double _petalSize = 56;

  /// 花瓣中心到花芯的距离。
  ///
  /// 取 30 是让五片花瓣刚好彼此相接又略有重叠——太小会散成一圈点，
  /// 太大则糊成一团看不出是五片。
  static const double _petalOrbit = 30;
}

/// 单片花瓣的形状。
class _PetalShape extends StatelessWidget {
  const _PetalShape({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Container(
          width: size * 0.52,
          height: size * 0.78,
          decoration: BoxDecoration(
            color: color,
            // 上圆下尖的椭圆：花瓣的基本形态。
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(size * 0.26),
              bottom: Radius.circular(size * 0.12),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: color.withValues(alpha: 0.28),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 中心花芯。一片花瓣都没有时是空心的。
class _Core extends StatelessWidget {
  const _Core({required this.lit});

  final int lit;

  @override
  Widget build(BuildContext context) {
    const size = 30.0;
    final hollow = lit == 0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hollow ? Colors.white.withValues(alpha: 0.55) : null,
        gradient: hollow
            ? null
            : const RadialGradient(
                center: Alignment(-0.24, -0.36),
                colors: <Color>[Color(0xFFFFEEB8), Color(0xFFF0C04A)],
              ),
        border: hollow
            ? Border.all(color: AppColors.warmApricotDeep.withValues(alpha: 0.25), width: 2)
            : null,
        boxShadow: hollow
            ? null
            : const <BoxShadow>[
                BoxShadow(
                  color: AppColors.shadowSoft,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
    );
  }
}
