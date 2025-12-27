//
//  InstrumentInstance.swift
//  loop_it
//
//  Created by Mustafa Efe Doganbey on 26.12.25.
//

import Foundation

/// Uniquely identifies an instrument instance, including its base instrument kind.
struct InstrumentKey: Identifiable, Hashable {
    let id: UUID
    let instrument: DrumInstrument

    init(id: UUID = UUID(), instrument: DrumInstrument) {
        self.id = id
        self.instrument = instrument
    }
}

struct InstrumentInstance: Identifiable, Equatable {
    let key: InstrumentKey
    var id: InstrumentKey { key }
    var instrument: DrumInstrument { key.instrument }

    init(key: InstrumentKey) {
        self.key = key
    }

    init(id: UUID = UUID(), instrument: DrumInstrument) {
        self.key = InstrumentKey(id: id, instrument: instrument)
    }
}
