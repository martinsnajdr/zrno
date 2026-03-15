//
//  ZrnoApp.swift
//  Zrno
//
//  Created by Martin Šnajdr on 13.03.2026.
//

import SwiftUI
import SwiftData

@main
struct zrnoApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CameraProfile.self,
            Lens.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
