//
//  MCP.swift
//  nolon
//
//  Created by linhey on 1/24/26.
//

import Foundation
import STJSON

public struct MCP: Identifiable {
    
    public var id: String { name }
    let name: String
    let json: AnyCodable
    public let disabled: Bool?
    
    init(name: String, json: AnyCodable, disabled: Bool? = nil) {
        self.name = name
        self.json = json
        self.disabled = disabled
    }
    
    var workflowContent: String {
        """
        ---
        description: \(name)
        ---
        
        Use the `\(name)` mcp tool.
        """
    }
}
