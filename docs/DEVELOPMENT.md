# Development

本文档记录 TextFlash 的本地开发、构建和签名要求。发布流程见 [RELEASE.md](RELEASE.md)。

## 环境要求

- macOS 13+
- Swift 6.0 toolchain（`Package.swift` 为 `swift-tools-version: 6.0`，语言模式显式钉 `.v5`）
- Xcode Command Line Tools

## 快速部署开发版

```bash
git clone https://github.com/vipic/textflash.git
cd textflash
./deploy.sh
```

`deploy.sh` 会编译 debug 版本、组装并签名 `~/Applications/TextFlash Dev.app`，然后启动应用。

## 代码签名

macOS 的辅助功能权限绑定到应用签名。TextFlash 必须使用稳定代码签名：自签名代码签名证书或开发者账号证书都可以；不要使用 ad-hoc 签名。ad-hoc 每次重新编译都可能改变代码身份，导致辅助功能授权反复失效。

脚本默认使用证书名 `Nekutai`。如果你想用自己的证书名，通过环境变量覆盖：

```bash
export CODESIGN_IDENTITY="Your Certificate Name"
```

创建自签名证书：

```text
Keychain Access -> 证书助理 -> 创建证书
名称: Nekutai
身份类型: 自签名根
证书类型: 代码签名
```

证书缺失、签名失败或显式设置 `CODESIGN_IDENTITY="-"` 时，`deploy.sh` 和 `release.sh` 会直接停止，不会改用 ad-hoc。

## 本地构建

只确认 debug 编译：

```bash
swift build -Xswiftc -DDISABLE_PREVIEWS
```

只确认 release 编译：

```bash
swift build -c release -Xswiftc -Osize -Xswiftc -DDISABLE_PREVIEWS
```

这只会生成 SwiftPM 可执行文件，不会组装 `.app` 或 DMG。完整发布包请使用（`1.2.3` 仅为格式示例）：

```bash
./release.sh 1.2.3
```

## mise 入口

如果使用 `mise`，可以通过统一任务入口执行常用命令：

```bash
mise run check
mise run deploy
mise run release-auto
```

发布阶段日志可通过 `mise run logs:release` 和 `mise run logs:publish` 查看；附加 `-- --full` 输出完整命令日志。

完整任务列表见 [MISE.md](MISE.md)。

### 测试边界

缩写匹配使用纯逻辑测试覆盖最长后缀优先、较长前缀等待、共享 Trie 分支删除、Unicode 字素、替换和清空，避免依赖真实键盘注入。

CI 工作流通过配置审阅确认，不用源码字符串断言复刻 YAML。`mise run check` 中的 `test:release-gate` 在隔离目录注入检查失败，验证不会继续推送或创建发布；备份恢复行为测试和签名边界检查继续保留。

备份保留策略仅清理 `textflash-snippets-*.json`，同目录其他 JSON 文件不参与清理。
