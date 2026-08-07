import Foundation
import Testing
@testable import TextFlash

// MARK: - 参数解析

@Test func cliParseExportSnippetsDefaultsToStdout() throws {
    let result = CLIController.parse(arguments: ["export", "snippets"])
    #expect(result == .success(.exportSnippets(output: nil)))
}

@Test func cliParseExportSnippetsWithShortOutputFlag() throws {
    let result = CLIController.parse(arguments: ["export", "snippets", "-o", "/tmp/x.json"])
    #expect(result == .success(.exportSnippets(output: "/tmp/x.json")))
}

@Test func cliParseExportSnippetsWithLongOutputFlag() throws {
    let result = CLIController.parse(arguments: ["export", "snippets", "--output", "/tmp/x.json"])
    #expect(result == .success(.exportSnippets(output: "/tmp/x.json")))
}

@Test func cliParseExportSnippetsWithEqualsOutputFlag() throws {
    let result = CLIController.parse(arguments: ["export", "snippets", "--output=/tmp/x.json"])
    #expect(result == .success(.exportSnippets(output: "/tmp/x.json")))
}

@Test func cliParseExportConfig() throws {
    let result = CLIController.parse(arguments: ["export", "config"])
    #expect(result == .success(.exportConfig(output: nil)))
}

@Test func cliParseImportSnippets() throws {
    let result = CLIController.parse(arguments: ["import", "snippets", "/tmp/backup.json"])
    #expect(result == .success(.importSnippets(path: "/tmp/backup.json")))
}

@Test func cliParseImportConfig() throws {
    let result = CLIController.parse(arguments: ["import", "config", "/tmp/config.json"])
    #expect(result == .success(.importConfig(path: "/tmp/config.json")))
}

@Test func cliParseHelpVariants() throws {
    #expect(CLIController.parse(arguments: []) == .success(.help))
    #expect(CLIController.parse(arguments: ["--help"]) == .success(.help))
    #expect(CLIController.parse(arguments: ["-h"]) == .success(.help))
    #expect(CLIController.parse(arguments: ["help"]) == .success(.help))
}

@Test func cliParseRejectsUnknownCommand() {
    let result = CLIController.parse(arguments: ["frobnicate"])
    guard case .failure(let error) = result else {
        Issue.record("应返回失败，实际：\(result)")
        return
    }
    #expect(error.localizedDescription.contains("未知命令"))
}

@Test func cliParseRejectsUnknownSubcommand() {
    let result = CLIController.parse(arguments: ["export", "database"])
    guard case .failure(let error) = result else {
        Issue.record("应返回失败，实际：\(result)")
        return
    }
    #expect(error.localizedDescription.contains("未知命令"))
}

@Test func cliParseRejectsMissingSubcommand() {
    let result = CLIController.parse(arguments: ["export"])
    guard case .failure(let error) = result else {
        Issue.record("应返回失败，实际：\(result)")
        return
    }
    #expect(error.localizedDescription.contains("缺少参数"))
}

@Test func cliParseRejectsMissingImportPath() {
    let result = CLIController.parse(arguments: ["import", "snippets"])
    guard case .failure(let error) = result else {
        Issue.record("应返回失败，实际：\(result)")
        return
    }
    #expect(error.localizedDescription.contains("缺少参数"))
}

@Test func cliParseRejectsUnexpectedArguments() {
    let result = CLIController.parse(arguments: ["export", "snippets", "extra"])
    guard case .failure(let error) = result else {
        Issue.record("应返回失败，实际：\(result)")
        return
    }
    #expect(error.localizedDescription.contains("多余的参数"))
}

// MARK: - 片段导出格式（与 GUI 一致）

@Test func cliSnippetExportUsesWrappedBackupFormat() throws {
    let group = SnippetGroup(name: "通用", snippets: [
        Snippet(abbreviation: "addr", expandedText: "123 Main St", description: "地址")
    ])
    let data = try SnippetBackup.encode(groups: [group])

    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    #expect(object?["groups"] is [[String: Any]])

    // 与 GUI 导入器兼容：导出内容可直接解码回原分组
    let decoded = try SnippetBackupValidator.decodeImportData(data)
    #expect(decoded == [group])
}

@Test func cliSnippetExportMatchesSortedKeysConvention() throws {
    let group = SnippetGroup(name: "A", snippets: [
        Snippet(abbreviation: "x", expandedText: "y", description: "z")
    ])
    let data = try SnippetBackup.encode(groups: [group])

    // 与 SnippetManager.exportJSONData 共用同一编码器：prettyPrinted + sortedKeys
    let reference = try {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(SnippetBackup(groups: [group]))
    }()
    #expect(data == reference)
}

// MARK: - 配置备份编解码

@Test func configBackupRoundTripsAllFields() throws {
    let config = TextFlashConfigBackup(
        language: "zhHans",
        deletionSettleDelayPerCharacter: 35,
        triggerMatchingMode: "boundary",
        launchAtLogin: true,
        unicodeInputBundleIDs: ["com.apple.Terminal", "com.microsoft.VSCode"],
        excludedBundleIDs: ["com.apple.loginwindow"]
    )
    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(TextFlashConfigBackup.self, from: data)
    #expect(decoded == config)
}

@Test func configBackupDecodesPartialJSON() throws {
    let json = """
    {
      "triggerMatchingMode": "boundary",
      "unicodeInputBundleIDs": ["com.apple.Terminal"]
    }
    """
    let decoded = try JSONDecoder().decode(TextFlashConfigBackup.self, from: Data(json.utf8))
    #expect(decoded.language == nil)
    #expect(decoded.deletionSettleDelayPerCharacter == nil)
    #expect(decoded.triggerMatchingMode == "boundary")
    #expect(decoded.launchAtLogin == nil)
    #expect(decoded.unicodeInputBundleIDs == ["com.apple.Terminal"])
    #expect(decoded.excludedBundleIDs == nil)
}

@Test func configBackupIgnoresUnknownKeys() throws {
    let json = """
    {
      "language": "en",
      "someFutureField": 42
    }
    """
    let decoded = try JSONDecoder().decode(TextFlashConfigBackup.self, from: Data(json.utf8))
    #expect(decoded.language == "en")
}

@Test func configBackupOfSnippetJSONHasNoRecognizedFields() throws {
    // 防止误把片段 JSON 当配置导入：片段备份应解码出全 nil
    let group = SnippetGroup(name: "A", snippets: [
        Snippet(abbreviation: "x", expandedText: "y")
    ])
    let data = try SnippetBackup.encode(groups: [group])
    let decoded = try JSONDecoder().decode(TextFlashConfigBackup.self, from: data)
    #expect(decoded.language == nil)
    #expect(decoded.deletionSettleDelayPerCharacter == nil)
    #expect(decoded.triggerMatchingMode == nil)
    #expect(decoded.launchAtLogin == nil)
    #expect(decoded.unicodeInputBundleIDs == nil)
    #expect(decoded.excludedBundleIDs == nil)
}
