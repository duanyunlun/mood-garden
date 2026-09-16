import 'package:flutter/material.dart';

/// 全局色板。
///
/// 严格对齐 PRD 第 11.1 章「色系」的四个基准色：
///
/// | 基准色     | 应用场景                                             |
/// |-----------|-----------------------------------------------------|
/// | 奶油白     | 整体背景基底色，营造干净、柔和、治愈的视觉基调           |
/// | 暖橘黄     | 开心事记录相关元素、花朵主色调，传达温暖、积极的情绪联想   |
/// | 雾雾灰粉   | 不开心事记录相关元素、纸卷主色调，传达柔和、安全的释放氛围 |
/// | 鼠尾草绿   | 点缀色，用于叶片、花园背景细节，平衡活力与自然感          |
///
/// 命名约定：
/// - `xxx`     基准色，用于主视觉与关键控件
/// - `xxxDeep` 加深变体，用于按压态、描边、强调文字
/// - `xxxSoft` 减淡变体，用于填充块、标签底色
/// - `xxxTint` 极浅变体，用于大面积容器背景
///
/// 设计约束（PRD 11.3）：避免直角与锐利边缘，弱化数据化、工具化的视觉语言。
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // 奶油白 —— 整体背景基底色
  // ---------------------------------------------------------------------------

  /// 页面基底背景色。
  static const Color creamWhite = Color(0xFFFFFBF2);

  /// 卡片 / 面板背景色，比基底略暖，形成柔和的层次感。
  static const Color creamSoft = Color(0xFFFFF6E9);

  /// 分隔线与浅描边色。
  static const Color creamDeep = Color(0xFFF2E7D8);

  // ---------------------------------------------------------------------------
  // 暖橘黄 —— 开心事 / 花朵主色调
  // ---------------------------------------------------------------------------

  /// 品牌主色，用于「种下开心事」主入口、花朵主色、选中态。
  static const Color warmApricot = Color(0xFFF2A65A);

  /// 加深变体，用于按压态与强调文字。
  static const Color warmApricotDeep = Color(0xFFD98B3F);

  /// 减淡变体，用于标签底色、次级按钮填充。
  static const Color warmApricotSoft = Color(0xFFFDE8CE);

  /// 极浅变体，用于大面积暖色容器背景。
  static const Color warmApricotTint = Color(0xFFFFF3E2);

  // ---------------------------------------------------------------------------
  // 雾雾灰粉 —— 不开心事 / 纸卷主色调
  // ---------------------------------------------------------------------------

  /// 纸卷与负向情绪记录的主色。
  ///
  /// 刻意避开常见的沉重灰暗色，传达「柔和、安全的释放氛围」（PRD 11.1）。
  static const Color mistyRose = Color(0xFFD3AFAD);

  /// 加深变体，用于「点燃引信」按钮与纸卷描边。
  static const Color mistyRoseDeep = Color(0xFFB8908E);

  /// 减淡变体，用于纸卷纹理底色。
  static const Color mistyRoseSoft = Color(0xFFF2E3E2);

  /// 极浅变体，用于纸卷页面的大面积背景。
  static const Color mistyRoseTint = Color(0xFFF9F0EF);

  // ---------------------------------------------------------------------------
  // 鼠尾草绿 —— 点缀色
  // ---------------------------------------------------------------------------

  /// 点缀色，用于叶片、花园背景细节、成长进度指示。
  static const Color sageGreen = Color(0xFFA3B899);

  /// 加深变体，用于叶片描边与成功态。
  static const Color sageGreenDeep = Color(0xFF7F9873);

  /// 减淡变体，用于叶片填充与浅色标签。
  static const Color sageGreenSoft = Color(0xFFE2EADD);

  /// 极浅变体，用于花园土壤与草地背景。
  static const Color sageGreenTint = Color(0xFFEFF4EC);

  // ---------------------------------------------------------------------------
  // 中性色 —— 文字与结构
  // ---------------------------------------------------------------------------

  /// 主文字色。使用暖棕黑而非纯黑，保持柔和基调。
  static const Color inkPrimary = Color(0xFF4A4038);

  /// 次级文字色，用于说明文案与副标题。
  static const Color inkSecondary = Color(0xFF8A7C70);

  /// 三级文字色，用于占位符与禁用态。
  static const Color inkTertiary = Color(0xFFB3A79C);

  /// 深色背景上的反白文字色。
  static const Color inkInverse = Color(0xFFFFFBF2);

  /// 通用分隔线。
  static const Color divider = Color(0xFFF0E5D7);

  // ---------------------------------------------------------------------------
  // 语义色 —— 机制专属
  // ---------------------------------------------------------------------------

  /// 灰烬色。纸卷燃烧后灰烬的视觉色（PRD 7.2.2）。
  static const Color ash = Color(0xFF9E958C);

  /// 灰烬浅色，用于「已转化为养分」封条背景（PRD 7.2.3）。
  static const Color ashSoft = Color(0xFFEDE8E3);

  /// 养分值色。养分进度条与养分数值的专属金色（PRD 7.3）。
  static const Color nutrientGold = Color(0xFFE8B84B);

  /// 燃烧火苗色。点燃动画的火焰主色（PRD 7.2.2）。
  static const Color flame = Color(0xFFE8763C);

  /// 土壤色。花园土壤与种子入土动画的基底色（PRD 7.1.2）。
  static const Color soil = Color(0xFFB99B7C);

  // ---------------------------------------------------------------------------
  // 阴影
  // ---------------------------------------------------------------------------

  /// 卡片柔和投影。低透明度暖色阴影，避免生硬的灰黑投影。
  static const Color shadowSoft = Color(0x14A98E6B);

  /// 悬浮元素投影，用于主入口按钮与弹层。
  static const Color shadowMedium = Color(0x24A98E6B);
}
