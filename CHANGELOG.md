# Changelog

面向用户的版本说明。GitHub Release 的 commit 列表由 `release.sh` 自动生成；本文件用白话记录「对日常使用有影响」的变化。

发布新版本时：把 `Unreleased` 里的条目挪到对应版本节，并按需补充用户可见说明。0.1.2 至 1.2.1 期间未维护本文件，这些版本的变更见各 [GitHub Release](https://github.com/vipic/textflash/releases) 说明。

## Unreleased

- Added a command-line interface for exporting and importing snippets and user settings as JSON (same snippet format as the GUI; snippet imports auto-back up before overwriting, keeping the latest 20 backups).

## 0.1.1 — 2026-06-06

- Added a settings window with app language selection and localized menu/settings/debug strings.
- Added a launch-at-login control backed by macOS ServiceManagement.
- Localized the snippet manager, snippet editor, permission prompts, and exclusion alerts.
- Added a replacement timing setting for slower chat inputs that process deletion asynchronously.
- Refined the debug panel layout and only show its menu entry in debug builds.
- Copy SwiftPM resource bundles into generated development and release app bundles.
- Fixed trigger-character expansion so TextFlash no longer leaves partial abbreviations or duplicates trigger characters.
- Added conservative secure-field handling and application exclusion controls.
- Show accessibility permission status in the manager and debug windows.
- Added pause/resume controls with menu bar status feedback.
- Re-enable the keyboard event tap automatically when macOS disables it.
- Keep the running state in sync when keyboard event tap creation fails.
- Harden Accessibility element handling to fail safely instead of force-casting unexpected values.
- Allow expansion in apps that do not expose a focused Accessibility element unless a secure field is explicitly detected.
- Try Accessibility selected-text insertion before Unicode event injection without touching the system pasteboard.
- Wait for abbreviation deletion to settle before inserting expansion text to avoid Telegram-style delayed backspaces corrupting output.
- Added JSON import/export, import validation, overwrite confirmation, and automatic pre-import backups.
- Accept wrapped backups, raw group arrays, and single-group JSON when importing snippets.
- Added a manager toolbar action to open the automatic backup directory.
- Added transaction-backed database updates and surfaced write failures in the manager UI.
- Avoid crashing when the database directory or SQLite connection cannot be initialized.
- Added exclusion-list management, including add current app, remove, and clear actions.
- Refresh exclusion UI from exclusion-change notifications and show an error when no target app is available.
- Use the last non-TextFlash foreground app as the exclusion target so TextFlash windows do not exclude themselves.
- Extracted snippet matching into a testable matcher with unit coverage.
- Hardened release packaging with tests, signing checks, cleanup, and DMG signing (release artifacts are self-signed and not notarized).
- Added Accessibility usage descriptions to generated development and release app bundles.
- Prevented release packaging from stripping SwiftPM build artifacts and added clean-tree checks for publishing.
- Added CI for shell syntax checks, Swift tests, and release builds.
- Added project README with development, backup, exclusion, and release workflows.
