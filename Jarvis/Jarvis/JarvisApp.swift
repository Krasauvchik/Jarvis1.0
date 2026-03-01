import SwiftUI

@main
struct JarvisApp: App {
    init() {
        NSUbiquitousKeyValueStore.default.synchronize()
    }
    
    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            StructuredMainView()
            #elseif os(watchOS)
            MainView()
            #else
            StructuredMainView()
            #endif
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        #endif
    }
}
