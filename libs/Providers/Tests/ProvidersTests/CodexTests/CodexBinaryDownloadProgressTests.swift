import Foundation
import Testing
@testable import CodexProvider

@Suite("CodexBinaryManager Download Progress")
struct CodexBinaryDownloadProgressTests {
    @Test("Given normalized progress units, when mapping download progress, then do not expose fake byte sizes")
    func ignoresNormalizedUnitCountsForByteText() {
        let progress = CodexBinaryManager.makeDownloadProgress(
            completedUnitCount: 5,
            totalUnitCount: 100,
            receivedBytes: 0,
            expectedBytes: NSURLSessionTransferSizeUnknown
        )

        #expect(progress.fractionCompleted == 0.05)
        #expect(progress.completedBytes == nil)
        #expect(progress.totalBytes == nil)
    }

    @Test("Given task byte counts, when mapping download progress, then expose real byte sizes")
    func prefersTaskByteCounts() {
        let progress = CodexBinaryManager.makeDownloadProgress(
            completedUnitCount: 5,
            totalUnitCount: 100,
            receivedBytes: 5 * 1024 * 1024,
            expectedBytes: 100 * 1024 * 1024
        )

        #expect(progress.fractionCompleted == 0.05)
        #expect(progress.completedBytes == 5 * 1024 * 1024)
        #expect(progress.totalBytes == 100 * 1024 * 1024)
    }
}
