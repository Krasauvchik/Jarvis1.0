import SwiftUI

struct MainView: View {
    @StateObject private var store = PlannerStore()
    @StateObject private var wellness = WellnessStore()
    @StateObject private var aiManager = AIManager()
    
    var body: some View {
        TabView {
            PlannerView(store: store, aiManager: aiManager)
                .tabItem { Label("План", systemImage: "checklist") }
            
            CalendarView()
                .tabItem { Label("Календарь", systemImage: "calendar") }
            
            MailView()
                .tabItem { Label("Почта", systemImage: "envelope") }
            
            AnalyticsView(tasks: store.tasks, aiManager: aiManager)
                .tabItem { Label("Аналитика", systemImage: "chart.bar.xaxis") }
            
            WellnessView(store: store, wellness: wellness, aiManager: aiManager)
                .tabItem { Label("Здоровье", systemImage: "heart.text.square") }
        }
        .tint(JarvisTheme.accent)
    }
}
