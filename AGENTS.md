# AGENTS

本仓是 macOS 菜单栏文本展开工具，使用 Swift、SwiftUI 和 SwiftPM，运行时零第三方依赖。

## 项目专属规则

- 当前模块、数据流和关键不变量见 `docs/architecture/README.md`；开发、发布和定制化说明分别见 `docs/DEVELOPMENT.md`、`docs/RELEASE.md` 与 `docs/customization-inventory.md`，不要在本文件复制完整目录树。
- 全局 CGEvent tap 回调保持轻量，注入事件不得被自身再次处理；安全输入框必须禁止展开。
- 辅助功能授权依赖稳定代码身份。开发和正式构建均使用既有签名链路，证书缺失时停止，不回退到 ad-hoc。
- 新增按应用或场景写死的兼容逻辑时同步定制化清单，并优先考虑现有可配置入口。
- 修改后先运行 `mise tasks`，统一执行 `mise run check`；涉及真实文本注入、权限或更新安装时补做对应人工验收。

<!-- workspace-policy:start hash=8d4d8c94cf45 -->
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
- [TEST-001] 测试按风险添加，优先覆盖非平凡逻辑、稳定契约、安全边界和缺陷回归；静态配置与简单透传通常使用语法检查、构建或验收验证，不因每次改动机械新增测试。

### 依赖

- [DEPS-001] 改动保持最小，不引入项目基线之外的新框架、构建工具或生产依赖，除非用户明确要求。

### 文档

- [DOCS-001] 行为、命令或部署方式变化时同步 README 和相关文档，不保留过期引用。
- [DOCS-002] 跨仓依赖只记录本仓消费的稳定接口契约与验证方式；提供方的配置项、内部结构和操作步骤由其所属仓库维护，不在消费方重复复制。

### 工具链

- [MISE-001] 先运行 `mise tasks` 查看入口；构建、测试和部署统一使用 `mise run <task>`，不绕过 mise 手拼命令。

### macOS 应用

- [SWIFT-001] 使用 SwiftPM executable（swift-tools 6.0）和既有脚本组装应用，不新增 Xcode project。
- [SWIFT-002] 保持 Nekutai 自签名链路与 `com.nekutai.*` bundle id，严禁 ad-hoc 签名。

### macOS 发布

- [SWIFT-003] 新增 shell 脚本纳入 `lint:scripts`；发布继续使用既有 release.sh、DMG 和 GitHub Release 流程。
- [SWIFT-004] 正式发布必须验收最终 DMG：挂载后复制 App 到隔离临时目录，校验 bundle id、版本、关键资源与非 ad-hoc 签名，并完成真实启动冒烟；任一步失败都停止发布。
- [SWIFT-005] 发布说明从上一个正式标签到目标提交生成，保留逐条用户可见变更；release、tag 与同版本制品不得静默覆盖。

### macOS 自更新

- [SWIFT-006] 安装应用内更新前必须校验目标 bundle id、预期版本和代码签名 designated requirement，不得只比较证书名称或 Team ID。
- [SWIFT-007] 替换现有 App 前先备份旧版本；复制失败或安装后版本不符时恢复旧 App，并保留诊断日志和用户可见错误。
<!-- workspace-policy:end -->
