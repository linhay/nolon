import Foundation

public enum CostUsageJsonl {
    public struct Line: Sendable {
        public let bytes: Data
        public let wasTruncated: Bool
    }

    @discardableResult
    public static func scan(
        fileURL: URL,
        offset: Int64 = 0,
        maxLineBytes: Int,
        prefixBytes: Int,
        onLine: (Line) -> Void) throws
        -> Int64
    {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        let startOffset = max(0, offset)
        if startOffset > 0 {
            try handle.seek(toOffset: UInt64(startOffset))
        }

        var buffer = Data()
        buffer.reserveCapacity(64 * 1024)

        var current = Data()
        current.reserveCapacity(4 * 1024)
        var lineBytes = 0
        var truncated = false
        var bytesRead: Int64 = 0

        func appendLinePart(_ linePart: Data.SubSequence) {
            lineBytes += linePart.count
            guard !truncated else { return }
            if lineBytes > maxLineBytes || lineBytes > prefixBytes {
                truncated = true
                current.removeAll(keepingCapacity: true)
            } else {
                current.append(contentsOf: linePart)
            }
        }

        func flushLine() {
            guard lineBytes > 0 else { return }
            let line = Line(bytes: current, wasTruncated: truncated)
            onLine(line)
            current.removeAll(keepingCapacity: true)
            lineBytes = 0
            truncated = false
        }

        while true {
            let chunk = try handle.read(upToCount: 256 * 1024) ?? Data()
            if chunk.isEmpty {
                if !buffer.isEmpty {
                    appendLinePart(buffer[buffer.startIndex..<buffer.endIndex])
                    buffer.removeAll(keepingCapacity: true)
                }
                flushLine()
                break
            }

            bytesRead += Int64(chunk.count)
            buffer.append(chunk)

            while true {
                guard let nl = buffer.firstIndex(of: 0x0A) else { break }
                let linePart = buffer[..<nl]
                buffer.removeSubrange(...nl)

                appendLinePart(linePart)
                flushLine()
            }
        }

        return startOffset + bytesRead
    }
}
