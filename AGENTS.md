# TextFlash — Agent Onboarding

> macOS 13+ 菜单栏文本展开工具。Swift + SwiftUI，零第三方依赖；通过全局 CGEvent tap + Accessibility/Unicode 注入实现跨应用缩写展开。

## Build & Deploy

### 快速开发部署

```bash
./deploy.sh   # debug 编译 → 签名 → 启动，部署到 ~/Applications/TextFlash Dev.app
# 或
mise run deploy
```

### 生产发布

```bash
./release.sh <version>               # 统一验证 → release 编译 → 签名 → DMG → 烟测，产物在 dist/
./release.sh <version> --publish     # 额外原子推送 tag 并创建 GitHub Release
# 或
mise run release -- [version]
mise run release-auto                # 按 Conventional Commits 自动算下一版本
mise run publish -- <version>        # 显式确认版本后发布 GitHub Release
```

### 一次性设置：代码签名证书

辅助功能权限绑定到应用代码身份。TextFlash **禁止 ad-hoc 签名**；默认使用作者级共享证书 `Nekutai`，也可通过 `CODESIGN_IDENTITY` 指定任意稳定代码签名证书。

| 脚本 | 证书名称 | Bundle ID |
|---|---|---|
| `deploy.sh` | `${CODESIGN_IDENTITY:-Nekutai}` | `com.nekutai.textflash.dev` |
| `release.sh` | `${CODESIGN_IDENTITY:-Nekutai}` | `com.nekutai.textflash` |

**创建方法（只需一次）：**

1. 打开 **Keychain Access**（钥匙串访问）
2. 菜单 **钥匙串访问 → 证书助理 → 创建证书**
3. 名称填 `Nekutai`（或你自己的作者证书名）
4. 身份类型：**自签名根**
5. 证书类型：**代码签名**
6. 勾选 **覆盖默认** →「继续」→「创建」

证书缺失、签名失败或显式设置 `CODESIGN_IDENTITY="-"` 时，`deploy.sh` / `release.sh` 会直接停止，不会改用 ad-hoc。

本地验证入口统一走 mise：

```bash
mise run check       # lint:scripts + lint:design + test + build:release
mise tasks           # 查看全部任务
```

完整命令速查见 [`docs/MISE.md`](docs/MISE.md)；签名细节见 [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md)。

## Architecture

```
Sources/TextFlash/
├── TextFlashApp.swift              # @main + AppDelegate (LSUIElement)；init 内拦截命令行参数
├── Core/
│   ├── DataModels.swift            # Snippet / SnippetGroup
│   ├── EventController.swift       # CGEvent tap + AX/Unicode 注入引擎
│   ├── SnippetMatcher.swift        # 缩写匹配表
│   └── VariableProcessor.swift     # 展开变量（剪贴板、日期等）
├── CLI/
│   └── CLIController.swift         # 命令行 export/import 片段与配置（GUI 启动前退出）
├── Persistence/
│   ├── DatabaseManager.swift       # SQLite3 C API（纯 Swift，无第三方）
│   ├── AppSettings.swift           # 语言 / 触发匹配模式等 UserDefaults
│   └── SnippetManager.swift        # @MainActor ObservableObject 桥接
├── UI/
│   ├── MenuBarManager.swift        # NSStatusBar 菜单栏入口
│   ├── MenuBarMenuFactory.swift    # 右键菜单构建
│   ├── SnippetManagerView.swift    # 片段管理主窗口
│   ├── SnippetEditView.swift       # 片段编辑面板
│   ├── SyntaxHighlightedText.swift # 变量语法高亮
│   ├── SoftTheme.swift             # 软色主题 token
│   ├── AboutView.swift
│   ├── UpdateView.swift
│   └── DebugPanel.swift            # DEBUG 诊断面板
├── Settings/
│   └── SettingsView.swift          # 设置窗口（排除列表、Unicode 应用等）
├── Utils/
│   ├── AppResourceBundle.swift     # 资源包定位
│   ├── AppVersionInfo.swift        # About / Settings 版本展示
│   ├── LoginItemController.swift   # 登录项
│   ├── UpdateChecker.swift         # GitHub Release 检查更新
│   └── UpdateInstallScriptBuilder.swift
├── Generated/
│   └── Version.generated.swift     # release.sh 注入
└── Resources/
    ├── Assets/                     # AppIcon 等
    ├── Localizable.xcstrings
    └── Tools/                      # textflash-backup.sh / restore.sh

Tests/TextFlashTests/
├── SnippetMatcherTests.swift
├── VariableProcessorTests.swift
├── SnippetBackupValidatorTests.swift
├── MenuBarMenuFactoryTests.swift
├── SigningConfigurationTests.swift
├── ReleaseWorkflowContractTests.swift
├── AppVersionInfoTests.swift
├── AppResourceBundleTests.swift
└── UpdateInstallScriptBuilderTests.swift
```

分层约定：

- **Core**：领域模型 + 展开引擎（无 SwiftUI）
- **CLI**：命令行导入导出入口（无 SwiftUI；在 `TextFlashApp.init` 中于 GUI 启动前执行并退出）
- **Persistence**：SQLite / UserDefaults / Store 桥接
- **UI**：菜单栏、管理窗、主题与更新 UI
- **Settings**：设置窗
- **Utils**：横切（版本、登录项、更新、资源）
- 根目录只留 `@main` 入口；`Generated/` / `Resources/` 不参与分层

## Critical Pitfalls

以下是踩过的坑，Agent 接手时能省大量时间：

### 1. 禁止 ad-hoc 签名（TCC 绑定代码身份）

辅助功能授权绑定到代码签名身份。ad-hoc（`codesign -s -`）每次重编译可能换身份，导致用户反复重新授权。缺证书或 `CODESIGN_IDENTITY="-"` 必须失败退出。

### 2. CGEvent tap 必须挂 `.commonModes`

```swift
// ✅ EventController.setupEventTap()
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
```

macOS 进入 tracking mode（右键、拖拽、滚动）时，default mode 的源会丢事件。同理，若新增 `Timer`，也必须用 `.common`：

```swift
let timer = Timer(timeInterval: 0.5, repeats: true) { ... }
RunLoop.main.add(timer, forMode: .common)
```

### 3. 注入键事件用 `.privateState`，避免自触发

```swift
guard let source = CGEventSource(stateID: .privateState) else { return }
```

退格、Unicode 注入、触发符回写都走 `privateState`。若用 `.hidSystemState` / `.combinedSessionState`，自己发出的键会再次进入 tap，造成递归或缓冲区污染。

### 4. 全局 keyDown tap 需要 Accessibility；权限不足时不要硬弹系统框

`CGEvent.tapCreate(...)` 返回 `nil` 表示权限不足。当前策略：**不在启动时主动弹系统授权对话框**，由设置/横幅引导用户去系统设置开启。改权限请求时机前先确认产品行为。

打开设置用新旧 URL 双候选（Ventura / 更新系统设置）：

```swift
"x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
```

### 5. 注入策略：Accessibility 优先，Unicode 回退

展开流程：

1. `discardMarkedText()` 清输入法组合缓冲
2. 短延时后发退格删除缩写
3. 优先 `AXSelectedText` / 相关 AX 写入
4. 失败或偏好 Unicode 的应用 → `keyboardSetUnicodeString` 注入
5. 必要时回写触发字符

硬编码偏好 Unicode 的应用（Terminal / iTerm / Electron / Codex 等）见 `EventController.shouldPreferUnicodeInsertionForFocusedApplication()`；WebView 焦点也走 Unicode（`AXSelectedText` 不可靠）。新增不兼容应用时优先考虑用户可配置列表，而不是继续堆 `contains`。

### 6. 安全输入框禁止展开

检测 `AXIsSecureTextField` / `AXSecureTextField` 后必须禁用展开。密码框写错文本是严重安全问题，不要为「方便」绕过。

### 7. 忽略自身 Bundle

`com.nekutai.textflash` / `.dev` 前缀的应用不能当作排除目标或前台目标；用 `lastNonTextFlashApplication` 记录真正的目标应用。菜单栏 app 自身经常短暂成为 frontmost。

### 8. Event tap 回调必须极轻量

回调跑在 CGEvent tap 线程。重活（磁盘、网络、大量字符串处理）必须派发到主队列或其他队列；在回调里阻塞会卡全系统键盘。

### 9. 测试与运行中的 App 隔离

若测试触及剪贴板或全局事件，**不要**搅动正在运行的 TextFlash Dev.app。剪贴板测试用独立 pasteboard（`NSPasteboard.withUniqueName()`），不要写 `NSPasteboard.general`。当前单测以纯逻辑为主；扩展集成测试时遵守这条。

### 10. 备份脚本路径随 Resources 走

`Sources/TextFlash/Resources/Tools/textflash-{backup,restore}.sh` 由 `mise run lint:scripts` 语法检查，并打进 `.app`。改路径时同步 `mise.toml`、README 与 release 资源拷贝逻辑。

## Key Design Patterns

### 文本展开管道

`EventController` 维护输入缓冲区 + `SnippetMatcher` 匹配表。触发字符（空格/回车/Tab/标点；中文标点 `，。？、` 会归一）命中后走注入流程。片段变更通过 `Notification.Name.textFlashSnippetsDidChange` 通知 AppDelegate 重载匹配表。

### 应用排除与 Unicode 列表

- **排除列表**：这些 Bundle ID 上完全不展开（UserDefaults）
- **Unicode 输入列表**：这些应用强制走 Unicode 注入（菜单栏右键可把当前 app 加入）

两者都在设置页管理；变更发通知刷新控制器状态。

### 片段存储

SQLite 存 Application Support；管理窗支持 JSON 导入导出。导入前校验，覆盖前自动备份到 `~/Library/Application Support/TextFlash/Backups`（最多 20 份）。

### 更新安装

`UpdateChecker` 拉 GitHub Release；安装脚本由 `UpdateInstallScriptBuilder` 生成，校验 Bundle ID `com.nekutai.textflash` 与 codesign 后再替换应用。

## GitHub Actions

- `.github/workflows/ci.yml`：`main` push 和 pull request 触发；`jdx/mise-action` 后执行 **`mise run check`**（与本地单一事实来源）
- `.github/workflows/release-build-verification.yml`：仅 `workflow_dispatch`，执行 `mise run check`；CI 不持有稳定签名私钥，不生成正式 DMG

<!-- workspace-policy:start hash=2b7fa55c1aed -->
## 跨项目统一规则

以下区块由私有 `workspace-meta` 生成；项目专属规则请写在区块外。

### 协作

- [LANG-001] 文档、提交标题和用户可见文案默认使用中文。

### Git

- [GIT-001] 提交使用 Conventional Commits，格式为 `<type>(<optional-scope>): <中文说明>`，标题不以句号结尾。
- [GIT-002] 未明确要求时不要自动提交；需要提交时先检查 status、diff 和近期提交风格。
- [GIT-003] 禁止使用 `--no-verify`，不得擅自 amend，也不得添加 Co-Authored-By 或其他 AI/工具署名 trailer。

### 安全

- [SAFE-001] 保留用户已有和无关改动，不做顺手重构，不使用破坏性 Git 或文件操作。
- [SAFE-002] 不得提交 `.env`、密钥、个人数据、日志、报告、缓存或构建产物。

### 验证

- [VERIFY-001] 修改后运行仓库声明的统一验证入口；涉及页面流程时补跑对应 E2E。

### 依赖

- [DEPS-001] 改动保持最小，不引入项目基线之外的新框架、构建工具或生产依赖，除非用户明确要求。

### 文档

- [DOCS-001] 行为、命令或部署方式变化时同步 README 和相关文档，不保留过期引用。

### 工具链

- [MISE-001] 先运行 `mise tasks` 查看入口；构建、测试和部署统一使用 `mise run <task>`，不绕过 mise 手拼命令。

### macOS 应用

- [SWIFT-001] 使用 SwiftPM executable（swift-tools 6.0）和既有脚本组装应用，不新增 Xcode project。
- [SWIFT-002] 保持 Nekutai 自签名链路与 `com.nekutai.*` bundle id，严禁 ad-hoc 签名。
- [SWIFT-003] 新增 shell 脚本纳入 `lint:scripts`；发布继续使用既有 release.sh、DMG 和 GitHub Release 流程。
<!-- workspace-policy:end -->
