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
./release.sh [version]               # 测试 → release 编译 → 签名 → DMG → 烟测，产物在 dist/
./release.sh [version] --publish     # 额外推 tag 并创建 GitHub Release
# 或
mise run release -- [version]
mise run release-auto                # 按 Conventional Commits 自动算下一版本
mise run publish                     # 发布到 GitHub Release
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
mise run ci          # lint:scripts + test + build:release
mise tasks           # 查看全部任务
```

完整命令速查见 [`docs/MISE.md`](docs/MISE.md)；签名细节见 [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md)。

## Architecture

```
Sources/TextFlash/
├── TextFlashApp.swift              # @main + AppDelegate (LSUIElement)
├── Core/
│   ├── DataModels.swift            # Snippet / SnippetGroup
│   ├── EventController.swift       # CGEvent tap + AX/Unicode 注入引擎
│   ├── SnippetMatcher.swift        # 缩写匹配表
│   └── VariableProcessor.swift     # 展开变量（剪贴板、日期等）
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
├── AppVersionInfoTests.swift
├── AppResourceBundleTests.swift
└── UpdateInstallScriptBuilderTests.swift
```

分层约定：

- **Core**：领域模型 + 展开引擎（无 SwiftUI）
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

- `.github/workflows/ci.yml`：`main` push 和 pull request 触发；`jdx/mise-action` 后执行 **`mise run ci`**（与本地单一事实来源）
- `.github/workflows/release-artifact.yml`：仅 `workflow_dispatch`，跑 `release.sh` 并上传 DMG artifact；不自动打 tag / 不创建 GitHub Release

## Git 提交规范（强制）

所有提交（人工或 agent）必须使用 Conventional Commits，标题使用中文说明。

### 格式

```text
<type>(<optional-scope>): <中文说明>
```

### 允许的 type

- `feat` 新功能
- `fix` 修 bug
- `refactor` 重构（不改外部行为）
- `perf` 性能优化
- `docs` 文档
- `test` 测试
- `build` 构建 / 打包 / 发布链路
- `ci` CI 配置
- `chore` 杂务 / 依赖 / 工具
- `style` 纯格式或样式（不影响逻辑）

### 规则

1. `scope` 可选；用短小英文，如 `ui`、`event`、`snippets`
2. 冒号后必须有一个空格
3. 标题用中文，完整说明「做了什么 / 为什么」；不要只写「修复」「更新」
4. 标题尽量不超过 72 字符
5. 标题不要以句号结尾
6. 一次提交只做一件事；无关改动拆开提交
7. 未明确要求时，不要自动 `git commit`
8. 用户要求提交时，先看 `git status` / `git diff` / 最近提交风格，再起草 message
9. 不要使用 `--no-verify` 跳过 hook
10. 不要擅自 `git commit --amend`；仅在用户明确要求且符合安全条件时才 amend

### 禁止 Co-Author / 署名尾注

**禁止**在 commit message 中添加任何 co-author、生成器署名或类似 trailer，包括但不限于：

- `Co-Authored-By: ...`
- `Co-authored-by: ...`
- `Signed-off-by: ...`（除非用户或仓库明确要求）
- `Generated-by: ...` / `Assisted-by: ...` / `Made-with: ...`
- Cursor / Claude / Codex / Copilot / ChatGPT 等工具署名行

### 好例子

- `feat(event): 支持可配置的 Unicode 注入应用列表`
- `fix(matcher): 修复中文标点触发符归一遗漏`
- `refactor(sources): 按 Core/Persistence/UI 分层`
- `docs(agents): 补充 Accessibility/CGEvent 踩坑`
- `build(spm): swift-tools 升级到 6.0`

### 坏例子

- `修复问题`
- `update code`
- `feat: 搞定了`
- `临时提交一下`
- `fix(ui): 修复按钮` 后再附加 `Co-Authored-By: Cursor <...>`

### Body（可选）

需要时再写正文，说明动机、影响范围或破坏性变更。

## 提交操作约定

1. 默认只改代码，不主动提交
2. 需要提交时：用 Conventional Commits + 中文标题；优先 HEREDOC 传 message
3. 禁止添加 Co-Authored-By 或其他 AI/工具署名 trailer
4. 禁止用 `--no-verify` 绕过校验
