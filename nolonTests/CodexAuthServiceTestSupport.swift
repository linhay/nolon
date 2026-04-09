import Foundation
@testable import nolon

enum ActivationTestError: Error {
    case failed
}

struct UsageViewModelTestError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

actor AsyncFlagBox {
    private var flag = false

    func setTrue() {
        flag = true
    }

    func value() -> Bool {
        flag
    }
}

actor LockedBox<T: Sendable> {
    private var stored: T

    init(_ value: T) {
        stored = value
    }

    func set(_ value: T) {
        stored = value
    }

    func value() -> T {
        stored
    }
}

actor AsyncIntBox {
    private var stored: Int

    init(_ value: Int) {
        stored = value
    }

    func increment() {
        stored += 1
    }

    func value() -> Int {
        stored
    }
}

struct EmptyLocalizedError: LocalizedError {
    var errorDescription: String? { "   " }
}

extension ProviderUsageEngine {
    static func makeRandomCodexValidationInput() -> String {
        "nolon-connectivity-\(UUID().uuidString.lowercased())"
    }
}
