//
//  Double+Formatting.swift
//  loop_it
//
//  Created by Mustafa Efe Doganbey on 26.12.25.
//

import Foundation

extension Double {
    /// Formats numbers like 1.0 as 1 for compact UI labels.
    var cleanSpeedText: String {
        if self == floor(self) { return String(Int(self)) }
        return String(self)
    }
}
