# 定制化逻辑清单

这份清单记录当前项目里按应用、场景或个人路径写死的逻辑，作为现状和已知限制的备忘。

## 按应用定制

| 位置 | 当前做法 | 已知限制 |
| --- | --- | --- |
| `Sources/TextFlash/Core/EventController.swift` | `shouldPreferUnicodeInsertionForFocusedApplication()` 对 Codex、iTerm、Terminal、Electron 相关 Bundle ID 或应用名直接走 Unicode 注入 | 新增不兼容应用需要改代码发布；基于 `contains` 的匹配容易误伤 |
| `Sources/TextFlash/Core/EventController.swift` | 通过 `lastNonTextFlashApplication` 避免把 TextFlash 自己当作排除目标 | 这是菜单栏应用常见场景，但仍是 TextFlash 自身行为的特殊处理 |

## 按场景定制

| 位置 | 当前做法 | 已知限制 |
| --- | --- | --- |
| `Sources/TextFlash/Core/EventController.swift` | 退格后按 `deletionSettleDelayPerCharacter` 等待，覆盖 Telegram 类应用异步处理退格的场景 | 通过全局延迟覆盖所有应用，慢应用和快应用无法分别调优 |
| `Sources/TextFlash/Core/EventController.swift` | 优先 Accessibility 设置选中文本，失败后回退 Unicode 注入 | 这是合理的通用降级，但缺少可观测的失败原因和策略记录 |
| `Sources/TextFlash/Core/EventController.swift` | 检测 `AXIsSecureTextField` 和 `AXSecureTextField` 后禁用展开 | 安全场景必须保留，但目前检测逻辑散落在事件控制器里 |
| `Sources/TextFlash/Core/EventController.swift` | 将中文标点 `，。？、` 归一为英文触发符 | 这属于输入法场景定制，当前规则固定 |

## 个人路径约束（防回归）

- 禁止依赖个人本机路径（如 `~/Documents/...`）做自动迁移或自动导入。JSON 数据一律走管理窗口的手动导入/导出。
