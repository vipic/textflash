import Foundation
import SQLite3
import Testing
@testable import TextFlash

@Suite struct DatabaseFailureTests {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func execute(_ path: String, _ sql: String) throws {
        var db: OpaquePointer?
        #expect(sqlite3_open(path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        var error: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &error)
        if result != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? "SQLite error"
            sqlite3_free(error)
            throw NSError(domain: "SQLite", code: Int(result), userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private func scalar(_ path: String, _ sql: String) throws -> String {
        var db: OpaquePointer?
        guard sqlite3_open(path, &db) == SQLITE_OK else { throw CocoaError(.fileReadUnknown) }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw CocoaError(.fileReadUnknown) }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw CocoaError(.fileReadUnknown) }
        return String(cString: sqlite3_column_text(statement, 0))
    }

    @Test func migrationAvoidsExistingGeneratedNameAndCommitsVersionTogether() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("migration.db").path
        try execute(path, """
            CREATE TABLE groups (id TEXT PRIMARY KEY, name TEXT NOT NULL, sort_order INTEGER NOT NULL DEFAULT 0);
            CREATE TABLE snippets (id TEXT PRIMARY KEY, group_id TEXT NOT NULL, abbreviation TEXT NOT NULL, expanded_text TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', sort_order INTEGER NOT NULL DEFAULT 0);
            INSERT INTO snippets (id, group_id, abbreviation, expanded_text) VALUES
              ('1', 'g', 'a', 'one'), ('2', 'g', 'a', 'two'),
              ('3', 'g', '__textflash_migration_duplicate_2_a', 'existing');
            PRAGMA user_version = 0;
        """)

        let database = DatabaseManager(testDatabasePath: path)
        #expect(database.initializationError == nil)
        #expect(try scalar(path, "SELECT count(DISTINCT abbreviation) FROM snippets;") == "3")
        #expect(try scalar(path, "PRAGMA user_version;") == "2")
        #expect(try scalar(path, "SELECT abbreviation FROM snippets WHERE id='3';") == "__textflash_migration_duplicate_2_a")
    }

    @Test func failedMigrationRollsBackVersionBlocksWritesAndCanRetry() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("failure.db").path
        try execute(path, """
            CREATE TABLE groups (id TEXT PRIMARY KEY, name TEXT NOT NULL, sort_order INTEGER NOT NULL DEFAULT 0);
            CREATE TABLE snippets (id TEXT PRIMARY KEY, group_id TEXT NOT NULL, abbreviation TEXT NOT NULL, expanded_text TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', sort_order INTEGER NOT NULL DEFAULT 0);
            INSERT INTO snippets (id, group_id, abbreviation, expanded_text) VALUES ('1', 'g', 'a', 'one'), ('2', 'g', 'a', 'two');
            CREATE TRIGGER stop_migration BEFORE UPDATE OF abbreviation ON snippets BEGIN SELECT RAISE(ABORT, 'injected migration failure'); END;
            PRAGMA user_version = 0;
        """)
        let failed = DatabaseManager(testDatabasePath: path)
        #expect(failed.initializationError != nil)
        #expect(try scalar(path, "PRAGMA user_version;") == "0")
        #expect(!failed.insertGroup(id: UUID(), name: "must-not-write", sortOrder: 0))
        #expect(try scalar(path, "SELECT count(*) FROM groups;") == "0")

        try execute(path, "DROP TRIGGER stop_migration;")
        let retried = DatabaseManager(testDatabasePath: path)
        #expect(retried.initializationError == nil)
        #expect(try scalar(path, "PRAGMA user_version;") == "2")
    }

    @Test func readFailureCreatesNoBackupAndDoesNotPrune() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("read.db").path
        let backups = directory.appendingPathComponent("backups")
        try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true)
        let database = DatabaseManager(testDatabasePath: path)
        try execute(path, "DROP TABLE groups;")
        for index in 0...SnippetBackupArchiver.maxBackups {
            try Data("old".utf8).write(to: backups.appendingPathComponent("old-\(index).json"))
        }

        #expect(throws: Error.self) {
            try SnippetBackupArchiver.backupCurrentSnippets(database: database, directory: backups)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: backups.path).count == SnippetBackupArchiver.maxBackups + 1)
    }

    @Test func validEmptyDatabaseExportsNormally() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = DatabaseManager(testDatabasePath: directory.appendingPathComponent("empty.db").path)
        let backup = try SnippetBackupArchiver.backupCurrentSnippets(database: database, directory: directory.appendingPathComponent("backups"))
        #expect(FileManager.default.fileExists(atPath: backup.path))
    }

    @Test func openingDirectoryAsDatabaseReportsFailure() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = DatabaseManager(testDatabasePath: directory.path)
        #expect(database.initializationError != nil)
        #expect(!database.insertGroup(id: UUID(), name: "must-not-write", sortOrder: 0))
    }
}
