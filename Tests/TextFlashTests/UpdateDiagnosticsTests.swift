import Foundation
import Testing
@testable import TextFlash

@Test func updateErrorReportReadsAtMostConfiguredBytes() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("textflash-update-diagnostics-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let report = directory.appendingPathComponent("update_error.txt")
    try Data(repeating: 0x78, count: UpdateChecker.maxUpdateErrorBytes + 512)
        .write(to: report)

    let message = UpdateChecker.readUpdateErrorReport(at: report)

    #expect(message?.utf8.count == UpdateChecker.maxUpdateErrorBytes)
}

@Test func updateErrorReportIgnoresEmptyContent() throws {
    let report = FileManager.default.temporaryDirectory
        .appendingPathComponent("textflash-update-error-\(UUID().uuidString).txt")
    try Data("  \n".utf8).write(to: report)
    defer { try? FileManager.default.removeItem(at: report) }

    #expect(UpdateChecker.readUpdateErrorReport(at: report) == nil)
}
