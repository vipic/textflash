# mise 任务速查

真实执行入口仍是仓库里的 shell 脚本与 SwiftPM 命令；`mise`（`mise.toml`）只负责把它们收束成统一命令面板。

## 准备

```bash
brew install mise
mise trust
mise tasks
```

## 任务列表

| 任务 | 说明 |
| --- | --- |
| `mise run build` | Debug 编译（`-DDISABLE_PREVIEWS`） |
| `mise run build:release` | Release 编译（`-c release -Osize -DDISABLE_PREVIEWS`） |
| `mise run test` | Swift 单测（`swift test -DDISABLE_PREVIEWS`） |
| `mise run check` | 统一验证：脚本语法、设计 token、恢复测试、发布门禁测试、单测、release 编译 |
| `mise run lint:scripts` | 对全部 shell 脚本执行 `bash -n` |
| `mise run lint:design` | 检查颜色字面量只出现在 `Sources/TextFlash/UI/SoftTheme.swift` |
| `mise run test:restore` | 恢复脚本失败路径测试（临时目录） |
| `mise run test:release-gate` | 验证 `mise run check` 失败时不会推送/发布 |
| `mise run deploy` | 编译、签名并启动 `~/Applications/TextFlash Dev.app` |
| `mise run release -- <x.y.z> [--allow-dirty] [--publish]` | 构建 DMG（可发布） |
| `mise run release-auto` | 按提交计算版本并构建本地 DMG |
| `mise run publish -- <x.y.z>` | 构建并创建 GitHub Release，版本必须显式指定 |
| `mise run smoke:release -- <dmg> <x.y.z>` | 复核已有 DMG：挂载、复制、签名校验、启动冒烟 |
| `mise run logs:release [-- --full]` | 最近一次发布日志摘要（`--full` 为完整日志） |
| `mise run logs:publish [-- --full]` | 最近一次发布到 GitHub 的日志 |
| `mise run version:current` | 打印最高 SemVer 发布 tag |
| `mise run version:next` | 打印按提交计算的下一版本 |

## 说明

- `release`、`release-auto`、`publish` 的参数必须放在 `--` 之后，例如 `mise run release -- 1.2.3`。
- `publish` 会拒绝 `--` 后为空或以 `--` 开头的第一个参数，避免误用自动版本发布。
- `check` 是唯一要求的验证入口；CI 在 `macos-15` 上执行同一命令。
- 发布与部署细节分别见 [`RELEASE.md`](RELEASE.md) 与 [`DEVELOPMENT.md`](DEVELOPMENT.md)。
