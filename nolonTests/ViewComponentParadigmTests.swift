import XCTest

final class ViewComponentParadigmTests: XCTestCase {
    func testBDD_GivenMainProjectViews_WhenCheckingBestParadigm_ThenEachViewHasObservableComponentViewModel() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("nolon", isDirectory: true)

        let swiftFiles = try collectSwiftFiles(in: sourceRoot)

        let viewNameRegex = try NSRegularExpression(
            pattern: #"(?m)^(?!\s*private\b)\s*(?:public\s+)?struct\s+(\w+)\b[^\n]*:\s*View\b"#
        )
        let observableViewModelRegex = try NSRegularExpression(
            pattern: #"@Observable[\s\S]*?\bclass\s+(\w+(?:ViewModel|Model))\b"#
        )
        let bindableExtensionRegex = try NSRegularExpression(
            pattern: #"extension\s+(\w+)\s*:\s*ViewComponentBindable\b"#
        )

        var allViewNames: [String] = []
        var observableViewModelNames: Set<String> = []
        var bindableViewNames: Set<String> = []

        for file in swiftFiles {
            let content = try String(contentsOf: file)
            let nsContent = content as NSString

            for match in viewNameRegex.matches(
                in: content,
                range: NSRange(location: 0, length: nsContent.length)
            ) {
                allViewNames.append(nsContent.substring(with: match.range(at: 1)))
            }

            for match in observableViewModelRegex.matches(
                in: content,
                range: NSRange(location: 0, length: nsContent.length)
            ) {
                observableViewModelNames.insert(nsContent.substring(with: match.range(at: 1)))
            }

            for match in bindableExtensionRegex.matches(
                in: content,
                range: NSRange(location: 0, length: nsContent.length)
            ) {
                bindableViewNames.insert(nsContent.substring(with: match.range(at: 1)))
            }
        }

        let missing = allViewNames.filter { viewName in
            !observableViewModelNames.contains(expectedViewModelName(for: viewName))
        }
        let missingBindable = allViewNames.filter { viewName in
            !bindableViewNames.contains(viewName)
        }

        XCTAssertTrue(
            missing.isEmpty,
            """
            Missing @Observable component ViewModel for views:
            \(missing.joined(separator: "\n"))
            """
        )
        XCTAssertTrue(
            missingBindable.isEmpty,
            """
            Missing ViewComponentBindable extension for views:
            \(missingBindable.joined(separator: "\n"))
            """
        )
    }

    private func expectedViewModelName(for viewName: String) -> String {
        if viewName.hasSuffix("View") {
            return "\(viewName)Model"
        }
        return "\(viewName)ViewModel"
    }

    private func collectSwiftFiles(in root: URL) throws -> [URL] {
        let fm = FileManager.default
        let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var files: [URL] = []
        while let item = enumerator?.nextObject() as? URL {
            guard item.pathExtension == "swift" else { continue }
            files.append(item)
        }

        return files
    }
}
