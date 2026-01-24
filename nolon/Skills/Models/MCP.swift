//
//  MCP.swift
//  nolon
//
//  Created by linhey on 1/24/26.
//

import Foundation
import STJSON

struct MCP: Identifiable {
    
    var id: String { name }
    let name: String
    let json: AnyCodable
    
}
