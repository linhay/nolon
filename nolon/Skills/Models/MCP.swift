//
//  MCP.swift
//  nolon
//
//  Created by linhey on 1/24/26.
//

import Foundation
import STJSON

public struct MCP: Identifiable, Sendable {
    
    public var id: String { name }
    public let name: String
    public let json: AnyCodable
    
    public init(name: String, json: AnyCodable) {
        self.name = name
        self.json = json
    }

    public var dictionaryValue: [String: Any] {
        json.value as? [String: Any] ?? [:]
    }

    public var isEnabled: Bool {
        let dict = dictionaryValue
        if let enabled = dict["enabled"] as? Bool {
            return enabled
        }
        if let disabled = dict["disabled"] as? Bool {
            return !disabled
        }
        return true
    }

    public func withDictionary(_ dict: [String: Any]) -> MCP {
        MCP(name: name, json: AnyCodable(dict))
    }
}
