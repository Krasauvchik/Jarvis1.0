import SwiftUI
import Combine

// MARK: - Sleep Calculator Model

@MainActor
final class SleepCalculator: ObservableObject {
    @Published var wakeUpTime: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var bedTime: Date = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var mode: CalculationMode = .wakeUp
    
    enum CalculationMode: String, CaseIterable {
        case wakeUp = "wake_up"
        case bedTime = "bed_time"
        
        var displayName: String {
            switch self {
            case .wakeUp: return L10n.sleepCalcWakeUp
            case .bedTime: return L10n.sleepCalcBedtime
            }
        }
    }
    
    private let sleepCycleDuration: TimeInterval = 90 * 60
    private let fallAsleepTime: TimeInterval = 14 * 60
    
    var recommendedWakeUpTimes: [Date] {
        guard mode == .bedTime else { return [] }
        let fallAsleepTime = bedTime.addingTimeInterval(self.fallAsleepTime)
        return (4...6).map { cycles in
            fallAsleepTime.addingTimeInterval(sleepCycleDuration * Double(cycles))
        }
    }
    
    var recommendedBedTimes: [Date] {
        guard mode == .wakeUp else { return [] }
        return (4...6).reversed().map { cycles in
            wakeUpTime.addingTimeInterval(-sleepCycleDuration * Double(cycles) - fallAsleepTime)
        }
    }
    
    func sleepDuration(cycles: Int) -> String {
        let hours = (cycles * 90) / 60
        let minutes = (cycles * 90) % 60
        if minutes == 0 { return "\(hours) \(L10n.hoursShort)" }
        return "\(hours) \(L10n.hoursShort) \(minutes) \(L10n.minutesShort)"
    }
    
    func cyclesDescription(cycles: Int) -> String {
        let forms = [L10n.sleepCycleSingular, L10n.sleepCycleFew, L10n.sleepCycleMany]
        let n = cycles % 100
        let n1 = n % 10
        let form: String
        if n > 10 && n < 20 { form = forms[2] }
        else if n1 > 1 && n1 < 5 { form = forms[1] }
        else if n1 == 1 { form = forms[0] }
        else { form = forms[2] }
        return "\(cycles) \(form)"
    }
}

// MARK: - Sleep Calculator Sheet

struct SleepCalculatorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var calculator = SleepCalculator()
    let theme: JarvisTheme
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Picker(L10n.sleepCalcMode, selection: $calculator.mode) {
                        ForEach(SleepCalculator.CalculationMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        if calculator.mode == .wakeUp {
                            Text(L10n.sleepCalcWakeQuestion)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                            
                            DatePicker("", selection: $calculator.wakeUpTime, displayedComponents: .hourAndMinute)
                                #if os(iOS)
                                .datePickerStyle(.wheel)
                                #endif
                                .labelsHidden()
                        } else {
                            Text(L10n.sleepCalcBedQuestion)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                            
                            DatePicker("", selection: $calculator.bedTime, displayedComponents: .hourAndMinute)
                                #if os(iOS)
                                .datePickerStyle(.wheel)
                                #endif
                                .labelsHidden()
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackground))
                    .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "moon.zzz.fill")
                                .foregroundColor(JarvisTheme.accentPurple)
                            Text(calculator.mode == .wakeUp ? L10n.sleepCalcRecommendedBed : L10n.sleepCalcRecommendedWake)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(theme.textPrimary)
                        }
                        
                        let times = calculator.mode == .wakeUp ? calculator.recommendedBedTimes : calculator.recommendedWakeUpTimes
                        let cycles = calculator.mode == .wakeUp ? [6, 5, 4] : [4, 5, 6]
                        
                        ForEach(Array(zip(times.indices, times)), id: \.0) { index, time in
                            sleepTimeRow(time: time, cycles: cycles[index], isOptimal: index == 0)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label(L10n.sleepCalcAvgFallAsleep, systemImage: "info.circle")
                                .font(.system(size: 13))
                                .foregroundColor(theme.textSecondary)
                            
                            Label(L10n.sleepCalcCycleDuration, systemImage: "clock")
                                .font(.system(size: 13))
                                .foregroundColor(theme.textSecondary)
                            
                            Label(L10n.sleepCalcOptimalCycles, systemImage: "star")
                                .font(.system(size: 13))
                                .foregroundColor(JarvisTheme.accentGreen)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(theme.cardBackground.opacity(0.5)))
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackground))
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(theme.background)
            .navigationTitle(L10n.sleepCalcTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { dismiss() }
                }
            }
        }
    }
    
    private func sleepTimeRow(time: Date, cycles: Int, isOptimal: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(time.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(isOptimal ? JarvisTheme.accentGreen : theme.textPrimary)
                
                Text("\(calculator.cyclesDescription(cycles: cycles)) • \(calculator.sleepDuration(cycles: cycles))")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
            }
            
            Spacer()
            
            if isOptimal {
                Text(L10n.sleepOptimalLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(JarvisTheme.accentGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(JarvisTheme.accentGreen.opacity(0.15)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isOptimal ? JarvisTheme.accentGreen.opacity(0.1) : theme.cardBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isOptimal ? JarvisTheme.accentGreen.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }
}

// MARK: - User Profile Model

@MainActor
final class UserProfile: ObservableObject {
    static let shared = UserProfile()
    
    @Published var name: String {
        didSet { UserDefaults.standard.set(name, forKey: "jarvis_user_name") }
    }
    @Published var email: String {
        didSet { UserDefaults.standard.set(email, forKey: "jarvis_user_email") }
    }
    @Published var avatarEmoji: String {
        didSet { UserDefaults.standard.set(avatarEmoji, forKey: "jarvis_user_avatar") }
    }
    
    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
    
    private init() {
        name = UserDefaults.standard.string(forKey: "jarvis_user_name") ?? "User"
        email = UserDefaults.standard.string(forKey: "jarvis_user_email") ?? ""
        avatarEmoji = UserDefaults.standard.string(forKey: "jarvis_user_avatar") ?? "😊"
    }
}

// MARK: - Profile Sheet

struct ProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userProfile = UserProfile.shared
    @StateObject private var store = PlannerStore.shared
    let theme: JarvisTheme
    
    @State private var editedName: String = ""
    @State private var editedEmail: String = ""
    @State private var selectedEmoji: String = ""
    
    private let emojis = ["😊", "😎", "🚀", "⭐️", "🔥", "💪", "🎯", "💡", "🌟", "✨", "🎨", "📱", "💻", "🏆", "👤", "🦊"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [JarvisTheme.accent, JarvisTheme.accentOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 100, height: 100)
                            
                            Text(selectedEmoji)
                                .font(.system(size: 50))
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(emojis, id: \.self) { emoji in
                                    Text(emoji)
                                        .font(.system(size: 28))
                                        .padding(8)
                                        .background(
                                            Circle()
                                                .fill(selectedEmoji == emoji ? JarvisTheme.accent.opacity(0.2) : Color.clear)
                                        )
                                        .onTapGesture { selectedEmoji = emoji }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 20)
                    
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.profileName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                            TextField(L10n.profileNamePlaceholder, text: $editedName)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.email)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                            TextField(L10n.profileEmailPlaceholder, text: $editedEmail)
                                .textFieldStyle(.roundedBorder)
                                #if os(iOS)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                #endif
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(spacing: 12) {
                        Text(L10n.profileStats)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                        
                        HStack(spacing: 16) {
                            profileStatCard(value: "\(store.tasks.count)", label: L10n.statsTotal, color: JarvisTheme.accent)
                            profileStatCard(value: "\(store.tasks.filter { $0.isCompleted }.count)", label: L10n.statsDone, color: JarvisTheme.accentGreen)
                            profileStatCard(value: "\(completionRate)%", label: L10n.statsSuccess, color: JarvisTheme.accentBlue)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .background(theme.background)
            .navigationTitle(L10n.profileTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        userProfile.name = editedName
                        userProfile.email = editedEmail
                        userProfile.avatarEmoji = selectedEmoji
                        dismiss()
                    }
                }
            }
            .onAppear {
                editedName = userProfile.name
                editedEmail = userProfile.email
                selectedEmoji = userProfile.avatarEmoji
            }
        }
    }
    
    private var completionRate: Int {
        let total = store.tasks.count
        guard total > 0 else { return 0 }
        let completed = store.tasks.filter { $0.isCompleted }.count
        return Int(Double(completed) / Double(total) * 100)
    }
    
    private func profileStatCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 12).fill(theme.cardBackground))
    }
}
