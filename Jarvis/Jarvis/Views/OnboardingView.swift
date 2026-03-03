import SwiftUI
import Combine

// MARK: - Onboarding Manager

@MainActor
final class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()
    
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "jarvis_onboarding_completed") }
    }
    
    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "jarvis_onboarding_completed")
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    @StateObject private var store = PlannerStore.shared
    @State private var currentPage = 0
    @State private var wakeUpTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var bedTime = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var acceptedTerms = false
    
    private let totalPages = 6
    
    var body: some View {
        ZStack {
            // Background
            backgroundForPage(currentPage)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with progress + navigation
                topBar
                
                // Page content
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    privacyPage.tag(1)
                    wakeUpPage.tag(2)
                    bedTimePage.tag(3)
                    planningPage.tag(4)
                    readyPage.tag(5)
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
                .animation(.easeInOut(duration: 0.4), value: currentPage)
            }
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack(spacing: 12) {
            if currentPage > 0 {
                Button(action: { withAnimation { currentPage -= 1 } }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(accentForPage(currentPage))
                        .frame(width: geo.size.width * CGFloat(currentPage + 1) / CGFloat(totalPages), height: 6)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
            }
            .frame(height: 6)
            
            if currentPage > 0 && currentPage < totalPages - 1 {
                Button(action: { withAnimation { currentPage += 1 } }) {
                    Text("Skip")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Page 1: Welcome
    
    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 8) {
                Text("Welcome to")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                Text("Jarvis")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(JarvisTheme.accent)
            }
            
            Spacer().frame(height: 20)
            
            // Feature list
            VStack(spacing: 20) {
                featureItem(
                    icon: "scope",
                    iconBg: JarvisTheme.accent.opacity(0.9),
                    title: "stay focused and\ndistraction-free"
                )
                
                featureItem(
                    icon: "cloud.fill",
                    iconBg: JarvisTheme.accentBlue.opacity(0.9),
                    title: "not get overwhelmed\non busy days"
                )
                
                featureItem(
                    icon: "bolt.fill",
                    iconBg: JarvisTheme.accentYellow.opacity(0.9),
                    title: "achieve your goals\nin the long haul"
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            onboardingButton(title: "Continue", accent: JarvisTheme.accent) {
                withAnimation { currentPage = 1 }
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Page 2: Privacy & Data
    
    private var privacyPage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Your Privacy & Data")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            // Lock illustration
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [JarvisTheme.accentBlue.opacity(0.3), JarvisTheme.accentPurple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [JarvisTheme.accentBlue, JarvisTheme.accentPurple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text("Your tasks and settings are stored locally on your device. They are synced via iCloud for the sole purpose of keeping your data in sync across all your devices.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
                
                Text("To continue, you'll need to accept our **Terms of Service** and **Data Processing Agreement**.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
                
                Text("Further information about the processing of your personal data can be found in our **Privacy Policy**.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            onboardingButton(title: "Accept Terms", accent: JarvisTheme.accent) {
                acceptedTerms = true
                withAnimation { currentPage = 2 }
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Page 3: Wake Up Time
    
    private var wakeUpPage: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Illustration area with gradient sunrise background 
            ZStack {
                // Sun
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.9, blue: 0.5),
                                Color(red: 1.0, green: 0.7, blue: 0.3).opacity(0.7),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 50))
                    .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.3))
            }
            .padding(.bottom, 24)
            
            VStack(spacing: 8) {
                Text("When did you")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("wake up?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(JarvisTheme.accent)
            }
            
            Spacer().frame(height: 32)
            
            // Time picker row
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(JarvisTheme.accent)
                        .frame(width: 44, height: 44)
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
                DatePicker("", selection: $wakeUpTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .scaleEffect(1.1)
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
            )
            .padding(.horizontal, 40)
            
            Spacer()
            
            onboardingButton(title: "Continue", accent: JarvisTheme.accent) {
                // Save wake up time
                let cal = Calendar.current
                let hour = cal.component(.hour, from: wakeUpTime)
                let minute = cal.component(.minute, from: wakeUpTime)
                UserDefaults.standard.set(hour, forKey: "jarvis_rise_hour")
                UserDefaults.standard.set(minute, forKey: "jarvis_rise_minute")
                withAnimation { currentPage = 3 }
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Page 4: Bed Time
    
    private var bedTimePage: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Moon illustration
            ZStack {
                // Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                JarvisTheme.accentBlue.opacity(0.4),
                                JarvisTheme.accentBlue.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 140, height: 140)
                
                Image(systemName: "moon.fill")
                    .font(.system(size: 56))
                    .foregroundColor(JarvisTheme.accentBlue)
            }
            .padding(.bottom, 24)
            
            // Stars scattered
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.3...0.8)))
                        .frame(width: CGFloat.random(in: 2...5), height: CGFloat.random(in: 2...5))
                        .offset(
                            x: CGFloat.random(in: -120...120),
                            y: CGFloat.random(in: -40...40)
                        )
                }
            }
            .frame(height: 1)
            
            VStack(spacing: 8) {
                Text("When will you")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("go to bed?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(JarvisTheme.accentBlue)
            }
            
            Spacer().frame(height: 32)
            
            // Time picker row
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(JarvisTheme.accentBlue)
                        .frame(width: 44, height: 44)
                    Image(systemName: "moon.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
                DatePicker("", selection: $bedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .scaleEffect(1.1)
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
            )
            .padding(.horizontal, 40)
            
            Spacer()
            
            onboardingButton(title: "Continue", accent: JarvisTheme.accentBlue) {
                let cal = Calendar.current
                let hour = cal.component(.hour, from: bedTime)
                let minute = cal.component(.minute, from: bedTime)
                UserDefaults.standard.set(hour, forKey: "jarvis_winddown_hour")
                UserDefaults.standard.set(minute, forKey: "jarvis_winddown_minute")
                withAnimation { currentPage = 4 }
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Page 5: Let's Start Planning
    
    private var planningPage: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 4) {
                Text("Let's start planning")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("today...")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(JarvisTheme.accent)
            }
            
            Text("This will only take a few steps.")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 8)
            
            Spacer().frame(height: 40)
            
            // Colorful hanging shapes illustration
            HStack(spacing: 10) {
                ForEach(0..<8, id: \.self) { i in
                    hangingShape(index: i)
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            onboardingButton(title: "Start Planning", accent: JarvisTheme.accent) {
                withAnimation { currentPage = 5 }
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Page 6: Ready (What's up next?)
    
    private var readyPage: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)
            
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Text("What's up")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("next?")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(JarvisTheme.accent)
                }
                
                Text("Awesome! Go ahead and plan your first task.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer().frame(height: 32)
            
            // Onboarding timeline preview
            VStack(spacing: 0) {
                // Rise and Shine
                onboardingTimelineItem(
                    time: formattedTime(wakeUpTime),
                    title: "Rise and Shine",
                    icon: "alarm.fill",
                    color: JarvisTheme.accent,
                    isCompleted: true,
                    isFirst: true
                )
                
                // Create Your First Task
                onboardingTimelineItem(
                    time: nil,
                    title: "Create Your First Task",
                    icon: "plus",
                    color: JarvisTheme.accent,
                    isCompleted: false,
                    isFirst: false
                )
                
                // Wind Down
                onboardingTimelineItem(
                    time: formattedTime(bedTime),
                    title: "Wind Down",
                    icon: "moon.fill",
                    color: JarvisTheme.accentBlue,
                    isCompleted: false,
                    isFirst: false
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            onboardingButton(title: "Finish Setup", accent: JarvisTheme.accent) {
                // Create wake/sleep tasks
                createDefaultTasks()
                onboardingManager.completeOnboarding()
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Helpers
    
    private func featureItem(icon: String, iconBg: Color, title: String) -> some View {
        HStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(iconBg)
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
    
    private func onboardingButton(title: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(accent)
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
    }
    
    private func onboardingTimelineItem(time: String?, title: String, icon: String, color: Color, isCompleted: Bool, isFirst: Bool) -> some View {
        HStack(spacing: 16) {
            // Timeline line + circle
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : color.opacity(0.3))
                    .frame(width: 2)
                    .frame(height: 20)
                
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                
                Rectangle()
                    .fill(color.opacity(0.3))
                    .frame(width: 2)
                    .frame(height: 20)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                if let time = time {
                    Text(time)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isCompleted ? .white.opacity(0.6) : .white)
                    .strikethrough(isCompleted, color: .white.opacity(0.4))
            }
            
            Spacer()
            
            // Checkbox
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 24))
                .foregroundColor(isCompleted ? color : color.opacity(0.5))
        }
        .padding(.vertical, 8)
    }
    
    private func hangingShape(index: Int) -> some View {
        let colors: [Color] = [
            JarvisTheme.accentBlue.opacity(0.7),
            JarvisTheme.accent.opacity(0.6),
            JarvisTheme.accentGreen.opacity(0.6),
            JarvisTheme.accentPink.opacity(0.6),
            JarvisTheme.accentBlue.opacity(0.5),
            JarvisTheme.accentOrange.opacity(0.6),
            JarvisTheme.accentGreen.opacity(0.5),
            JarvisTheme.accentPurple.opacity(0.6),
        ]
        let heights: [CGFloat] = [80, 50, 70, 60, 90, 55, 75, 65]
        let topPaddings: [CGFloat] = [10, 30, 15, 25, 5, 35, 20, 28]
        
        return VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 1, height: topPaddings[index % topPaddings.count])
            
            // Shape
            RoundedRectangle(cornerRadius: 16)
                .fill(colors[index % colors.count])
                .frame(width: 32, height: heights[index % heights.count])
            
            // Connector circle
            Circle()
                .fill(colors[index % colors.count])
                .frame(width: 22, height: 22)
                .offset(y: -4)
            
            // Bottom line
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 1, height: 15)
        }
    }
    
    private func backgroundForPage(_ page: Int) -> some View {
        Group {
            switch page {
            case 2:
                // Sunrise gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.35, green: 0.25, blue: 0.35),
                        Color(red: 0.55, green: 0.35, blue: 0.25),
                        Color(red: 0.85, green: 0.65, blue: 0.35)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            case 3:
                // Night sky gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.08, blue: 0.2),
                        Color(red: 0.1, green: 0.15, blue: 0.35),
                        Color(red: 0.15, green: 0.2, blue: 0.45)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            default:
                // Dark gray (matches Structured app styling)
                Color(red: 0.12, green: 0.12, blue: 0.14)
            }
        }
    }
    
    private func accentForPage(_ page: Int) -> Color {
        switch page {
        case 3: return JarvisTheme.accentBlue
        default: return JarvisTheme.accent
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func createDefaultTasks() {
        let cal = Calendar.current
        let today = Date()
        
        // Wake up task (recurring)
        let wakeHour = cal.component(.hour, from: wakeUpTime)
        let wakeMinute = cal.component(.minute, from: wakeUpTime)
        let wakeDate = cal.date(bySettingHour: wakeHour, minute: wakeMinute, second: 0, of: today) ?? today
        
        var wakeTask = PlannerTask(title: "Wake up", date: wakeDate, durationMinutes: 15)
        wakeTask.icon = TaskIcon.sun.rawValue
        wakeTask.colorIndex = 0 // coral
        wakeTask.recurrenceRule = .daily
        
        // Bed time task (recurring)
        let bedHour = cal.component(.hour, from: bedTime)
        let bedMinute = cal.component(.minute, from: bedTime)
        let bedDate = cal.date(bySettingHour: bedHour, minute: bedMinute, second: 0, of: today) ?? today
        
        var bedTask = PlannerTask(title: "Go to bed", date: bedDate, durationMinutes: 30)
        bedTask.icon = TaskIcon.moon.rawValue
        bedTask.colorIndex = 4 // blue
        bedTask.recurrenceRule = .daily
        
        store.add(wakeTask)
        store.add(bedTask)
    }
}
