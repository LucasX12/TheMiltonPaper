//
//  Item.swift
//  The Milton Paper
//
//  Created by Lucas Xia on 17/05/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
