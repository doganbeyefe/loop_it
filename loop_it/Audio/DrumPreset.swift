//
//  DrumPreset.swift
//  loop_it
//
//  Created by Mustafa Efe Doganbey on 26.12.25.
//

import Foundation

protocol DrumPreset: Identifiable, Hashable {
    var title: String { get }
    var program: UInt8 { get }
    var midiNote: UInt8 { get }
}
