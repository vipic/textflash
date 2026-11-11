# 开发说明

本页覆盖本地环境、常用任务、签名要求、资源与本地化约定。发布流程见 [`RELEASE.md`](RELEASE.md)，全部 mise 任务见 [`MISE.md`](MISE.md)。

## 环境

| 项 | 要求 |
| --- | --- |
| macOS | 13.0+（`Package.swift` 与 Info.plist 的 `LSMinimumSystemVersion`） |
| Swift | 6.0 工具链，`swift-tools-version: 6.0`；语言模式暂时钉在 v5 |
| mise | 所有构建/测试/发布入口 |
| 签名证书 | 钥匙串中存在稳定代码签名身份，默认 `Nekutai` |

首次使用：

```bash
brew install mise
mise trust
mise tasks
```

无第三方运行时依赖；`Package.swift` 的 `dependencies` 必须保持为空。

## 常用任务

```bash
mise run build          # swift build -Xswiftc -DDISABLE_PREVIEWS
mise run test           # swift test -Xswiftc -DDISABLE_PREVIEWS
mise run build:release  # swift build -c release -Osize -DDISABLE_PREVIEWS
mise run check          # 统一验证入口
mise run deploy         # 编译 → 打包 → 签名 → 启动开发版
```

`mise run check` 依次执行：

1. `lint:scripts`：对全部 shell 脚本做 `bash -n`。
2. `lint:design`：拒绝 `SoftTheme.swift` 之外的 `Color(red:` / `Color(.sRGB` 颜色字面量。
3. `test:restore`：`Tests/Scripts/restore_behavior_test.sh`，在临时数据目录里验证恢复脚本的失败路径（无效数据库、运行中未退出、保护快照）。
4. `test:release-gate`：`Tests/Scripts/release_gate_test.sh`，用桩命令验证 `mise run check` 失败时不会推送 tag 或创建 Release。
5. `test`：Swift Testing 单测。
6. `build:release`：release 编译必须通过。

CI（`.github/workflows/ci.yml`）在 `macos-15` 上对 `main` 与 PR 执行同一入口；`release-build-verification.yml` 可手动触发，仅做源码与 release 构建验证，不持有签名私钥。

## 签名要求

开发和正式构建都必须使用稳定代码签名，禁止回退 ad-hoc：

- `deploy.sh` 与 `release.sh` 默认身份 `Nekutai`，可用 `CODESIGN_IDENTITY` 覆盖；身份为 `-` 或证书不存在时脚本直接退出。
- 稳定身份是辅助功能（TCC）授权可长期保留的前提：`deploy.sh` 原地覆盖二进制、只更新 Info.plist 字段，保留 bundle 目录与 inode，避免每次部署都要重新授权。
- 辅助功能授权无法随数据迁移或备份恢复，只能在系统设置中重新勾选。

## 部署开发版

```bash
mise run deploy   # 等价于 ./deploy.sh
```

`deploy.sh` 的行为：

1. 校验签名身份不是 `-`。
2. `swift build`（debug）并用 `tail -3` 保留输出。
3. `pkill -f "TextFlash Dev.app"`，最多等 2 秒；只影响开发版。
4. 首次运行时创建 `~/Applications/TextFlash Dev.app` 结构。
5. 覆盖 `Contents/MacOS/TextFlash`，复制 `AppIcon.icns`、SwiftPM 资源包 `TextFlash_TextFlash.bundle`、`Tools/*.sh`（并赋可执行位）。
6. 版本号写入 `Info.plist`：`<最近 tag>-dev+<short hash>`，`CFBundleVersion` 为 short hash，bundle id 固定 `com.nekutai.textflash.dev`。
7. 删除旧 `_CodeSignature` 后 `codesign --force --deep --sign <身份>`；失败即退出，不回退 ad-hoc。
8. `open` 开发版应用。

调试构建可通过“Debug 版右键菜单 → 调试面板”查看 tap 状态、输入缓冲、缩写表与事件日志尾部（面板读取 `/tmp/textflash_events.log`，该文件只有在额外打开日志写入时才存在，见 [`customization-inventory.md`](customization-inventory.md)）。

## 资源与本地化

- `Sources/TextFlash/Resources/Assets/`：`AppIcon.icns`、`MenuBarIcon.svg`、`MenuBarIconDev.svg`。
- `Sources/TextFlash/Resources/zh-Hans.lproj`、`en.lproj`：全部用户可见文案；新增 key 必须同时补齐两种语言。
- `Sources/TextFlash/Resources/Tools/`：`textflash-backup.sh`、`textflash-restore.sh`，随应用分发，`release.sh` 会校验可执行位。
- `Resources/`（仓库根）：DMG 背景图；`scripts/layout_dmg.applescript` 负责 Finder 视图布局。

本地化读取走 `L10n.t` / `L10n.f`，直接读 `UserDefaults` 中的语言键，因此后台线程也可安全调用。资源包必须通过 `AppResourceBundle.main` 定位：打包后的 `.app` 里不得触发 `Bundle.module`，否则 SwiftPM 会去探测 `~/Documents/.../.build` 路径并弹出“文件与文件夹”授权窗口。

预览代码统一包在 `#if !DISABLE_PREVIEWS` 中，CI 与部署构建都传 `-DDISABLE_PREVIEWS`。

## 测试

- 框架：Swift Testing（`import Testing`），测试目标 `Tests/TextFlashTests`。
- 现有覆盖：Trie 匹配（前缀等待、最长后缀、共享前缀删除、Unicode 字素）、变量处理（日期/剪贴板/转义/诊断）、片段 JSON 校验与规范化、CLI 参数解析、数据库失败与迁移、AX 写入快照判定（识别静默失败）、更新安装脚本契约、更新诊断读取上限、资源包候选路径、版本号显示回退、签名配置（脚本不得出现 ad-hoc 回退）。
- 脚本测试：`Tests/Scripts/` 下的恢复行为与发布门禁用例，全部在临时目录运行，不触碰真实应用数据。
- 不为 UI 外观写单测或快照；涉及页面流程时使用仓库既有脚本入口或人工验收。

新增测试按风险取舍：纯逻辑、稳定契约、安全边界与缺陷回归优先；静态配置与简单透传用构建或验收覆盖。

## 常见陷阱

- 事件 tap 回调运行在键盘事件线程，禁止放入磁盘、网络或长字符串处理；需要延时的工作放到 `DispatchQueue.main.asyncAfter`。
- 注入事件必须带 `eventSourceUserData = "SNIP"` 并使用 `.privateState`，否则会被自身 tap 再次处理。
- 键盘监听只在 `keyDown` 上工作；新增事件类型时同步 `eventMask`。
- 修改 AX 写入路径后要人工验收“AX 假成功”场景（Electron/WebView/终端），确认不会重复写入。
- 片段/配置 JSON 的导出必须继续使用 `SnippetBackup.encode` 的 `prettyPrinted + sortedKeys`，保证 GUI 与 CLI 格式一致。
- 数据库初始化失败时界面必须报错，不允许以“空列表”伪装成功。

## 人工验收清单（涉及注入/权限时）

1. 在普通原生应用（如备忘录）展开含 `{cursor}`、`{datetime:}`、`{clipboard}` 的片段。
2. 在 Electron 或终端应用展开，确认回退 Unicode 后内容只出现一次。
3. 在密码框内输入缩写，确认不展开。
4. 撤销/重做、粘贴快捷键（⌘V/⌘Z）在 TextFlash 窗口内正常。
5. 关闭所有窗口后 Dock 图标消失，点击菜单栏图标可再次打开。
