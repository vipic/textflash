# 发布流程

本页覆盖版本号计算、DMG 构建与验收、GitHub Release 发布、应用内自动更新与日志诊断。开发环境见 [`DEVELOPMENT.md`](DEVELOPMENT.md)。

## 版本号

版本来自 git tag（`v<major>.<minor>.<patch>`）：

```bash
mise run version:current   # 最高的 SemVer 发布 tag
mise run version:next      # 根据提交计算下一个版本
```

`scripts/next_version.sh` 的规则（只看最近 tag 到 `HEAD` 的非合并提交）：

| 提交特征 | 结论 |
| --- | --- |
| `type!:` 或 `BREAKING CHANGE:` | major |
| `feat:` / `feat(scope):` | minor |
| `fix:` / `perf:` | patch |
| 其他非空提交 | `VERSION_BUMP_FALLBACK`，默认 patch |
| 无提交 | 保持当前版本 |

多处同时出现时取最高影响级别。

## 发布入口

| 命令 | 行为 |
| --- | --- |
| `mise run release -- 1.2.3` | 构建 `dist/TextFlash-1.2.3.dmg` |
| `mise run release -- 1.2.3 --allow-dirty` | 本地脏工作区验收，禁止与 `--publish` 同时使用 |
| `mise run release -- 1.2.3 --publish` | 构建 + 推 tag + 创建 GitHub Release |
| `mise run release-auto` | 自动计算版本并构建本地 DMG（不允许发布） |
| `mise run publish -- 1.2.3` | 等价于 `release.sh 1.2.3 --publish`，必须显式给版本 |
| `mise run smoke:release -- dist/TextFlash-1.2.3.dmg 1.2.3` | 单独复核已有 DMG |

`release.sh` 的前置检查：

- `--publish` 与 `--allow-dirty` 不能同时使用；工作区有未提交改动时必须显式 `--allow-dirty`。
- 签名身份必须是有效证书，`-` 或证书不存在直接退出（不回退 ad-hoc）。
- 本地标签已存在、远端标签已存在、同名 GitHub Release 已存在时拒绝继续。
- `--publish` 额外要求：当前分支为 `main`、安装 `gh`、存在 `origin`、`gh auth status` 通过。

## release.sh 的八个阶段

1. **统一验证**：`mise run check`；验证后若工作区被改变且未传 `--allow-dirty`，停止发布。
2. **注入版本号**：写入 `Sources/TextFlash/Generated/Version.generated.swift`，`build` 取 `git rev-list --count HEAD`。
3. **Release 编译**：`swift build -c release -Osize -DDISABLE_PREVIEWS`。
4. **去除调试符号**：`strip -S`，记录前后体积。
5. **组装 `.app`**：二进制、`AppIcon.icns`、资源包、`Tools/*.sh`（赋可执行位）、手写 Info.plist（bundle id `com.nekutai.textflash`、版本、`LSMinimumSystemVersion=13.0`、`LSUIElement=true`、辅助功能说明）。
6. **签名与验收**：`codesign --force --deep --sign <身份>`，随后 `scripts/verify_release.sh` 检查文件齐全、版本、bundle id、最低系统版本、LSUIElement、`codesign --verify --deep --strict`，并拒绝 ad-hoc 签名。
7. **DMG 打包与烟测**：`hdiutil` 创建可写镜像 → 挂载 → `scripts/layout_dmg.applescript` 写入 Finder 布局与背景 → 校验 `.DS_Store` 与背景文件存在 → 卸载 → 转 UDZO → `hdiutil verify` → 生成 `.sha256` → `scripts/release_smoke.sh`。
8. **发布（可选）**：`--publish` 时用 `scripts/generate_release_notes.sh` 生成说明，打 annotated tag，`git push --atomic origin HEAD:refs/heads/main refs/tags/<tag>`，再 `gh release create` 上传 DMG 与校验文件；任一步失败回滚本地（和已推送的）标签，不覆盖既有制品。

退出时 `trap cleanup` 会重新挂载/卸载残留卷、删除 `.release_staging`，并把 `Version.generated.swift` 复位为 `0.0.0-dev` / `0`，避免开发构建带上发布版本号。

## 制品验收（`scripts/release_smoke.sh`）

1. 校验 DMG 存在、签名身份不是 `-`、钥匙串中有该证书。
2. 只读挂载到临时目录，确认存在指向 `/Applications` 的拖放链接，`ditto` 复制到隔离的 `/tmp/textflash-release-smoke.*` 目录并卸载。
3. 对复制出的 App 跑 `verify_release.sh`。
4. 编译 `TextFlashReleaseSmoke` 辅助进程，用同一身份签名后 `open -n -F` 启动复制出的 App。
5. 通过可执行文件路径定位进程，校验 bundle id、`activationPolicy == .accessory`、应用图标尺寸非零。
6. 清理临时目录并结束进程。

任一步失败即中止发布；该脚本也用于复核历史 DMG：

```bash
mise run smoke:release -- dist/TextFlash-1.2.3.dmg 1.2.3
```

## 发布日志与诊断

`scripts/lib/command_log.sh` 把每个阶段与命令写入被 `.gitignore` 忽略的 `.local/logs/<release|publish>/<时间戳>-<pid>.log`，并维护 `latest.log` 符号链接。

```bash
mise run logs:release          # 阶段与命令摘要
mise run logs:publish          # 同上，针对发布流程
mise run logs:release -- --full  # 完整日志
```

构建结束后终端会打印各阶段耗时汇总。发布失败时先看 `latest.log` 中 `exit_code` 非 0 的 `command.finish` 行。

## 应用内自动更新

- 检查：`UpdateChecker` 请求 GitHub `repos/vipic/textflash/releases/latest`，非强制模式 24 小时一次，开发版直接跳过；只取第一个 `.dmg` 资产。
- 下载：仅 HTTPS，`expectedContentLength` 与累计字节均不超过 300 MB，字节数与 Release 声明不一致即失败，进度回调事件驱动。
- 安装：把 DMG 移到临时目录、写出安装脚本并用 `/usr/bin/nohup` 拉起，然后应用退出。脚本参数为 `dmg 目标App 期望版本 当前PID 诊断目录`。
- 安装校验：挂载 DMG → 确认存在 `TextFlash.app` → `CFBundleIdentifier == com.nekutai.textflash` → `CFBundleShortVersionString == 期望版本` → `codesign --verify --deep --strict` → 拒绝 `Signature=adhoc` → 比较当前与候选 App 的 designated requirement；不一致时只在双方 Authority 均为 `Nekutai` 时放行（证书轮换，辅助功能可能需重新授权），否则中止并提示手动下载。
- 替换：`mv` 旧 App 为同目录隐藏备份 → `cp -R` 新 App → 复核版本 → 删除备份；复制失败或版本不符时恢复旧 App 并写错误报告。
- 诊断：日志 `~/Library/Application Support/TextFlash/update.log`；错误写入同目录 `update_error.txt`，下次启动读取前 2 KB 展示后删除。日志与错误只包含路径/版本/校验结论，不包含用户内容。

## 发布前检查清单

1. `mise run check` 通过，工作区干净，提交符合 Conventional Commits（生成更新日志用提交标题）。
2. 确认版本号未被占用：本地/远端 tag、GitHub Release 均不存在。
3. 确认钥匙串中存在 `Nekutai` 或通过 `CODESIGN_IDENTITY` 指定稳定证书。
4. `mise run release -- <版本>` 产出 DMG 与 `.sha256`，并检查烟测输出。
5. 需要发布时在 `main` 上执行 `mise run publish -- <版本>`，确认 tag、Release 与制品 URL。
6. 发布后进行真实安装冒烟：挂载 DMG → 复制 App 到隔离目录 → 校验 bundle id、版本、资源与签名 → 启动并完成一次文本展开。
7. 检查应用内更新：旧版本能检查到新版本、下载安装成功、辅助功能权限状态符合预期。
