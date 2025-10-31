
import SwiftUI

@main
struct PersonalAssistantApp: App {
    @StateObject private var dataStore = DataStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .onAppear {
                    // Migrate existing data from UserDefaults on first launch
                    dataStore.migrateFromUserDefaults()
                }
        }
    }
}

