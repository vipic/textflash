# 架构与模块

本页描述 TextFlash 当前代码如何协作。历史选择通过 Git 查询；开发命令、发布步骤和按应用定制分别见 [`DEVELOPMENT.md`](../DEVELOPMENT.md)、[`RELEASE.md`](../RELEASE.md) 与 [`customization-inventory.md`](../customization-inventory.md)。

## 文本展开数据流

```text
CGEvent tap
  → EventController 维护输入缓冲并识别触发字符
  → SnippetMatcher 查询缩写
  → VariableProcessor 展开变量
  → 优先通过 Accessibility 写入
  → 不兼容应用回退到 Unicode 键盘事件
```

事件回调必须保持轻量；磁盘、网络和大量字符串处理不得阻塞键盘事件线程。应用自身 bundle 不作为输入目标，安全输入框禁止展开。

## 模块边界

| 模块 | 职责 |
|---|---|
| `Core/` | 数据模型、事件监听、缩写匹配与变量处理 |
| `CLI/` | 在 GUI 启动前执行片段和配置导入导出 |
| `Persistence/` | SQLite、偏好、备份归档和主线程状态桥接 |
| `UI/` | 菜单栏、片段管理、编辑、主题、更新与诊断界面 |
| `Settings/` | 设置窗口与应用列表配置 |
| `Utils/` | 版本、登录项、资源定位、自更新检查与安装脚本生成 |
| `Resources/` | 本地化、图标和随应用分发的备份恢复工具 |

根目录 `TextFlashApp.swift` 是应用入口；`Generated/Version.generated.swift` 由发布流程注入版本，不作为手工事实来源。

## 持久化

- 片段保存在 Application Support 下的 SQLite 数据库。
- 设置保存在 UserDefaults；片段与设置通过 CLI 分别导入导出。
- 覆盖导入前创建备份，备份数量和恢复规则以当前实现与测试为准。
- 辅助功能授权由 macOS TCC 按代码身份和机器管理，不能随数据备份迁移。

## 必须保持的不变量

- 正式版和开发版使用稳定代码签名，禁止回退到 ad-hoc。
- Event tap source 与相关 Timer 使用 common run-loop mode，避免菜单跟踪期间漏事件。
- 注入事件使用 private event source，避免被自身的 event tap 再次处理。
- 权限不足时提供用户可见引导，不在启动时反复弹系统授权框。
- 更新安装前校验 bundle id、版本和 designated requirement；替换失败时恢复旧应用。
- 新增按应用写死的兼容逻辑时，同步更新定制化清单，并优先考虑可配置策略。

## 验证

修改职责、数据流或上述不变量时同步更新本页。运行 `mise tasks` 确认入口，并以 `mise run check` 作为统一验证；涉及真实文本注入、权限或更新安装时补做对应人工验收。
