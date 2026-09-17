import 'package:flutter/material.dart';

/// 全局色板。
///
/// 取值来自原型 v5（`docs/心情花园-原型-v5-单文件版.html`），
/// 并按 WCAG 相对亮度公式校正到 AA（4.5:1）。
///
/// ## 原型教给我们的一件事：填充色与文字色必须分开
///
/// 原型把橙色拆成了三个令牌——`--orange`（填充）、`--orange-deep`（强调）、
/// `--orange-text`（**用于文字**）。这不是冗余，而是必需的：
/// 暖橘黄 `#FFB74D` 在奶油底上只有 **1.66:1**，它天生只能当填充，不能当文字。
///
/// 本项目把这条约定固化下来：
///
/// | 令牌后缀 | 用途 | 能否当文字 |
/// | --- | --- | --- |
/// | （无） | 基准填充色 | ❌ 对比度不足，只做色块 |
/// | `Soft` / `Tint` | 浅底填充 | ❌ 同上 |
/// | `Deep` | **文字与图标** | ✅ 已校正到 AA |
///
/// 命名沿用原型语义，`test/unit/color_contrast_test.dart` 会逐对断言。
///
/// ## 另一个结论：深奶油底上放不下第三级文字
///
/// 在 `creamSoft`（`#FCEFDF`）上，任何比 `inkSecondary` 更浅的文字都低于 4.5:1。
/// 因此这里只有**两级**承载信息的文字色（`inkPrimary` / `inkSecondary`），
/// 层次靠字号与字重去拉；`inkTertiary` 只服务禁用态与装饰。
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // 奶油白 —— 整体背景基底色（原型 --cream / --cream-deep）
  // ---------------------------------------------------------------------------

  /// 页面基底背景色。
  static const Color creamWhite = Color(0xFFFFF9F2);

  /// 卡片 / 面板背景色。
  static const Color creamSoft = Color(0xFFFCEFDF);

  /// 再深一档，用于分隔线与浅描边。
  static const Color creamDeep = Color(0xFFF5E3D0);

  // ---------------------------------------------------------------------------
  // 暖橘黄 —— 开心事 / 花朵（原型 --orange / --orange-deep / --orange-text）
  // ---------------------------------------------------------------------------

  /// 品牌主色。**只做填充**：在奶油底上仅 1.66:1。
  static const Color warmApricot = Color(0xFFFFB74D);

  /// 浅填充，用于标签底色与次级强调块。
  ///
  /// 它必须**足够浅**：深暖色文字压在其上要达 AA，实测下限约为 `#FFF1DE`。
  /// 调深这个底就等于牺牲压在它上面的文字的可读性。
  static const Color warmApricotSoft = Color(0xFFFFF1DE);

  /// 极浅填充，用于大面积暖色容器。
  static const Color warmApricotTint = Color(0xFFFFF3E0);

  /// 暖色文字与图标。
  ///
  /// 对应原型 `--orange-text`，并把它的 `#B5651D` 从 4.15:1 校正到
  /// **奶油底 4.93:1 / 深奶油底 4.56:1**，两处都达 AA。
  static const Color warmApricotDeep = Color(0xFFA85815);

  // ---------------------------------------------------------------------------
  // 雾雾灰粉 —— 不开心事 / 纸卷（原型 --pink-deep）
  // ---------------------------------------------------------------------------

  /// 纸卷与负向情绪记录的主色。**只做填充**。
  static const Color mistyRose = Color(0xFFD9B9AE);

  /// 浅填充。
  static const Color mistyRoseSoft = Color(0xFFF9EBE7);

  /// 极浅填充，用于纸卷页面的大面积背景。
  static const Color mistyRoseTint = Color(0xFFFBF0EC);

  /// 灰粉文字与图标。奶油底 **5.07:1** / 深奶油底 4.68:1。
  static const Color mistyRoseDeep = Color(0xFF87635A);

  // ---------------------------------------------------------------------------
  // 鼠尾草绿 —— 点缀（原型 --sage）
  // ---------------------------------------------------------------------------

  /// 点缀色，用于叶片与花园背景细节。**只做填充**。
  static const Color sageGreen = Color(0xFFA9C7A0);

  /// 浅填充。
  static const Color sageGreenSoft = Color(0xFFEDF4EA);

  /// 极浅填充，用于花园土壤与草地背景。
  static const Color sageGreenTint = Color(0xFFF1F6EE);

  /// 绿色文字与图标。奶油底 **5.04:1** / 深奶油底 4.66:1。
  static const Color sageGreenDeep = Color(0xFF587350);

  // ---------------------------------------------------------------------------
  // 中性色 —— 文字与结构（原型 --ink / --ink-light）
  // ---------------------------------------------------------------------------

  /// 主文字色。对应原型 `--ink`，奶油底 **8.46:1**。
  static const Color inkPrimary = Color(0xFF5B4636);

  /// 次级文字色，用于说明文案、正文与所有小字。
  ///
  /// 对应原型 `--ink-light`，但把它的 `#A08D7C`（3.05:1）校正到
  /// **奶油底 5.05:1 / 深奶油底 4.67:1**——原值只够大字，用来写说明会发虚。
  static const Color inkSecondary = Color(0xFF7C6857);

  /// 三级文字色。**只用于禁用态与纯装饰**，不承载信息。
  ///
  /// 保留原型的 `--ink-light` 原值：约 3.05:1，故意留浅——
  /// 否则「禁用」看起来会像「可用」。需要传达信息的场景请用 [inkSecondary]。
  static const Color inkTertiary = Color(0xFFA08D7C);

  /// 深色背景上的反白文字色。
  static const Color inkInverse = Color(0xFFFFF9F2);

  /// 通用分隔线。
  static const Color divider = Color(0xFFF1E4D5);

  // ---------------------------------------------------------------------------
  // 语义色 —— 机制专属
  // ---------------------------------------------------------------------------

  /// 灰烬色。同时用作封条文字，在 [ashSoft] 上 5.84:1。
  static const Color ash = Color(0xFF5F574F);

  /// 灰烬浅色，用于「已转化为养分」封条背景。
  static const Color ashSoft = Color(0xFFEDE8E3);

  /// 养分值色。用于养分进度条与金色养分数值。
  static const Color nutrientGold = Color(0xFFE8B84B);

  /// 燃烧火苗色。**只做填充与描边**：深色文字压在其上仅 3.40:1，
  /// 因此点燃按钮的底色始终保持在浅色区间（见 `ignite_button.dart`）。
  static const Color flame = Color(0xFFE8763C);

  /// 土壤色。花园土壤与种子入土动画的基底色。
  static const Color soil = Color(0xFFB99B7C);

  // ---------------------------------------------------------------------------
  // 阴影（原型 --shadow: 0 8px 24px rgba(139,111,82,0.15)）
  // ---------------------------------------------------------------------------

  /// 卡片柔和投影。
  static const Color shadowSoft = Color(0x268B6F52);

  /// 悬浮元素投影，用于主入口按钮与弹层。
  static const Color shadowMedium = Color(0x3D8B6F52);
}
