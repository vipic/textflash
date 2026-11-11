# 架构与模块

本页描述 TextFlash 当前代码如何协作。开发命令见 [`DEVELOPMENT.md`](../DEVELOPMENT.md)，发布流程见 [`RELEASE.md`](../RELEASE.md)，按应用/场景写死的逻辑见 [`customization-inventory.md`](../customization-inventory.md)。

## 运行时形态

- SwiftPM executable（`swift-tools-version: 6.0`，`swiftLanguageModes: [.v5]`），macOS 13+，零第三方依赖。
- 菜单栏应用：`LSUIElement=true`，启动时 `NSApp.setActivationPolicy(.accessory)`；打开托管窗口时临时切换为 `.regular`，所有窗口关闭后再切回 `.accessory`（`AppDelegate.restoreAccessoryModeIfNoManagedWindows`）。
- 单例：`EventController.shared`（键盘监听与注入）、`AppSettings.shared`（设置读写）、`DatabaseManager.shared`（SQLite）、`MenuBarManager.shared`（状态栏）、`UpdateChecker.shared`（更新）。

### 启动顺序

1. `TextFlashApp.init`：`CommandLine.arguments` 非空时交给 `CLIController.handleIfNeeded`，处理完直接 `exit`，不启动 GUI 与事件监听。
2. `AppDelegate.applicationDidFinishLaunching`：设 accessory、构建应用菜单、安装编辑快捷键本地监听、`MenuBarManager.setup()`、把数据库片段载入 `EventController`、`EventController.start()`、展示上次更新失败报告。
3. 订阅 `.textFlashSnippetsDidChange`（重载匹配表）与 `.textFlashLanguageDidChange`（重建菜单与窗口标题）。
4. `applicationWillTerminate`：移除快捷键监听、`EventController.stop()`。

## 文本展开数据流

```text
CGEvent tap（只订阅 keyDown）
  → 过滤自身注入事件（eventSourceUserData == "SNIP"）
  → 过滤 TextFlash 自身窗口、排除列表、Cmd/Ctrl 修饰键
  → EventController 维护输入缓冲，中文标点归一为英文触发符
  → SnippetMatcher（Trie）匹配最长后缀；可选“仅词边界”前置字符检查
  → VariableProcessor 展开变量，得到文本与 {cursor} 偏移
  → discardMarkedText()（清输入法组合）+ 5ms 等待
  → 按缩写长度发送退格，等待 max(20ms, 字符数 × 每字符延迟)
  → 写入展开文本：优先 Accessibility，必要时（或预判不兼容）改用 Unicode 键盘事件
  → 20ms 后按 {cursor} 偏移发送左箭头，解除 isInjecting
```

不变量：tap 回调只做内存与轻量 AX 查询，不做磁盘/网络/大字符串处理；注入事件使用 `.privateState` 事件源并携带标记，不得被自身再次处理；安全输入框禁止展开。

## 注入策略

`EventController.inject(...)` 在退格落地后决定写入方式：

| 条件 | 行为 |
| --- | --- |
| 当前应用在 `unicodeInputBundleIDs` 中 | 直接 `postUnicodeString` |
| 焦点元素位于 `AXWebArea` 内（最多向上查 10 层，遇到 `AXApplication` 停止） | 直接 `postUnicodeString` |
| 其余情况 | `AXUIElementSetAttributeValue(kAXSelectedTextAttribute)` |
| AX 明确返回失败 | 同次回退 `postUnicodeString` |
| AX 返回成功，但插入前后快照（`AXNumberOfCharacters` / `AXSelectedTextRange`）没有任何变化 | 60ms 后复查，仍无变化才按“静默忽略”处理：回退 `postUnicodeString`，并把当前应用写入 `unicodeInputBundleIDs` |
| 快照不可读（应用不暴露上述属性） | 信任 AX 结果，不学习、不重复写入 |

自动学习只记录 bundle id、写 `UserDefaults` 并广播 `.textFlashUnicodeAppsDidChange`；UI 里可随时移除。

Unicode 注入实现为一次 `CGEvent.keyboardSetUnicodeString` keyDown + keyUp，绕过键盘布局映射，但会经过目标应用的正常按键/输入法链路，因此慢应用需要更长的删除等待。

## 模块边界

| 模块 | 职责 |
| --- | --- |
| `Core/` | 数据模型、事件监听与注入、Trie 匹配、变量处理 |
| `CLI/` | GUI 启动前的片段/配置导入导出 |
| `Persistence/` | SQLite、UserDefaults、导入前备份、设置模型与本地化入口 |
| `Settings/` | 设置窗口、Unicode 输入与排除应用管理 |
| `UI/` | 菜单栏、片段管理/编辑、主题、语法高亮、调试面板、更新与关于窗口 |
| `Utils/` | 资源包定位、版本显示、登录项、更新检查与安装脚本生成 |
| `Resources/` | 本地化字符串、图标、随应用分发的备份/恢复脚本 |
| `Generated/` | 由 `release.sh` 注入的版本常量 |
| `TextFlashReleaseSmoke` | 发布验收辅助进程，检查 DMG 安装后的应用启动状态 |

根目录 `Sources/TextFlash/TextFlashApp.swift` 是应用入口与窗口管理；`Generated/Version.generated.swift` 不是手工事实来源。

## 持久化

### 片段（SQLite）

- 路径：`~/Library/Application Support/TextFlash/textflash.db`。
- `PRAGMA journal_mode=WAL`、`synchronous=FULL`、`foreign_keys=ON`。
- 表：`groups(id, name, sort_order)`、`snippets(id, group_id, abbreviation, expanded_text, description, sort_order, created_at, updated_at)`，`group_id` 外键级联删除。
- 唯一索引 `idx_snippets_abbr_unique` 保证缩写全局唯一；`PRAGMA user_version=2` 迁移会把历史重复缩写重命名为 `__textflash_migration_duplicate_<rowid>_<缩写>[_n]`。
- 初始化或迁移失败会记录 `initializationError` 并阻止后续写入；读取返回空结果时由调用方检查 `lastReadError` 并报错，不会伪装成“没有片段”。
- 导入：`SnippetBackupValidator` 兼容 `{"groups":[...]}`、分组数组、单个分组三种 JSON；校验空分组名、空缩写、空展开文本、重复缩写；文件上限 2 MB。
- 覆盖前自动备份到 `~/Library/Application Support/TextFlash/Backups/textflash-snippets-<时间>.json`（与导入格式兼容），只保留最近 20 份。

### 设置（UserDefaults）

| Key | 含义 |
| --- | --- |
| `TextFlashAppLanguage` | `system` / `zhHans` / `en` |
| `TextFlashDeletionSettleDelayPerCharacter` | 退格后每字符等待毫秒数，默认 20，界面范围 5–80 |
| `TextFlashTriggerMatchingMode` | `anywhere` / `boundary` |
| `TextFlashExcludedBundleIDs` | 排除应用 bundle id 列表 |
| `TextFlashUnicodeBundleIDs` | 强制 Unicode 输入的应用 bundle id 列表（含自动学习结果） |
| `TextFlashLastUpdateCheck` | 上次检查更新时间（24 小时间隔） |
| `TextFlashLastReleaseNotes` | 最近一次 Release 说明缓存 |

Bundle id 列表在写入前排序；变更通过 `NotificationCenter` 广播，界面据此刷新计数与列表。

### 命令行走廊

`CLIController` 复用同一套数据库与设置：

- `export snippets` / `import snippets`：与 GUI 共用 `SnippetBackup.encode`，输出 `prettyPrinted + sortedKeys`；导入前同样创建备份。
- `export config` / `import config`：字段全部可选（`language`、`deletionSettleDelayPerCharacter`、`triggerMatchingMode`、`launchAtLogin`、`unicodeInputBundleIDs`、`excludedBundleIDs`）；全部字段缺失视为无效文件；无效枚举值跳过并在 stderr 输出警告。

辅助功能授权由 macOS TCC 按代码身份管理，不属于可迁移数据。

## 窗口与界面

| 窗口 | 默认尺寸 | 说明 |
| --- | --- | --- |
| 片段管理 | 1040×640（最小 900×560） | 分组侧栏 + 片段列表 + 详情，支持导入导出与搜索 |
| 设置 | 宽 620，高按内容自适应 | 语言、开机启动、触发边界、替换时序、Unicode 应用、权限、排除应用、版本 |
| 关于 | 320×300 | 版本、构建号、说明 |
| 更新 | 420 宽自适应 | 检查/下载/安装/错误状态 |
| 调试面板（仅 DEBUG） | 560×520 | tap 状态、缓冲、已加载缩写、事件日志尾部 |

菜单栏左键打开片段管理，右键弹出菜单（打开片段管理、检查更新、设置 ⌘,、当前应用用 Unicode 输入、DEBUG 下调试面板、退出 ⌘Q）。开发版（版本号含 `-dev` 或 bundle id 以 `.dev` 结尾）会禁用检查更新并使用 `MenuBarIconDev`。

设置窗口与片段窗口都使用 `isReleasedWhenClosed = false` + `willCloseNotification` 清理引用，避免悬垂窗口指针。

## 视觉与本地化

- 颜色字面量统一收敛到 `UI/SoftTheme.swift`；`mise run lint:design` 会拒绝其他文件里的 `Color(red:` / `Color(.sRGB`。
- 中英文案在 `Resources/zh-Hans.lproj` 与 `Resources/en.lproj`，通过 `L10n.t` / `L10n.f` 读取；语言切换不需要重启应用窗口。
- `AppResourceBundle` 自行定位 `TextFlash_TextFlash.bundle`，打包后的 `.app` 中禁止触发 `Bundle.module`（其回退路径指向开发者 `~/Documents`，会触发 TCC 弹窗）。

## 版本与更新

- `release.sh` 注入 `Version.generated.swift`（`current`/`build`）；开发构建保留 `0.0.0-dev`/`0`。
- `AppVersion.displayCurrent` 优先取 Info.plist 的 `CFBundleShortVersionString`，占位版本回退 `0.1.0`；`displayBuild` 在生成值为 `0` 时回退 bundle 版本。
- 更新检查：GitHub `releases/latest`，非强制模式 24 小时一次，开发版跳过；仅接受 HTTPS、下载上限 300 MB、校验 HTTP 状态与字节数；只取第一个 `.dmg` 资产。
- 安装：写入临时脚本并由 `nohup` 拉起，脚本等待当前进程退出 → 挂载 DMG → 校验 bundle id、版本、`codesign --verify --deep --strict`、拒绝 ad-hoc、比较 designated requirement（同证书 `Nekutai` 轮换放行）→ 备份旧 App → 复制 → 复核版本 → 失败恢复 → 重新打开。
- 诊断：安装日志 `~/Library/Application Support/TextFlash/update.log`，错误写入 `update_error.txt`，下次启动读取并截断到 2 KB 后展示，然后删除。

## 必须保持的不变量

- 开发和正式构建都使用稳定代码签名（默认 `Nekutai`），禁止 ad-hoc 回退；TCC 授权依赖稳定代码身份。
- Event tap source 与相关 Timer 使用 common run-loop mode，避免菜单跟踪、拖拽期间漏事件。
- 注入事件使用 private event source 并带 `SNIP` 标记，避免自触发。
- 安全输入框（`AXIsSecureTextField` / `AXSecureTextField`）禁止展开；TextFlash 自身窗口完全放行。
- 权限不足时给用户可见引导，不在启动时反复弹系统授权框。
- 更新安装前校验 bundle id、版本与 designated requirement；替换失败必须恢复旧 App。
- 新增按应用写死的兼容逻辑时同步更新定制化清单，并优先提供可配置入口。
- 运行日志与诊断输出不得包含正文、剪贴板内容或凭据；仅记录 bundle id、版本与状态。

## 验证

- 统一入口：`mise run check`（脚本语法、设计 token、恢复/发布门禁脚本测试、`swift test`、release 编译）。
- 改动职责、数据流或上述不变量时同步更新本页。
- 涉及真实文本注入、TCC 权限或更新安装时补做人工验收（见 [`RELEASE.md`](../RELEASE.md)）。
