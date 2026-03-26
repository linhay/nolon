import Foundation

struct IDBox<ID: Hashable>: Hashable, Identifiable, CustomStringConvertible {
    let rawValue: ID

    init(_ rawValue: ID) {
        self.rawValue = rawValue
    }

    var id: ID {
        rawValue
    }

    var description: String {
        String(describing: rawValue)
    }
}

extension Identifiable where ID: Hashable {
    var boxedID: IDBox<ID> {
        IDBox(id)
    }
}
