import Foundation
import STFilePath

#if canImport(Darwin)
import Darwin
#endif

extension STPathProtocol {
    /// Removes a path if it exists, including broken symbolic links.
    ///
    /// `STPathProtocol.delete()` uses `FileManager.fileExists` and will skip broken symlinks.
    /// This helper deletes broken symlinks via `unlink(2)`.
    func deleteIncludingBrokenSymlink() throws {
        if isExists {
            try delete()
            return
        }

        guard isSymbolicLink else { return }

        #if canImport(Darwin)
        if unlink(url.path) != 0 {
            throw NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(errno),
                userInfo: [NSFilePathErrorKey: url.path]
            )
        }
        #else
        // Fallback: on non-Darwin platforms we don't have a reliable unlink here.
        #endif
    }
}

