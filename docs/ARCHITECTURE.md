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

**理由**：PRD 第 10 章要求本地加密，但具体方案（SQLCipher / 系统安全区 / 文件加密）
尚未定案。把存储与加密解耦后，无论最终选哪种方案，业务代码都零改动。

**当前实现**：`InMemoryLocalStore` —— 数据仅存活于进程内存，**不落盘、不加密**。
这是骨架期的占位实现，替换前不得对外发布。

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
| 业务编排 | `test/unit/mood_garden_controller_test.dart` | 三套机制端到端、连续天数规则 |
| 表现层 | `test/widget/app_smoke_test.dart` | 四个 Tab 渲染、页面导航、关键文案 |

**刻意不测的**：保存流程的完整 UI 链路（含动画与对话框）。
原因是它会把测试与 `FakeAsync` 时钟、动画时长耦合在一起，非常脆弱；
而其中的业务逻辑已在控制器单元测试中完整覆盖。若将来要测，建议用集成测试
（`integration_test`）在真机/模拟器上跑。

---

## 5. 后续接入指引

### 接入真实的加密持久化

1. 实现 `LocalStore` 接口（例如 `EncryptedFileStore`）；
2. 密钥交由 iOS Keychain / Android Keystore 托管
   （别名见 `AppConstants.encryptionKeyAlias`）；
3. 在 `main.dart` 中替换 `InMemoryLocalStore` 的实例化；
4. 业务代码无需任何改动。

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
