# 应用备注

## 设计资产

| 资产 | 路径 | 用途 |
| --- | --- | --- |
| 应用图标 | `Sources/TextFlash/Resources/Assets/AppIcon.icns` | 打包进 `Contents/Resources/AppIcon.icns`，关于/更新窗口使用 `NSApp.applicationIconImage` |
| 菜单栏图标 | `Sources/TextFlash/Resources/Assets/MenuBarIcon.svg` | 正式版状态栏模板图标（`isTemplate = true`） |
| 菜单栏图标（开发） | `Sources/TextFlash/Resources/Assets/MenuBarIconDev.svg` | 版本号含 `-dev` 或 bundle id 以 `.dev` 结尾时使用 |
| DMG 背景 | `Resources/dmg-background.png`、`Resources/dmg-background@2x.png` | `release.sh` 写入 DMG 的 `.background/` |
| 文档图标 | `docs/screenshots/icon.png` | README 顶部展示 |

视觉样式集中在 `Sources/TextFlash/UI/SoftTheme.swift`：窗口底色、玻璃面板、字段、边框、强调色、警告/成功状态与三级文字色。其他文件只能引用这些 token，`mise run lint:design` 会拒绝新增颜色字面量。

## 图标生成 Prompt

```text
A pixel art illustration. A stylized lightning bolt shaped like the letter "T", 16-bit cyberpunk terminal style, with electric blue and neon cyan glow pixels radiating outward. Tiny pixel text characters "ab" on the left side of the bolt transforming into spark-like pixel particles that fly into the bolt. Dark navy to deep indigo pixel gradient background with subtle scanline grid and a few floating pixel data dots. Clean pixel edges, limited high-contrast color palette, retro hacker terminal aesthetic. No text labels, no words, no frame, no border, no rounded corners, no icon shape. Sharp, sleek, tech-forward.
```

## DMG 布局

`scripts/layout_dmg.applescript` 在挂载的可写镜像上设置：图标视图、120px 图标、13pt 文字、DMG 背景图，App 位置 `{140, 167}`，`Applications` 链接位置 `{401, 167}`，窗口范围 `{200, 200, 740, 550}`。布局写入后必须存在 `.DS_Store` 与背景文件，否则 `release.sh` 中止。

## 文案

用户可见文案全部来自 `Sources/TextFlash/Resources/{zh-Hans,en}.lproj/Localizable.strings`。中文为默认本地化（`defaultLocalization: "zh-Hans"`），新增 key 必须两份同时补齐，否则英文环境会回退到中文字符串。
