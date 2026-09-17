# 心情花园 · MoodGarden

> **每一种情绪都有价值** —— 开心的事被温柔地收藏，不开心的事被温柔地转化。

面向 iOS 的情绪记录 App（Flutter 实现）。在「感恩日记」的心理学基础上，做了两个关键创新：

1. **开心的事记录后会产生奖赏感** —— 种下一颗花的种子，花会随时间在花园中真实生长；
2. **不开心的事记录后可以「烧掉」释放** —— 烧掉产生的灰烬会转化为花园的养分，反哺让美好的事物长得更好。

两条路径最终汇入同一个「花园养分池」，形成 *无论情绪好坏，都在为花园做贡献* 的正循环闭环。

---

## 目录

- [当前状态](#当前状态)
- [核心机制](#核心机制)
- [隐私机制](#隐私机制不只是不显示)
- [技术栈](#技术栈)
- [快速开始](#快速开始)
- [项目结构](#项目结构)
- [需求映射](#需求映射)
- [架构说明](#架构说明)
- [已知限制](#已知限制)
- [路线图](#路线图)
- [待定事项](#待定事项)

---

## 当前状态

**v0.3.0 · 功能补齐版** —— PRD 第 6～11 章的功能已全部落地：三套核心机制、四个一级 Tab、图片输入、本地加密持久化、进阶收集玩法、搜索筛选、无障碍与音效；静态分析零问题，**204 个测试**全部通过。

✅ **数据会真正落盘且已加密**：密文写入 App 私有目录，主密钥由系统安全区（iOS Keychain / Android Keystore）托管，关闭 App 后记录仍在，存储文件也无法被直接读出明文。详见[隐私机制](#隐私机制不只是不显示)。

| 模块 | 状态 | 说明 |
| --- | --- | --- |
| 工程骨架 | ✅ 完成 | iOS / Android 平台目录、依赖、lint、测试均就绪 |
| 主题系统 | ✅ 完成 | PRD 11.1 四色系完整落地，圆角卡片风格 |
| 领域模型 | ✅ 完成 | 心情标签、花种、生长阶段、花朵、记录、花园状态 |
| 种花机制（PRD 7.1） | ✅ 逻辑完成 | 业务逻辑与动画骨架完成，画质待替换为手绘插画 |
| 烧纸卷机制（PRD 7.2） | ✅ 逻辑完成 | 含长按点燃、燃烧、灰烬飘散与**内容物理擦除** |
| 养分系统（PRD 7.3） | ✅ 完成 | 双路径汇入同一养分池 |
| **本地加密持久化（PRD 10）** | ✅ **完成** | **AES-256-GCM + 系统安全区托管密钥，原子落盘** |
| **无障碍（字体放大 2×）** | ✅ **完成** | **全部页面在 2× 字体下零溢出，有回归测试守护** |
| Tab1 花园首页 | ✅ 完成 | 全景画布、今日概览、养分进度条、双主入口 |
| Tab2 时光轴 | ✅ 完成 | 周 / 月 / 年三视图 + 日期详情（含灰烬封条） |
| Tab3 花之图鉴 | ✅ 完成 | 三个分区、稀有度、收集进度、隐藏款解锁条 |
| Tab4 我的 | ✅ 完成 | 主题换肤、字体大小、每日提醒、分享花园、自定义标签、隐私与数据 |
| **图片输入** | ✅ **完成** | **拍照 / 相册 / 多图，同一把主密钥加密，燃烧时连同密文一起删除** |
| **进阶收集玩法（PRD 7.1.3）** | ✅ **完成** | **进化花种解锁、季节限定约束、隐藏款可种** |
| **时光轴搜索 / 筛选** | ✅ **完成** | **按心情标签多选 + 关键词搜索（P2）** |
| **无障碍** | ✅ **完成** | **字体放大 2× 零溢出 + 色彩对比度达 WCAG AA，均有测试守护** |
| **仪式音效** | 🟡 **占位音** | **链路已通；素材是代码合成的占位音，待声音设计替换** |
| 每日提醒 / 分享 | ✅ 完成 | 本地通知（P1）、花园卡片分享（P2）|

---

## 核心机制

### 1. 开心事 → 种花（PRD 7.1）

记录 → 选心情标签（标签与花种一一对应）→ 种子入土 → **随真实时间自然生长**。

```dart
// lib/domain/entities/flower.dart
// 生长阶段不由任何写操作决定，而是由「种植时间 → 当前时间」推导。
// 这正是 PRD 7.1.2「活地图」心智的技术落点。
GrowthStage stageAt(DateTime now);
```

养分值越高，生长周期越短（PRD 7.3）。

### 2. 不开心事 → 烧纸卷 → 灰烬化肥（PRD 7.2）

写入 → 长按点燃（**松手只回退进度，不产生副作用**）→ 火苗蔓延 → 化为灰烬 → 灰烬**只向下**飘入土壤。

> 灰烬动画的粒子没有一个向上散开——这不是美术选择，而是机制表达：灰烬不会消失，它会变成养分。

### 3. 养分池：两条路径的汇合点（PRD 7.3）

```
开心事 → 种子入土 ─┐
                   ├─→ 花园养分池 ─→ 生长速度 / 繁茂程度
不开心事 → 灰烬入土 ─┘
```

> 负向转化带来的养分被刻意设定为**不低于**正向记录（`nutrientPerAsh >= nutrientPerSeed`），
> 数值上不对负向情绪做任何贬抑。该约束由测试守护。

---

## 隐私机制：不只是「不显示」

PRD 7.2.3 要求：*原始记录内容不可再次查看、不可恢复*。

本项目没有把这当成一条 UI 约束，而是**在模型层强制实现**：

```dart
// lib/domain/entities/mood_entry.dart
/// 执行燃烧：返回一个内容已被擦除的副本。
/// 这是「原始记录内容不可再次查看、不可恢复」这条产品承诺的强制实现点。
UnhappyEntry burn(DateTime at) => UnhappyEntry(
      id: id,
      occurredAt: occurredAt,
      createdAt: createdAt,
      text: '',                     // 原文物理清空
      imagePaths: const <String>[], // 图片引用物理清空
      burnedAt: at,
    );
```

序列化层还会再擦一次——即使有人手工篡改存储文件试图让已燃烧的记录「复活」，
解码时只要 `burnedAt` 存在，原文就会被丢弃。这两条路径都有测试覆盖
（`test/unit/mood_entry_test.dart`、`test/unit/codec_test.dart`）。

### 落盘同样是加密的

PRD 第 10 章要求本地存储加密，且「灰烬转化后的原始记录需做到物理层面不可恢复」。
实现分三层，每层都有测试：

| 层 | 做法 | 测试 |
| --- | --- | --- |
| 密钥 | 主密钥由系统安全区托管（Keychain / Keystore），**不与密文同处存放** | `secure_master_key_provider` 相关 4 例 |
| 密文 | AES-256-GCM 加密后写入 App 私有目录；带认证标签，篡改即解密失败 | `encrypted_local_store_test.dart` |
| 落盘 | 「临时文件 + 原子重命名」，写到一半被杀进程也不会留下半截文件 | 原子性 1 例 |

两条刻意的设计取向：

- **密钥变了不删数据，而是隔离保留**：解密失败时把原文件改名为
  `*.unreadable-<时间戳>`，既不阻塞启动，也不静默销毁用户的日记。
  这类场景在测试里有专门覆盖。
- **装配失败要降级而不是崩溃**：安全区不可用时退化为内存存储，并把原因
  显示在「我的 → 隐私与数据」里，让用户知道这轮记录不会留存——
  而不是让他自己发现「记了半天，重开全没了」。

---

## 技术栈

| 项 | 选择 | 说明 |
| --- | --- | --- |
| 框架 | Flutter 3.47.4 (stable) | 一套代码覆盖 iOS 首发 + 后续 Android 拓展 |
| 语言 | Dart 3.13.3 | 用 `sealed class` 建模记录类型，靠穷尽 `switch` 保证不漏处理分支 |
| 状态管理 | `provider` | 轻量、官方推荐的 `ChangeNotifier` 方案 |
| 本地化 | `flutter_localizations` | 日期选择器等系统文案的中文支持 |
| 本地加密 | `cryptography`（AES-256-GCM） | 纯 Dart 实现，无需平台原生加密库 |
| 密钥托管 | `flutter_secure_storage` | iOS / macOS → Keychain，Android → Keystore |
| 沙盒目录 | `path_provider` | 取 App 私有目录写入密文文件 |
| 图片输入 | `image_picker` | 相册多选 / 拍照，入库前先缩到长边 1600 |
| 每日提醒 | `flutter_local_notifications` + `timezone` + `flutter_timezone` | 本地通知；时区必须取设备的，否则提醒会在错的时间响 |
| 分享 | `share_plus` | 把花园卡片渲染成 PNG 后交给系统分享 |
| 音效 | `audioplayers` | 播放 assets 里的仪式音效 |
| 测试 | `flutter_test` + `integration_test` | 单元 / 组件 / 桌面集成，共 204 个用例 |
| 静态分析 | `flutter_lints` + 项目自定义规则 | 当前零 issue |

**刻意不引入**：`intl`（手写中文日期格式化，避免版本约束冲突）、`build_runner`（手写序列化，骨架期无需代码生成）、任何 DI 框架（手工构造注入，依赖少时更直观）。

---

## 快速开始

### 环境要求

- Flutter SDK ≥ 3.47.0（Dart ≥ 3.13.0）
- iOS 构建需 Xcode；Android 构建需 Android SDK

### 运行

```bash
flutter pub get
flutter analyze          # 应为 "No issues found!"
flutter test             # 应为 "All tests passed!"（124 个用例）
flutter run              # 连接设备或启动模拟器
flutter build apk --release   # 产出 build/app/outputs/flutter-apk/app-release.apk
```

> 本机构建 Android 包时请直接用 `tool/build_android.sh`：它固化了工具链路径与
> 「Xcode 许可未接受」的旁路。实机验收步骤见 **[docs/ACCEPTANCE.md](docs/ACCEPTANCE.md)**。

### 本机环境说明

**1. Xcode 许可已同意**（曾是最麻烦的一条）——在同意之前，`git` / `clang` / `xcrun`
乃至 `brew` 全部会打印许可警告并非零退出，连带让 `bin/flutter` 以 69 退出、
Flutter 无法确定自身版本、pub 求解失败。若在别的机器上再遇到：

```bash
sudo xcodebuild -license accept     # 需要你本人执行，需输入密码
```

**2. Flutter SDK 未加入 PATH** —— SDK 位于 `~/development/flutter`，需要时执行：

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

**3. JDK 与 Android SDK 在非标准路径** —— 位于 `~/development/toolchain/`。
打 Android 包请直接用 `tool/build_android.sh`，它会把路径 export 好。

**4. Maven 走阿里云镜像** —— `maven.google.com` 在本网络下不可达。
另注意 `android/gradle.properties` 里关掉了 AGP 的 SDK 联网自动下载，
否则构建会在拉取 SDK 仓库清单时静默挂起十几分钟。

---

## 项目结构

```
lib/
├── main.dart                    # 入口 + 依赖装配
├── app.dart                     # 根组件（主题、本地化、Provider）
├── application/
│   └── mood_garden_controller.dart   # ★ 三套机制的业务逻辑中枢
├── core/
│   ├── constants/app_constants.dart  # 业务常量（含待确认项标注）
│   ├── router/app_router.dart        # 类型安全的页面路由
│   ├── theme/                        # PRD 11.1 四色系 + 字体 + 主题装配
│   └── utils/                        # 日期格式化、ID 生成
├── domain/                      # ★ 领域层：纯业务，不依赖 Flutter UI
│   ├── entities/                # 心情标签 / 花种 / 生长阶段 / 花朵 / 记录 / 花园状态
│   └── repositories/            # 仓库抽象接口
├── data/                        # 数据层：实现领域层定义的契约
│   ├── models/                  # 序列化编解码（含隐私擦除的二次防线）
│   ├── datasources/
│   │   ├── local_store.dart               # 本地持久化抽象
│   │   ├── encrypted_local_store.dart     # ★ AES-256-GCM 加密文件存储
│   │   ├── secure_master_key_provider.dart # ★ 主密钥托管（Keychain / Keystore）
│   │   └── storage_bootstrap.dart         # 存储装配 + 失败降级
│   └── repositories/            # 仓库实现
├── features/                    # 表现层：按 PRD 的 Tab 划分
│   ├── shell/                   # 四个一级 Tab 的容器
│   ├── garden/                  # Tab1 花园首页 + 全景画布 + 养分进度条
│   ├── timeline/                # Tab2 时光轴（周/月/年）+ 日期详情
│   ├── codex/                   # Tab3 花之图鉴
│   ├── profile/                 # Tab4 我的（主题换肤可用）
│   ├── record_happy/            # 记录开心事 + 种子落地动画
│   └── record_unhappy/          # 情绪纸卷 + 长按点燃 + 燃烧 + 灰烬飘散
└── shared/widgets/              # 通用组件（圆角卡片、空态、区块标题）

test/
├── unit/                        # 领域模型、控制器、序列化、加密存储、
│                                # 进阶玩法规则、筛选规则、色彩对比度
└── widget/                      # 应用冒烟、字体放大无障碍、图鉴收集口径、
                                 # 花园渲染护栏

integration_test/                # 在真实平台后端上跑（macOS 真实 Keychain + 沙盒目录）
├── desktop_storage_test.dart

tool/
└── build_android.sh             # Android 打包脚本（固化本机非标准工具链路径）

docs/
├── PRD.md                       # 产品需求文档归档（由 docx 转换）
├── ARCHITECTURE.md              # 架构与设计决策
├── ACCEPTANCE.md                # 实机验收指南（装哪个包、逐项怎么验）
└── ROADMAP.md                   # 迭代路线图

android/ ios/ macos/             # 三端平台目录（macOS 仅用于桌面实测，非 PRD 目标平台）
```

---

## 平台构建状态

| 平台 | 状态 | 说明 |
| --- | --- | --- |
| Android | ✅ 已产出 release APK | `tool/build_android.sh`；当前用 debug 签名，仅供验收 |
| iOS | ✅ 可编译（`--no-codesign`） | CocoaPods 与 Keychain entitlement 均已接好；**尚未真机验证** |
| macOS | ✅ 可构建并运行 | 非目标平台，加它是为了能在这台机器上做真实运行验证 |

---

## 需求映射

PRD 章节与代码位置的对应关系，便于评审时逐条核对：

| PRD 章节 | 内容 | 代码位置 |
| --- | --- | --- |
| 6 | 产品信息架构（四个一级 Tab） | `lib/features/shell/main_shell.dart` |
| 7.1.1 | 开心事输入流程（五步） | `lib/features/record_happy/record_happy_page.dart` |
| 7.1.1 步骤 3 | 标签与花种一一对应 | `lib/domain/entities/mood_tag.dart`、`flower_species.dart` |
| 7.1.2 | 种子落地反馈动画 | `lib/features/record_happy/widgets/seed_landing_overlay.dart` |
| 7.1.2 | 收集进度提示（「再种 N 颗」） | `mood_garden_controller.dart` → `PlantSeedResult` |
| 7.1.2 | 随真实时间自然生长 | `lib/domain/entities/flower.dart` → `stageAt()` |
| 7.1.3 | 进化花种 / 季节限定 / 隐藏款 | `flower_species.dart`、`app_constants.dart` |
| 7.2.1 | 纸卷输入流程 | `lib/features/record_unhappy/record_unhappy_page.dart` |
| 7.2.1 步骤 2 | 纸卷做旧纹理造型 | `lib/features/record_unhappy/widgets/paper_scroll_card.dart` |
| 7.2.2 | 长按点燃 + 进度条 + 松手中断 | `lib/features/record_unhappy/widgets/ignite_button.dart` |
| 7.2.2 | 火苗蔓延、灰烬飘入土壤（唯一归宿） | `paper_scroll_card.dart` → `BurningFlame`、`widgets/ash_scatter_overlay.dart` |
| 7.2.3 | 灰烬化肥 + 内容不可恢复 | `mood_entry.dart` → `UnhappyEntry.burn()` |
| 7.2.3 | 时光轴「已转化为养分」封条 | `lib/features/timeline/date_detail_page.dart` → `_AshSeal` |
| 7.3 | 花园养分系统（双来源、进度条常驻） | `garden_state.dart`、`garden/widgets/nutrient_progress_bar.dart` |
| 7.4 | 机制闭环 | 两条路径共用 `MoodGardenController` 与 `GardenState` |
| Tab1 | 花园首页 | `lib/features/garden/garden_home_page.dart` |
| Tab2 | 时光轴（周/月/年 + 日期详情） | `lib/features/timeline/` |
| Tab3 | 花之图鉴（四个分区） | `lib/features/codex/codex_page.dart` |
| Tab4 | 我的（主题换肤等六项） | `lib/features/profile/profile_page.dart` |
| 11.1 | 四色系 | `lib/core/theme/app_colors.dart` |
| 11.2 | 字体（圆润、可调节） | `lib/core/theme/app_typography.dart` |
| 11.3 | 圆角卡片 + 柔和节奏 | `lib/core/theme/app_theme.dart`、`shared/widgets/soft_card.dart` |
| 12 | 待定事项 | 代码中以 `⚠️ PRD 第 12 章待定项` 标注 |
| 13 | 里程碑规划 | `docs/ROADMAP.md` |

---

## 架构说明

采用简化的分层架构，依赖方向单向向内：

```
features (表现层)
      ↓  依赖
application (业务编排)
      ↓  依赖
domain (实体 + 仓库接口)  ← 纯业务，不依赖 Flutter UI
      ↑  实现
data (仓库实现 + 序列化 + 存储)
```

关键设计决策详见 **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**，其中记录了若干处「为什么这样写」的取舍：

- 为什么生长阶段由时间推导而非存储字段；
- 为什么 `burn()` 返回新实例而不是修改标记位；
- 为什么用 `Wrap` 而非 `GridView` 承载卡片网格（字体放大时不溢出）。

---

## 已知限制

按优先级排列。前三条**无法靠写代码解决**，需要外部投入：

| # | 限制 | 影响 | 能否自行解决 |
| --- | --- | --- | --- |
| 1 | **动效仍是 emoji + 几何动画，不是手绘插画**（PRD 11.3） | 未达视觉要求 | ❌ 需美术产出插画 / 序列帧 |
| 2 | **音效是代码合成的占位音**（PRD 7.2.2） | 听感粗糙 | ❌ 需声音设计产出正式素材 |
| 3 | 字体仍是系统默认，未换圆体（PRD 11.2） | 亲和力略欠 | ❌ 需选型并内置可商用字体 |
| 4 | Android release 包使用 debug 签名 | 可安装验收，不可上架 | ✅ 需正式签名证书 |
| 5 | iOS 只验证到「可编译」，未在真机跑过 | 运行时行为未知 | ✅ 需一台 iPhone |
| 6 | 云同步与账号体系未实现 | PRD 第 12 章的开放问题，非既定需求 | ✅ 待产品决策 |

✅ **已解决**（相对 v0.1.0 骨架版）：

- 数据不落盘、无加密 → **AES-256-GCM 落盘 + 系统安全区托管密钥**
- 图片输入缺失 → **拍照 / 相册 / 多图，密文独立成文件，燃烧即删除**
- 进阶收集玩法是空壳 → **进化花种 / 季节限定 / 隐藏款全部生效**
- 设置项是占位 → **字体大小 / 每日提醒 / 分享花园 / 自定义标签全部可用**
- 色彩对比度不达标 → **关键文字全部达到 WCAG AA，有 9 条断言守护**

---

## 路线图

详见 **[docs/ROADMAP.md](docs/ROADMAP.md)**。三阶段与 PRD 第 13 章对齐：

1. **MVP 验证期** —— 核心机制成立性验证（P0 功能）
2. **功能完善期** —— 养成深度与个性化（P1 功能）
3. **正式上线期** —— 生态、无障碍与隐私安全体系（P2 功能）

---

## 待定事项

以下问题源自 PRD 第 12 章，**尚未定案**，实现中已用注释显式标注，需产品负责人补充确认后再固化：

| 待定项 | 当前占位处理 |
| --- | --- |
| 产品最终命名（谢谢日记 / 心情花园） | 暂用「心情花园」，见 `AppConstants.appName` |
| 花种与心情标签对照表的完整细节 | 仅实现 PRD 举例的 6 个标签 + 2 个进阶花种 |
| 开花阈值与养分数值 | 占位值（10 颗 / +10 / +15），集中定义在 `AppConstants` |
| 花朵是否支持主动加速交互（浇水等） | 未实现，保留「真实时间流逝」心智 |
| 隐藏款与季节限定的解锁规则 | 占位规则（连续 21 天 / 樱花 3-4 月） |
| 技术方案最终选型 | 当前 Flutter，待正式评估确认 |
| 商业化模式 | 未实现，`GardenThemeOption.unlockHint` 已预留字段 |

---

## 开发约定

- 提交前请确保 `flutter analyze` 零 issue、`flutter test` 全绿；
- 新增业务常量统一放入 `lib/core/constants/app_constants.dart`，并标注是否待产品确认；
- 涉及 PRD 待定项的实现，务必以 `⚠️ PRD 第 12 章待定项` 注释标明，避免占位值被误当作定案；
- `domain/` 层不得引入 Flutter UI 依赖，保持业务逻辑可独立测试。

---

## 许可证

待定。
