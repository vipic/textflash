import Foundation

/// 片段导入覆盖前的自动备份：把当前全部片段写成 JSON 快照，
/// 保留最近 `maxBackups` 份。JSON 格式与 GUI/CLI 导入完全兼容，可直接恢复。
enum SnippetBackupArchiver {
    static let maxBackups = 20

    /// ~/Library/Application Support/TextFlash/Backups
    static var backupsDirectory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("TextFlash/Backups", isDirectory: true)
    }

    /// 将当前数据库中的全部片段备份为 JSON 快照并清理旧备份。
    /// 返回写入的快照 URL。
    @discardableResult
    static func backupCurrentSnippets() throws -> URL {
        guard let directory = backupsDirectory else {
            throw SnippetImportExportError.databaseWriteFailed
        }
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let groups = DatabaseManager.shared.fetchAllGroups()
        let data = try SnippetBackup.encode(groups: groups)

        let stamp = Self.timestamp()
        var url = directory.appendingPathComponent("textflash-snippets-\(stamp).json")
        var attempt = 0
        while fileManager.fileExists(atPath: url.path), attempt < 100 {
            attempt += 1
            url = directory.appendingPathComponent("textflash-snippets-\(stamp)-\(attempt).json")
        }
        try data.write(to: url, options: .atomic)
        prune(in: directory)
        return url
    }

    /// 删除最旧的备份，只保留最近 `maxBackups` 份
    private static func prune(in directory: URL) {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        let sorted = contents
            .filter { $0.pathExtension == "json" }
            .sorted { lhs, rhs in
                let lhsDate = try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                let rhsDate = try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                return (lhsDate ?? .distantPast) > (rhsDate ?? .distantPast)
            }

        if sorted.count > maxBackups {
            for url in sorted.dropFirst(maxBackups) {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
