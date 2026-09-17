# 架构说明

本文档记录项目的分层结构、关键设计决策，以及若干处「为什么这样写」的取舍。
评审时若对某处实现有疑问，通常能在这里找到答案；找不到的，说明该决策应当被补充进来。

---

## 1. 分层结构

```
┌─────────────────────────────────────────────────┐
│ features/          表现层（Widget + 页面）        │
│   garden / timeline / codex / profile /          │
│   record_happy / record_unhappy / shell          │
└────────────────────┬────────────────────────────┘
                     │ 依赖
┌────────────────────▼────────────────────────────┐
│ application/       业务编排                       │
│   MoodGardenController (ChangeNotifier)          │
└────────────────────┬────────────────────────────┘
                     │ 依赖
┌────────────────────▼────────────────────────────┐
│ domain/            领域层（纯 Dart，无 Flutter UI）│
│   entities/        实体与业务规则                  │
│   repositories/    仓库抽象接口                    │
└────────────────────▲────────────────────────────┘
                     │ 实现
┌────────────────────┴────────────────────────────┐
│ data/              数据层                         │
│   models/          序列化编解码                    │
│   datasources/     LocalStore（存储抽象）          │
│   repositories/    仓库实现                        │
└─────────────────────────────────────────────────┘
```

**依赖方向单向向内**：`features → application → domain ← data`。
`domain/` 不 import 任何 Flutter UI 代码，因此其中的业务规则可以脱离 Widget 测试。

---

## 2. 关键设计决策

### 2.1 生长阶段由时间推导，而不是存储字段

**决策**：`Flower` 只存储 `plantedAt`，当前生长阶段由 `stageAt(now)` 实时计算。

**理由**：PRD 7.1.2 的核心心智是「花园是随真实时间流逝自然生长的活地图」。
如果生长阶段是一个存储字段，就需要一个后台任务或启动时批量更新去推进它——
既增加复杂度，也让「用户隔天打开看到花长大了」这件事依赖于更新任务是否跑成功。

**收益**：
- 无需任何后台机制，时间本身就是驱动力；
- 时光轴回看历史某天时，传入那天的日期即可**复现当天的花园样貌**（`stageAt` 接受任意时刻）；
- 测试可以直接传入任意时间点，不依赖系统时钟。

**代价**：每次渲染都要做一次时间差计算。对个人日记的植物数量级（数百株）可忽略。

### 2.2 `burn()` 返回新实例，而不是打标记

**决策**：`UnhappyEntry.burn()` 返回一个 `text` 与 `imagePaths` 已被清空的**新实例**，
而不是把 `isBurned` 置为 `true` 后保留原文。

**理由**：PRD 7.2.3 承诺「原始记录内容不可再次查看、**不可恢复**」。
如果原文还留在对象或存储里，只是 UI 不展示，那这条承诺就只是一句 UI 层的君子协定——
任何拿到存储文件的人都能读出来。

**收益**：隐私承诺由类型系统和数据流保证，而非依赖调用方的自觉。

**配套防线**：序列化层 `MoodEntryCodec.fromMap` 在解码时若发现 `burnedAt` 非空，
会**再次丢弃** `text` 与 `imagePaths`。即使有人手工篡改存储文件试图让记录「复活」，
读出来的仍是空内容。该行为有测试覆盖。

### 2.3 记录类型用 `sealed class` 建模

**决策**：`MoodEntry` 是 `sealed class`，`HappyEntry` 与 `UnhappyEntry` 是仅有的两个子类。

**理由**：两条记录路径的**输入结构相同、后续命运完全不同**（一个入土生长，一个烧成灰烬）。
用 sealed class 后，消费方（时光轴、花园首页等）的 `switch` 会被编译器强制穷尽——
将来若新增第三种记录类型，所有需要处理它的地方都会在编译期报错，而不是在运行期静默漏掉。

### 2.4 卡片网格用 `Wrap`，不用 `GridView`

**决策**：花种图鉴与花园主题选择器使用 `Wrap` + `SizedBox(width: itemWidth)`，
而非 `GridView` + `childAspectRatio`。

**理由**：`GridView` 的固定宽高比意味着**固定高度**。一旦内容超出行高
（窄屏、长文案，或用户放大了系统字体），`Column` 就会 `RenderFlex overflow` 报错。
而「字体大小可调节」是 PRD 第 10 章明确的无障碍要求。

**收益**：卡片高度由内容决定，字体放大时自动变高，永不溢出。

**代价**：同一行的卡片高度可能不一致（`Wrap` 不强制等高）。对治愈系视觉风格而言可以接受。

> 这个问题是在组件测试中真实发现的：主题卡片在 360dp 宽度下溢出 5.6px。

### 2.5 用 `Wrap` 的确定性抖动而非随机布局

**决策**：花园中每株植物的位置微扰、倾斜角度由其 `id.hashCode` 派生的
确定性伪随机数生成（`Flower.jitter`）。

**理由**：如果用 `Random()` 每次绘制都取新值，花园会在每一帧重绘时「跳动」，
破坏柔和治愈的观感（PRD 11.3）。

**收益**：同一株花永远长在同一个位置；重建 Widget 树、重启 App 后位置也一致。

### 2.6 刻意不引入的三个依赖

| 未引入 | 替代方案 | 原因 |
| --- | --- | --- |
| `intl` | `lib/core/utils/date_formatter.dart` | 骨架期只需中文单语展示；`intl` 与 Flutter 版本间存在约束耦合，手写可避免。未来支持多语言时再切换为 `intl` + ARB。 |
| `build_runner` / `json_serializable` | 手写 `MoodEntryCodec` / `GardenStateCodec` | 需要代码生成步骤会提高构建复杂度；骨架期模型尚未稳定，手写反而更易读。 |
| DI 框架（`get_it` 等） | `main.dart` 手工构造注入 | 依赖数量少时手工装配更直观，且测试中替换实现同样方便。 |

### 2.7 存储与加密分成两层

**决策**：`LocalStore` 只负责键值存取（`Future<String?> read(key)`），不关心内容形态与加密。

**理由**：PRD 第 10 章要求本地加密。把存储与加密解耦后，更换加密方案时业务代码零改动——
这一点已经被验证过一次：从内存占位实现换成加密文件实现时，
`MoodGardenController` 与两个仓库一行都没有改。

**当前实现**：`EncryptedLocalStore` —— AES-256-GCM 加密后写入 App 私有目录，
落盘采用「临时文件 + 原子重命名」。主密钥**不**写在密文文件里，
而由 `SecureStorageMasterKeyProvider` 交给 Keychain / Keystore 托管
（别名见 `AppConstants.encryptionKeyAlias`）。

**失败时的取向**（两条都刻意反直觉，故记录在此）：

- 解密失败（密钥变更 / 文件被篡改）→ 把原文件**改名隔离保留**
  （`*.unreadable-<时间戳>`），而不是删除。宁可留下一个用户或许能人工恢复的文件，
  也不静默销毁日记数据；同时不阻塞启动。
- 装配失败（安全区不可用）→ 降级为 `InMemoryLocalStore`，并把降级原因回传 UI
  显式展示。不让「存储不可用」变成「App 打不开」，也不让用户自己发现
  「记了半天，重开全没了」。

`InMemoryLocalStore` 仍然保留，用于测试与上述降级路径。

### 2.8 密钥托管的平台差异：iOS 要 entitlement，macOS 走 legacy Keychain

**决策**：`createSecureStorage()` 按平台构造不同的 `FlutterSecureStorage`——
macOS 显式关掉 data protection keychain，iOS / Android 用默认配置。

**理由**：`flutter_secure_storage_darwin` 在 Apple 平台都走 Keychain，但
**entitlement 要求不同**，而且它的失败方式是最坏的一种：

> 缺 `keychain-access-groups` 时，密钥会「看起来写成功、实际没写进去」。
> 于是本次运行一切正常，**下次启动却解不开旧密文**。

因此两端的处理必须分开：

| 平台 | 做法 | 原因 |
| --- | --- | --- |
| iOS | `Runner/DebugProfile.entitlements` 与 `Release.entitlements` 加 `keychain-access-groups`，并用 `CODE_SIGN_ENTITLEMENTS` 接进三处构建配置 | 这是插件的硬性要求；该 entitlement 随 provisioning profile 生效 |
| macOS | 用 `MacOsOptions(usesDataProtectionKeychain: false)` 回退到 legacy Keychain | 加同一个 entitlement 需要 provisioning profile，会让打出来的 `.app` 只能在构建它的机器上启动；本项目不需要 Keychain Sharing（无 App Group） |

**这个缺口是桌面实测发现的**：iOS 工程此前根本没有 entitlements 文件，
也没有 `CODE_SIGN_ENTITLEMENTS` 配置——真机上会静默丢密钥。
纯代码审查与单元测试都发现不了它，因为它是工程配置而非 Dart 逻辑。

> ⚠️ macOS 上的遗留现象：本机构建是 ad-hoc 签名且未设 Team
> （`TeamIdentifier=not set`），每次重建代码身份都变，
> legacy Keychain 会因此弹出系统授权框。这是桌面签名问题，
> **不影响 iOS**（始终以 team 签名 + data protection keychain）。

### 2.9 图片单独成文件，但用同一套信封

**决策**：图片不进那个键值 JSON，而是每张一个文件；加密复用同一个
[SecretEnvelope]（AES-256-GCM + 同一把主密钥）。

**理由**：如果图片塞进键值表，base64 会把每条记录撑大几十倍，
而且**每写一个字都要重新加密整张图**——记录一段 20 字的文字却要付出
几 MB 的加密开销。拆开之后，文字存储只关心文字。

**一致的承诺**：两种存储共用一套信封格式与一把密钥，
所以「磁盘上的数据长什么样」只有一个答案，安全审计不用看两处。

**燃烧时的顺序是刻意的**：先删图片密文，再落盘「已燃烧」的记录。
两种失败各会发生一次，代价并不对等：

- 先删后写失败 → 草稿里留下几个加载不出来的图片引用（界面小瑕疵）；
- 先写后删失败 → 磁盘上永久残留图片密文，而记录已显示「已转化为养分」
  （隐私承诺被静默破坏）。

后者是产品最核心的承诺，所以把删除放在前面。

### 2.10 色彩对比度是算出来的，不是看出来的

**决策**：把 `warmApricotDeep` / `mistyRoseDeep` / `sageGreenDeep` / `ash`
四个色的取值按 WCAG 相对亮度公式反推，并用 9 条断言锁住。

**理由**：这几个色当初是照美观挑的，实测在各自的浅色底上只有
**2.4 ~ 2.8:1**，连 AA 要求（4.5:1）的一半多都不到——
「已转化为养分」那句封条只有 2.42:1，而它恰恰是这个产品最需要被看清的一句话。

**代价**：强调色整体变深，视觉上比之前「重」一点。这是无障碍的必然取舍：
小字要读得清，层次就只能靠字号与字重去拉，不能再靠把颜色调淡。

**例外**：`inkTertiary` 刻意保留在 2.3:1，只用于禁用态与纯装饰——
如果它也变得清晰可读，「禁用」看起来就会像「可用」。测试里有一条断言
专门守住这个例外，提醒后来者不要拿它去写需要读的内容。

### 2.11 先出画面，再装配存储

**决策**：`main()` 先 `runApp` 一个静态过渡页，存储装配完成后再 `runApp` 真正的应用。

**理由**：装配要异步向系统安全区取主密钥。正常情况下只要几十毫秒，但它**可能被阻塞**
——macOS 上换签名后访问钥匙串会弹系统授权框等待用户输入。若把 `runApp` 放在
`await` 之后，这段等待就是一片纯黑窗口，用户完全不知道发生了什么。

**这个问题同样是桌面实测撞到的**，不是推测。代价是快速路径下过渡页会闪一下；
收益是任何慢路径下用户至少有东西可看，而不是面对黑屏。

---

## 3. 状态管理

`MoodGardenController`（`ChangeNotifier`）集中承载三套机制的结算逻辑。

**为什么集中而不拆分**：三个机制共同操作同一份 `GardenState` 与同一个养分池。
拆成多个控制器会引入跨控制器的一致性难题（例如「烧纸卷增加养分」与
「种花增加养分」并发写入时如何不互相覆盖）。当前规模下，一个控制器是最稳妥的选择。

**何时该拆**：当图鉴、提醒、分享等 P1/P2 功能接入后，若控制器超过约 500 行，
可按 `GardenController` / `EntryController` / `SettingsController` 拆分，
但需先把养分池的写入收敛为单一入口。

---

## 4. 测试策略

| 层次 | 位置 | 覆盖内容 |
| --- | --- | --- |
| 领域模型 | `test/unit/mood_entry_test.dart` | 燃烧擦除、补记判定、时间语义 |
| 领域模型 | `test/unit/flower_test.dart` | 生长阶段推导、养分加速、花种目录 |
| 领域模型 | `test/unit/garden_state_test.dart` | 养分进度、收集进度、隐藏款解锁 |
| 数据层 | `test/unit/codec_test.dart` | 序列化往返、**篡改后仍擦除**、损坏数据容错 |
| 数据层 | `test/unit/encrypted_local_store_test.dart` | **密文落盘、重启后仍可解密、磁盘上无明文、篡改检测、密钥变更时隔离保留、原子写入** |
| 业务编排 | `test/unit/mood_garden_controller_test.dart` | 三套机制端到端、连续天数规则 |
| 表现层 | `test/widget/app_smoke_test.dart` | 四个 Tab 渲染、页面导航、关键文案 |
| 表现层 | `test/widget/text_scale_test.dart` | **系统字体放大 2× 时全部页面零溢出**（PRD 第 10 章无障碍） |
| 表现层 | `test/widget/codex_collection_test.dart` | **图鉴顶部「已收集」与卡片剪影判定口径一致** |
| 真实后端 | `integration_test/desktop_storage_test.dart` | **在 macOS 桌面端跑真实 `path_provider` 沙盒目录 + 真实 Keychain**：加密落盘、无明文、重建实例后仍能解密 |

**刻意不测的**：保存流程的完整 UI 链路（含动画与对话框）。
原因是它会把测试与 `FakeAsync` 时钟、动画时长耦合在一起，非常脆弱；
而其中的业务逻辑已在控制器单元测试中完整覆盖。若将来要测，建议用集成测试
（`integration_test`）在真机/模拟器上跑。

---

## 5. 后续接入指引

### 本地加密持久化（✅ 已完成）

1. ~~实现 `LocalStore` 接口~~ → `EncryptedLocalStore`
   （AES-256-GCM + 临时文件原子替换）；
2. ~~密钥交由 iOS Keychain / Android Keystore 托管~~
   → `SecureStorageMasterKeyProvider`，别名 `AppConstants.encryptionKeyAlias`；
3. ~~在 `main.dart` 中替换 `InMemoryLocalStore` 的实例化~~
   → `bootstrapLocalStore()`，内含失败降级；
4. ~~业务代码无需任何改动~~ —— 实际改动量为零：
   `MoodGardenController` 与两个仓库实现均未修改。

**遗留（图片输入的前置条件）**：图片文件本身尚未纳入加密存储，因此图片输入仍未接入。
方案确定后除了给图片加密，还要在 `UnhappyEntry.burn()` 的调用链上一并删除
对应密文文件——否则「原始内容不可恢复」这条承诺在图片上就存在漏洞。

### 三端构建状态

| 平台 | 状态 | 说明 |
| --- | --- | --- |
| Android | ✅ 已产出 release APK | 见 `docs/ACCEPTANCE.md`；release 仍用 debug 签名 |
| iOS | ✅ 可编译（`flutter build ios --no-codesign`） | CocoaPods 集成与 entitlements 均已接好；**未在真机验证**（模拟器子系统在本机不可用） |
| macOS | ✅ 可构建并运行 | 用于桌面实测；非 PRD 目标平台 |

### 接入图片输入

图片不能只存路径——文件本身也必须纳入加密存储（PRD 第 10 章）。
建议顺序：先确定图片加密方案，再接入 `image_picker`，
最后替换 `record_happy_page.dart` 中的 `_ImagePickerStub` 与
`date_detail_page.dart` 中的 `_ImageStrip`。

### 替换占位动效为手绘插画

三个动画组件的**对外接口已稳定**，替换时只需改动内部绘制层：

| 组件 | 文件 | 替换目标 |
| --- | --- | --- |
| 种子落地 | `features/record_happy/widgets/seed_landing_overlay.dart` | 序列帧 / Rive |
| 燃烧火苗 | `features/record_unhappy/widgets/paper_scroll_card.dart` → `BurningFlame` | 序列帧 / Rive + 音效 |
| 灰烬飘散 | `features/record_unhappy/widgets/ash_scatter_overlay.dart` | 序列帧 / Rive |

调用方（`RecordHappyPage` / `RecordUnhappyPage`）通过
`SeedLandingOverlay.totalDuration`、`AshScatterOverlay.totalDuration`
这两个常量感知动画时长，替换时保持常量语义即可。
