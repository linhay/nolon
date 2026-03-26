import Foundation

enum GenericSelectionStateResolver {
    static func resolveSingleSelection<Value: Hashable>(
        current: Value?,
        tapped: Value,
        allowsEmptySelection: Bool
    ) -> Value? {
        if current == tapped {
            return allowsEmptySelection ? nil : current
        }
        return tapped
    }

    static func resolveMultiSelection<Value: Hashable>(
        current: Set<Value>,
        tapped: Value
    ) -> Set<Value> {
        var next = current
        if next.contains(tapped) {
            next.remove(tapped)
        } else {
            next.insert(tapped)
        }
        return next
    }

    static func resolveBatchMultiSelection<Value: Hashable>(
        current: Set<Value>,
        toggledValues: Set<Value>
    ) -> Set<Value> {
        guard !toggledValues.isEmpty else { return current }
        var next = current
        if toggledValues.isSubset(of: next) {
            next.subtract(toggledValues)
        } else {
            next.formUnion(toggledValues)
        }
        return next
    }

    static func resolveHoverSelection<Value: Hashable>(
        current: Value?,
        hovered: Value,
        isHovering: Bool
    ) -> Value? {
        guard !isHovering else { return hovered }
        return current == hovered ? nil : current
    }

    static func resolveBooleanToggle(current: Bool) -> Bool {
        !current
    }

    static func resolveSortSelection<Key: Equatable>(
        currentKey: Key,
        currentAscending: Bool,
        tappedKey: Key,
        defaultAscendingForTappedKey: Bool
    ) -> (key: Key, ascending: Bool) {
        if currentKey == tappedKey {
            return (currentKey, resolveBooleanToggle(current: currentAscending))
        }
        return (tappedKey, defaultAscendingForTappedKey)
    }
}
