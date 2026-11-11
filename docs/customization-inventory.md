# 定制化逻辑清单

记录当前代码里按应用、场景或个人路径写死的逻辑，作为现状与已知限制的备忘。新增此类逻辑时同步更新本表，并优先提供可配置入口。

## 按应用定制

| 位置 | 当前做法 | 已知限制 |
| --- | --- | --- |
| `Core/EventController.swift` | 用户在设置或右键菜单把应用加入 `TextFlashUnicodeBundleIDs`，列表内应用直接走 Unicode 注入 | 需要用户手动配置；菜单栏“当前应用用 Unicode 输入”依赖能取到目标应用，取不到时提示改用“选择应用” |
| `Core/EventController.swift` | AX 写入返回成功但 `AXNumberOfCharacters` / `AXSelectedTextRange` 快照未变化时，60ms 复查仍无变化则回退 Unicode 并把该 bundle id 自动写入列表 | 应用不暴露上述属性时无法判断，只能信任 AX；异步更新超过复查窗口的应用可能被误判（有重复写入风险，靠二次复查缓解）；自动学习只在能取到 bundle id 时生效 |
| `Core/EventController.swift` | `lastNonTextFlashApplication` 记录最近一个非 TextFlash 前台应用；TextFlash 自身窗口内完全放行事件 | 这是菜单栏应用的通用处理，但它确实是按 bundle id 前缀 `com.nekutai.textflash` 写死的特例 |
| `UI/MenuBarManager.swift`、`Utils/UpdateChecker.swift` | 开发版判定：版本号包含 `-dev`，菜单栏另看 bundle id 是否以 `.dev` 结尾 | 两个判定条件不一致，改名或改版本格式时需要同步 |
| `UI/MenuBarManager.swift` | 状态栏图标资源名 `MenuBarIcon` / `MenuBarIconDev`，缺失时退化为绘制字母 “T” | 新增图标需同时更新这两个名字或保持回退可用 |
| `Utils/AppResourceBundle.swift` | 资源包名写死 `TextFlash_TextFlash.bundle`，按 `Contents/Resources`、`.app` 根目录顺序查找 | SwiftPM 产物改名会破坏打包后的资源定位 |
| `Utils/UpdateChecker.swift` | 更新源写死 GitHub 仓库 `vipic/textflash`，只取第一个 `.dmg` 资产 | 换仓库或改用其他分发方式需改代码 |
| `Utils/UpdateInstallScriptBuilder.swift` | 安装脚本写死 bundle id `com.nekutai.textflash`，并在 designated requirement 不一致时只放行双方 Authority 均为 `Nekutai` 的证书轮换 | 更换作者证书名称后需同步修改，否则自动更新会被拒绝 |
| `UI/DebugPanel.swift` | 事件日志固定读取 `/tmp/textflash_events.log` | 当前 `EventController` 不再写入该文件，面板通常显示“暂无日志”；固定世界可写临时路径也不适合存放任何敏感内容 |
| `Utils/AppVersionInfo.swift` | 生成值 `0.0.0-dev` 视为占位，显示回退到 bundle 版本，再回退 `0.1.0` | 占位字符串变更会影响 `MenuBarManager`、`UpdateChecker` 的开发版判定 |
| `release.sh`、`scripts/verify_release.sh` | 产物契约写死：bundle id、`LSMinimumSystemVersion=13.0`、`LSUIElement=true`、`AppIcon.icns`、`Tools/textflash-backup.sh`、`Tools/textflash-restore.sh` | 调整资源或最低系统版本要同步脚本与验收 |

## 按场景定制

| 位置 | 当前做法 | 已知限制 |
| --- | --- | --- |
| `Core/EventController.swift` | 把中文标点 `，。？、` 归一为 `, . ? \` 参与触发字符匹配 | 属于输入法场景定制，规则固定不可配置 |
| `Core/EventController.swift` | 退格后等待 `max(20ms, 退格数 × 每字符延迟)`，默认每字符 20ms（覆盖 Telegram 类异步处理退格的应用） | 全局统一延迟，快应用也被拖慢；只有单一滑块可调 |
| `Core/EventController.swift` | 优先 AX 写入选中文本，失败回退 Unicode；WebView（向上 10 层内出现 `AXWebArea`）直接走 Unicode | 属性不可观测时无法记录失败原因；层级上限写死 10 |
| `Core/EventController.swift` | 通过 `AXIsSecureTextField` 与 `subrole == AXSecureTextField` 双重检测后禁止展开 | 检测逻辑散落在事件控制器；无法识别的自绘密码框可能漏判 |
| `Core/EventController.swift` | 清除输入法组合（`discardMarkedText`）后固定等待 5ms 再发送退格；写入后固定等待 20ms 再移动光标 | 固定延时，极端慢速输入法可能仍错位 |
| `Core/EventController.swift` | 无触发字符的即时匹配只删除 `缩写长度 - 1`，由拦截的按键补全语义 | 与触发字符路径的删除数量不同，改动时需同时验证两条路径 |
| `Core/EventController.swift` | `isInjecting` 期间事件全部放行，避免注入被自身吞掉 | 注入窗口内用户输入会被目标应用直接接收 |
| `Core/EventController.swift` | Cmd/Ctrl 组合键直接清空缓冲，不参与匹配 | 不做应用级快捷键例外 |
| `Persistence/SnippetManager.swift` | 首次启动自动创建名为“通用”的分组 | 分组名不跟随语言设置 |
| `Persistence/SnippetBackupArchiver.swift` | 备份文件名前缀 `textflash-snippets-`，最多保留 20 份 | 数量上限与命名写死 |
| `CLI/CLIController.swift` | 导入文件上限 2 MB；配置字段全部缺失视为无效文件 | 上限不可配置 |
| `AppDelegate` | 有窗口时切 `.regular`，无窗口时切回 `.accessory` 并隐藏 Dock 图标 | 依赖手动维护的窗口列表，新增窗口需同步登记 |
| `AppDelegate` | 自己安装 ⌘C/⌘V/⌘X/⌘A/⌘Z/⇧⌘Z 本地快捷键转发（Settings-only App 没有稳定 Edit 菜单） | 只覆盖这几组快捷键，其他编辑动作依赖默认行为 |

## 个人路径约束（防回归）

- 禁止依赖个人本机路径（如 `~/Documents/...`）做自动迁移或自动导入；JSON 数据一律走管理窗口或 CLI 手动导入/导出。
- 数据库目录固定 `~/Library/Application Support/TextFlash`；恢复脚本支持 `TEXTFLASH_DATA_DIR` 覆盖，仅用于隔离测试。
- 备份脚本默认输出 `~/Backups/TextFlash/<时间戳>/`，可通过第一个参数覆盖；内容为 `textflash.db`、`preferences.plist`、`manifest.txt`。
- 开发版固定部署到 `~/Applications/TextFlash Dev.app`，与正式版并存。
- 发布与更新诊断只写应用专属数据目录（`~/Library/Application Support/TextFlash`）或系统临时目录下的短生命周期文件，不使用固定的世界可写路径。
