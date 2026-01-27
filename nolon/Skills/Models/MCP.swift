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
}
