import Foundation

// MARK: - 用户配置备份（JSON）

/// CLI 导入导出的用户配置。字段全部可选：导出时全部填充；导入时只应用出现的字段，
/// 便于跨版本向前兼容。辅助功能授权由 macOS 按机器管理（TCC），无法迁移，不包含在内。
struct TextFlashConfigBackup: Codable, Equatable {
    var language: String?
    var deletionSettleDelayPerCharacter: Double?
    var triggerMatchingMode: String?
    var launchAtLogin: Bool?
    var unicodeInputBundleIDs: [String]?
    var excludedBundleIDs: [String]?
}

// MARK: - CLI 错误

enum CLIError: LocalizedError, Equatable {
    case unknownCommand(String)
    case missingArgument(String)
    case unexpectedArguments([String])
    case fileNotFound(String)
    case readFailed(String)
    case writeFailed(String, String)
    case invalidImport(String)
    case databaseWriteFailed

    var errorDescription: String? {
        switch self {
        case .unknownCommand(let command):
            return "未知命令：\(command)"
        case .missingArgument(let name):
            return "缺少参数：\(name)"
        case .unexpectedArguments(let args):
            return "多余的参数：\(args.joined(separator: " "))"
        case .fileNotFound(let path):
            return "文件不存在：\(path)"
        case .readFailed(let path):
            return "读取失败：\(path)"
        case .writeFailed(let path, let detail):
            return "写入失败：\(path)（\(detail)）"
        case .invalidImport(let message):
            return "导入失败：\(message)"
        case .databaseWriteFailed:
            return "数据库写入失败"
        }
    }
}

// MARK: - CLI 命令

enum CLICommand: Equatable {
    case exportSnippets(output: String?)
    case importSnippets(path: String)
    case exportConfig(output: String?)
    case importConfig(path: String)
    case help
}

// MARK: - CLIController

/// 命令行导入导出入口。应用以非空参数启动时（如 `TextFlash export snippets -o x.json`），
/// 在 TextFlashApp.init 中调用 `handleIfNeeded`，处理完毕后直接退出，不启动 GUI。
enum CLIController {

    static let helpText = """
    TextFlash 命令行工具 — 片段与配置导入导出

    用法：
      TextFlash export snippets [--output <路径>]  导出全部片段为 JSON（与 GUI 导入导出格式一致）
      TextFlash import snippets <文件>              导入片段 JSON，校验通过后替换全部片段（覆盖前自动备份）
      TextFlash export config [--output <路径>]    导出用户配置为 JSON
      TextFlash import config <文件>                导入用户配置 JSON
      TextFlash --help                              显示本帮助

    导出的配置包含：语言、替换时序（删除等待毫秒数）、触发匹配模式、开机启动、
    Unicode 输入应用 Bundle ID、排除应用 Bundle ID。
    辅助功能授权由 macOS 按机器管理，无法迁移，不包含在配置中。

    示例：
      TextFlash export snippets --output ~/Desktop/snippets.json
      TextFlash import snippets ~/Desktop/snippets.json
      TextFlash export config -o ~/Desktop/config.json
      TextFlash import config ~/Desktop/config.json

    导出默认写到标准输出（stdout）；导入文件大小上限 2 MB。
    """

    /// 入口：应用启动时若有命令行参数，处理并退出进程（不返回值）。
    /// 无参数时返回 false，走正常 GUI 启动。
    static func handleIfNeeded(arguments: [String]) -> Bool {
        guard !arguments.isEmpty else { return false }
        let code = run(arguments: arguments)
        fflush(stdout)
        exit(code)
    }

    static func run(arguments: [String]) -> Int32 {
        switch parse(arguments: arguments) {
        case .failure(let error):
            FileHandle.standardError.write(Data(("错误：\(error.localizedDescription)\n\n").utf8))
            FileHandle.standardError.write(Data((helpText + "\n").utf8))
            return 1
        case .success(.help):
            print(helpText)
            return 0
        case .success(let command):
            return execute(command)
        }
    }

    // MARK: - 参数解析（纯函数，可单测）

    static func parse(arguments: [String]) -> Result<CLICommand, CLIError> {
        guard let first = arguments.first else { return .success(.help) }
        let rest = Array(arguments.dropFirst())

        switch first {
        case "export":
            guard let kind = rest.first else { return .failure(.missingArgument("export 子命令（snippets / config）")) }
            let options = Array(rest.dropFirst())
            switch kind {
            case "snippets":
                return parseOutputOption(options, make: CLICommand.exportSnippets)
            case "config":
                return parseOutputOption(options, make: CLICommand.exportConfig)
            default:
                return .failure(.unknownCommand("export \(kind)"))
            }
        case "import":
            guard let kind = rest.first else { return .failure(.missingArgument("import 子命令（snippets / config）")) }
            let options = Array(rest.dropFirst())
            switch kind {
            case "snippets":
                return parsePathArgument(options, make: CLICommand.importSnippets)
            case "config":
                return parsePathArgument(options, make: CLICommand.importConfig)
            default:
                return .failure(.unknownCommand("import \(kind)"))
            }
        case "-h", "--help", "help":
            return .success(.help)
        default:
            return .failure(.unknownCommand(first))
        }
    }

    private static func parseOutputOption(_ arguments: [String], make: (String?) -> CLICommand) -> Result<CLICommand, CLIError> {
        if arguments.isEmpty {
            return .success(make(nil))
        }
        if arguments.count == 2, arguments[0] == "-o" || arguments[0] == "--output" {
            return .success(make(arguments[1]))
        }
        if arguments.count == 1, arguments[0].hasPrefix("--output=") {
            let value = String(arguments[0].dropFirst("--output=".count))
            return value.isEmpty ? .failure(.missingArgument("--output 的值")) : .success(make(value))
        }
        return .failure(.unexpectedArguments(arguments))
    }

    private static func parsePathArgument(_ arguments: [String], make: (String) -> CLICommand) -> Result<CLICommand, CLIError> {
        if arguments.isEmpty {
            return .failure(.missingArgument("导入文件路径"))
        }
        if arguments.count > 1 {
            return .failure(.unexpectedArguments(Array(arguments.dropFirst())))
        }
        return .success(make(arguments[0]))
    }

    // MARK: - 执行

    static func execute(_ command: CLICommand) -> Int32 {
        do {
            switch command {
            case .exportSnippets(let output):
                try emit(try exportSnippetsData(), to: output)
            case .importSnippets(let path):
                try importSnippets(from: path)
            case .exportConfig(let output):
                try emit(try exportConfigData(), to: output)
            case .importConfig(let path):
                try importConfig(from: path)
            case .help:
                print(helpText)
            }
            return 0
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            FileHandle.standardError.write(Data(("错误：\(message)\n").utf8))
            return 1
        }
    }

    private static func emit(_ data: Data, to output: String?) throws {
        if let output {
            let url = URL(fileURLWithPath: output)
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                throw CLIError.writeFailed(output, error.localizedDescription)
            }
        } else {
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        }
    }

    // MARK: - 片段导出 / 导入

    static func exportSnippetsData() throws -> Data {
        try SnippetBackup.encode(groups: DatabaseManager.shared.fetchAllGroups())
    }

    static func importSnippets(from path: String) throws {
        let data = try readImportFile(path: path)
        let groups: [SnippetGroup]
        do {
            groups = try SnippetBackupValidator.decodeImportData(data)
        } catch {
            throw CLIError.invalidImport(error.localizedDescription)
        }

        // 覆盖前自动备份，导入后可从备份恢复
        _ = try SnippetBackupArchiver.backupCurrentSnippets()

        guard DatabaseManager.shared.replaceAllGroups(groups) else {
            throw CLIError.databaseWriteFailed
        }
        NotificationCenter.default.post(name: .textFlashSnippetsDidChange, object: nil)

        let snippetCount = groups.reduce(0) { $0 + $1.snippets.count }
        print("已导入 \(groups.count) 个分组、\(snippetCount) 个片段")
    }

    // MARK: - 配置导出 / 导入

    static func exportConfigData() throws -> Data {
        let defaults = UserDefaults.standard
        let config = TextFlashConfigBackup(
            language: defaults.string(forKey: AppSettingsKeys.language) ?? AppLanguage.system.rawValue,
            deletionSettleDelayPerCharacter: defaults.object(forKey: AppSettingsKeys.deletionDelay) as? Double ?? 20,
            triggerMatchingMode: defaults.string(forKey: AppSettingsKeys.triggerMatchingMode) ?? TriggerMatchingMode.anywhere.rawValue,
            launchAtLogin: LoginItemController.isEnabled,
            unicodeInputBundleIDs: defaults.stringArray(forKey: AppSettingsKeys.unicodeInputBundleIDs) ?? [],
            excludedBundleIDs: defaults.stringArray(forKey: AppSettingsKeys.excludedBundleIDs) ?? []
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(config)
    }

    static func importConfig(from path: String) throws {
        let data = try readImportFile(path: path)
        let config: TextFlashConfigBackup
        do {
            config = try JSONDecoder().decode(TextFlashConfigBackup.self, from: data)
        } catch {
            throw CLIError.invalidImport("无法识别为配置文件：\(error.localizedDescription)")
        }

        // 全部字段都缺失时视为无效文件（防止误把片段 JSON 当配置导入）
        let fieldsPresent = config.language != nil
            || config.deletionSettleDelayPerCharacter != nil
            || config.triggerMatchingMode != nil
            || config.launchAtLogin != nil
            || config.unicodeInputBundleIDs != nil
            || config.excludedBundleIDs != nil
        guard fieldsPresent else {
            throw CLIError.invalidImport("未识别到任何配置字段")
        }

        var warnings: [String] = []
        let defaults = UserDefaults.standard

        if let language = config.language {
            if AppLanguage(rawValue: language) != nil {
                defaults.set(language, forKey: AppSettingsKeys.language)
                NotificationCenter.default.post(name: .textFlashLanguageDidChange, object: nil)
            } else {
                warnings.append("language 无效，已跳过：\(language)")
            }
        }
        if let delay = config.deletionSettleDelayPerCharacter {
            defaults.set(delay, forKey: AppSettingsKeys.deletionDelay)
        }
        if let mode = config.triggerMatchingMode {
            if TriggerMatchingMode(rawValue: mode) != nil {
                defaults.set(mode, forKey: AppSettingsKeys.triggerMatchingMode)
                NotificationCenter.default.post(name: .textFlashTriggerMatchingModeDidChange, object: nil)
            } else {
                warnings.append("triggerMatchingMode 无效，已跳过：\(mode)")
            }
        }
        if let launchAtLogin = config.launchAtLogin {
            do {
                try LoginItemController.setEnabled(launchAtLogin)
            } catch {
                warnings.append("设置开机启动失败：\(error.localizedDescription)")
            }
        }
        if let ids = config.unicodeInputBundleIDs {
            defaults.set(ids.sorted(), forKey: AppSettingsKeys.unicodeInputBundleIDs)
            NotificationCenter.default.post(name: .textFlashUnicodeAppsDidChange, object: nil)
        }
        if let ids = config.excludedBundleIDs {
            defaults.set(ids.sorted(), forKey: AppSettingsKeys.excludedBundleIDs)
            NotificationCenter.default.post(name: .textFlashExclusionsDidChange, object: nil)
        }

        for warning in warnings {
            FileHandle.standardError.write(Data(("警告：\(warning)\n").utf8))
        }
        print("已导入用户配置")
    }

    // MARK: - 共用

    private static func readImportFile(path: String) throws -> Data {
        guard FileManager.default.fileExists(atPath: path) else {
            throw CLIError.fileNotFound(path)
        }
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else {
            throw CLIError.readFailed(path)
        }
        guard data.count <= 2 * 1024 * 1024 else {
            throw CLIError.invalidImport("文件过大（超过 2 MB）")
        }
        return data
    }
}
