import Foundation
import Testing

@Suite struct ReleaseWorkflowContractTests {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func contents(of relativePath: String) throws -> String {
        try String(contentsOf: repositoryRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    @Test func releaseRequiresUnifiedValidationAndSafePublishing() throws {
        let release = try contents(of: "release.sh")
        #expect(release.contains("command_log_run mise_check mise run check"))
        #expect(release.contains("git push --atomic"))
        #expect(release.contains("gh release create"))
        #expect(!release.contains("--clobber"))
        #expect(!release.contains("RUN_TESTS=false"))
    }

    @Test func ciDoesNotBuildUnsignedFormalArtifacts() throws {
        let workflow = try contents(of: ".github/workflows/release-build-verification.yml")
        #expect(workflow.contains("mise run check"))
        #expect(!workflow.contains("release.sh"))
        #expect(!workflow.contains("upload-artifact"))
    }

    @Test func formalPublishRequiresExplicitVersion() throws {
        let publish = try contents(of: ".mise/tasks/publish")
        #expect(publish.contains("正式发布必须显式指定版本"))
        #expect(!publish.contains("next_version.sh"))
    }
}
