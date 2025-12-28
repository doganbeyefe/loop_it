//
//  loop_itApp.swift
//  loop_it
//
//  Created by Mustafa Efe Doganbey on 26.12.25.
//

import SwiftUI

@main
struct loop_itApp: App {
    @StateObject private var audio = SoundFontDrumEngine()

    var body: some Scene {
        WindowGroup {
            ContentView(audio: audio)
        }
    }
}
