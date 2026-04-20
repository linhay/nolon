import Foundation

enum CodexRolloutLineReader {
    private static let newline = Data([0x0A])

    @discardableResult
    static func readLines(
        at url: URL,
        fromOffset: Int64 = 0,
        chunkSize: Int = 64 * 1024,
        _ body: (Data) throws -> Void
    ) throws -> Int64 {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        if fromOffset > 0 {
            try handle.seek(toOffset: UInt64(fromOffset))
        }

        let effectiveChunkSize = max(4 * 1024, chunkSize)
        var pending = Data()
        var readBytes: Int64 = 0

        while true {
            let chunk = handle.readData(ofLength: effectiveChunkSize)
            if chunk.isEmpty {
                break
            }
            readBytes += Int64(chunk.count)
            pending.append(chunk)

            while let newlineRange = pending.firstRange(of: newline) {
                let lineData = pending.subdata(in: 0..<newlineRange.lowerBound)
                pending.removeSubrange(0..<newlineRange.upperBound)
                if lineData.isEmpty {
                    continue
                }
                try body(lineData)
            }
        }

        if !pending.isEmpty {
            try body(pending)
        }

        return fromOffset + readBytes
    }
}
