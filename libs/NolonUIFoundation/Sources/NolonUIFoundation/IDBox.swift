import Foundation

public struct IDBox<ID: Hashable>: Hashable, Identifiable, CustomStringConvertible {
    public let rawValue: ID

    public init(_ rawValue: ID) {
        self.rawValue = rawValue
    }

    public var id: ID {
        rawValue
    }

    public var description: String {
        String(describing: rawValue)
    }
}

public extension Identifiable where ID: Hashable {
    var boxedID: IDBox<ID> {
        IDBox(id)
    }
}
