//
//  InstrumentInstance.swift
//  loop_it
//
//  Created by Mustafa Efe Doganbey on 26.12.25.
//

import Foundation

struct InstrumentInstance: Identifiable, Equatable {
    let id: UUID
    let instrument: DrumInstrument

    init(id: UUID = UUID(), instrument: DrumInstrument) {
        self.id = id
        self.instrument = instrument
    }
}
