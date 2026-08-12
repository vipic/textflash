<p align="center">
  <img src="docs/screenshots/icon.png" width="96" alt="TextFlash icon">
</p>

<h1 align="center">TextFlash</h1>

<p align="center">
  <strong>macOS 菜单栏文本展开工具</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0%2B-blue" alt="macOS 13.0+">
  <img src="https://img.shields.io/badge/Swift-6.0-orange" alt="Swift 6.0">
  <a href="https://github.com/vipic/textflash/releases"><img src="https://img.shields.io/github/v/release/vipic/textflash" alt="GitHub Release"></a>
</p>

<p align="center">
  <a href="#功能特点">功能</a> ·
  <a href="#安装">安装</a> ·
  <a href="#开发">开发</a> ·
  <a href="#文档">文档</a> ·
  <a href="#关联项目">关联项目</a>
</p>

TextFlash 是一款 macOS 菜单栏文本展开工具，基于 SwiftUI 和 SQLite 构建。

## 功能特点

- **缩写展开**：输入缩写后自动替换为常用文本，支持剪贴板、日期等变量。
- **片段管理**：按分组维护片段，可通过 JSON 导入、导出和迁移。
- **应用适配**：可排除指定应用，也可为终端、Electron 等应用切换 Unicode 输入。
- **本地存储**：片段保存在本机 SQLite 数据库，不依赖云端服务。
- **备份恢复**：提供应用内自动备份，以及可供外部自动化调用的命令行工具。

## 安装

从 [GitHub Releases](https://github.com/vipic/textflash/releases) 下载最新 DMG，打开后将 `TextFlash.app` 拖入 `/Applications`。

当前发布产物没有开发者账号签名和公证，首次打开时可能需要在系统设置中允许运行。文本展开需要 macOS 辅助功能权限；如果无法触发展开，请在设置中检查权限状态。

菜单栏中，**左键**打开片段管理，**右键**打开菜单（检查更新、设置、Unicode 输入等）。

## 开发

运行测试：

```bash
mise run test
```

本地构建：

```bash
mise run build
```

部署开发版应用到 `~/Applications/TextFlash Dev.app`：

```bash
mise run deploy
```

也可以查看所有项目任务：

```bash
mise tasks
```

完整 mise 命令速查见 [docs/MISE.md](docs/MISE.md)。常用入口：

```bash
mise run ci
mise run deploy
mise run release-auto
```

CI（GitHub Actions）与本地一致，执行 `mise run ci`（脚本语法检查 + `swift test` + release 构建）。源码按 `Core / Persistence / UI / Settings / Utils` 分层，Agent 约定见 [`AGENTS.md`](AGENTS.md)。重要变更详见 `CHANGELOG.md`。

## 片段管理

片段以 SQLite 格式存储在 Application Support 目录下。管理窗口支持 JSON 导入导出。导入兼容 TextFlash 备份 JSON、原始分组数组或单个分组对象。导入前会校验备份数据，覆盖现有数据前自动生成备份。

自动导入备份路径：

```text
~/Library/Application Support/TextFlash/Backups
```

应用最多保留 20 份自动备份。

使用管理工具栏中的文件夹按钮可快速打开备份目录。

## 应用排除

在设置中可管理排除列表与 Unicode 输入应用。排除列表按 bundle identifier 存储在 `UserDefaults` 中。菜单栏右键可快速将当前应用加入 Unicode 输入列表。

## 命令行备份与恢复

安装后的 app 内置了备份和恢复脚本，方便外部自动化调用：

```bash
"/Applications/TextFlash.app/Contents/Resources/Tools/textflash-backup.sh"
"/Applications/TextFlash.app/Contents/Resources/Tools/textflash-restore.sh" --launch "$HOME/Backups/TextFlash/20260620-120000"
```

备份内容包含片段数据库和当前版本对应的偏好设置。登录项由 macOS 管理，恢复后需要在设置里重新确认。

## 命令行片段与配置导入导出

直接调用 app 可执行文件即可导出/导入片段和配置（JSON 格式），无需启动 GUI：

```bash
# 导出全部片段（与 GUI 导出格式一致，默认输出到 stdout）
"/Applications/TextFlash.app/Contents/MacOS/TextFlash" export snippets --output ~/Desktop/snippets.json

# 导入片段（校验通过后替换全部片段，覆盖前自动备份到 Backups 目录）
"/Applications/TextFlash.app/Contents/MacOS/TextFlash" import snippets ~/Desktop/snippets.json

# 导出/导入用户配置
"/Applications/TextFlash.app/Contents/MacOS/TextFlash" export config -o ~/Desktop/config.json
"/Applications/TextFlash.app/Contents/MacOS/TextFlash" import config ~/Desktop/config.json

# 帮助
"/Applications/TextFlash.app/Contents/MacOS/TextFlash" --help
```

导出的配置包含语言、替换时序、触发匹配模式、开机启动、Unicode 输入应用 Bundle ID 与排除应用 Bundle ID。辅助功能授权由 macOS 按机器管理（TCC），无法迁移，不包含在配置中。开发版可替换为 `~/Applications/TextFlash Dev.app/Contents/MacOS/TextFlash`。

## 文档

- [更新日志](CHANGELOG.md)：面向用户的版本说明。
- [开发说明](docs/DEVELOPMENT.md)：本地开发、构建和签名要求。
- [发布流程](docs/RELEASE.md)：版本号、DMG、GitHub Releases、自动更新排查。
- [mise 命令速查](docs/MISE.md)：全部项目任务入口。
- [定制化逻辑清单](docs/customization-inventory.md)：当前按应用/场景写死的逻辑与已知限制。
- [Agent Onboarding](AGENTS.md)：给代码代理使用的架构、坑点和约定。

## 关联项目

- [Pastry](https://github.com/vipic/pastry)：记录、搜索和回看临时剪贴板历史；TextFlash 更适合长期、高频文本，两者互补。
- [mac-as-code](https://github.com/vipic/mac-as-code)：可安装 TextFlash，并备份、恢复片段和应用配置的 macOS 配置脚本。

## 发布

完整发布流程见 [docs/RELEASE.md](docs/RELEASE.md)。本地签名要求见 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)。

构建 DMG：

```bash
mise run release -- 0.1.0
```

按 git message 自动计算下一个版本并构建 DMG：

```bash
mise run release-auto
```

发布产物会写入 `dist/`。默认使用稳定代码签名证书 `Nekutai`（可通过 `CODESIGN_IDENTITY` 覆盖）；不支持 ad-hoc 回退。

默认运行测试。跳过测试仅打包查看：

```bash
RUN_TESTS=false mise run release -- 0.1.0
```

发布到 GitHub Releases：

```bash
mise run release -- 0.1.0 --publish
```

`--publish` 需要在 `main` 分支、Git 工作区干净，脚本会推送 tag 并创建 GitHub Release。
