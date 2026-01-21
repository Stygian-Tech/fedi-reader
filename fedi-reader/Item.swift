//
//  Item.swift
//  fedi-reader
//
//  Created by Sam Clemente on 1/20/26.
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
