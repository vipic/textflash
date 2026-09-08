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

    @Test func ciDoesNotBuildUnsignedFormalArtifacts() throws {
        let workflow = try contents(of: ".github/workflows/release-build-verification.yml")
        #expect(workflow.contains("mise run check"))
        #expect(!workflow.contains("release.sh"))
        #expect(!workflow.contains("upload-artifact"))
    }

}
