#if !os(watchOS)
import SwiftUI
#if os(iOS)
import PhotosUI
#endif

struct WellnessView: View {
    @ObservedObject var store: PlannerStore
    @ObservedObject var wellness: WellnessStore
    @ObservedObject var aiManager: AIManager
    
    @State private var mealTitle = ""
    @State private var mealCalories = ""
    @State private var sleepStart = Calendar.current.date(byAdding: .hour, value: -8, to: Date()) ?? Date()
    @State private var sleepEnd = Date()
    @State private var activityTitle = ""
    @State private var activityMinutes = ""
    @State private var validationError: String?
    
    #if os(iOS)
    @State private var photoItem: PhotosPickerItem?
    @State private var isAnalyzing = false
    #endif
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    adviceSection
                        .animateOnAppear(delay: 0)
                    mealsSection
                        .animateOnAppear(delay: 0.06)
                    sleepSection
                        .animateOnAppear(delay: 0.12)
                    activitySection
                        .animateOnAppear(delay: 0.18)
                }
                .padding()
            }
            .background(JarvisTheme.background.ignoresSafeArea())
            .navigationTitle(L10n.healthTitle)
            .alert(L10n.errorTitle, isPresented: Binding(
                get: { validationError != nil },
                set: { if !$0 { validationError = nil } }
            )) {
                Button("OK") { validationError = nil }
            } message: {
                Text(validationError ?? "")
            }
        }
    }
    
    private var adviceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tipsTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(JarvisTheme.textPrimary)
            
            let advice = aiManager.generateAdvice(from: store.tasks)
            if advice.isEmpty {
                Text(L10n.addTasksForTips)
                    .font(.subheadline)
                    .foregroundStyle(JarvisTheme.textSecondary)
            } else {
                ForEach(advice, id: \.self) { item in
                    Label(item, systemImage: "lightbulb.fill")
                        .font(.subheadline)
                        .foregroundStyle(JarvisTheme.textPrimary)
                }
            }
        }
        .jarvisSectionCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.healthTipsLabel)
    }
    
    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.nutritionTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(JarvisTheme.textPrimary)
                Spacer()
                if wellness.todayCalories > 0 {
                    Text("\(wellness.todayCalories) \(L10n.kcal)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(JarvisTheme.accent)
                }
            }
            
            HStack(spacing: 10) {
                TextField(L10n.dish, text: $mealTitle)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 80)
                TextField(L10n.kcal, text: $mealCalories)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                
                Button { addMeal() } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(JarvisTheme.accent)
                }
                .buttonStyle(.plain)
                .bounceOnTap()
                .disabled(mealTitle.isEmpty)
                .accessibilityLabel(L10n.addDish)
                
                #if os(iOS)
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Image(systemName: isAnalyzing ? "hourglass" : "camera.viewfinder")
                        .font(.title2)
                        .foregroundStyle(JarvisTheme.accent)
                }
                .disabled(isAnalyzing)
                .onChange(of: photoItem) { _, item in
                    if let item { Task { await analyzePhoto(item) } }
                }
                #endif
            }
            
            ForEach(wellness.meals.suffix(5).reversed()) { meal in
                HStack {
                    VStack(alignment: .leading) {
                        Text(meal.title).font(.subheadline)
                        Text(meal.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(JarvisTheme.textSecondary)
                    }
                    Spacer()
                    Text("\(meal.calories) \(L10n.kcal)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JarvisTheme.accent)
                }
            }
        }
        .jarvisSectionCard()
    }
    
    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.sleepSection)
                .font(.headline.weight(.semibold))
                .foregroundStyle(JarvisTheme.textPrimary)
            
            DatePicker(L10n.bedtime, selection: $sleepStart, displayedComponents: [.date, .hourAndMinute])
            DatePicker(L10n.wakeUp, selection: $sleepEnd, displayedComponents: [.date, .hourAndMinute])
            
            Button(L10n.saveNight) { addSleep() }
                .buttonStyle(PrimaryButtonStyle())
                .bounceOnTap()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .accessibilityLabel(L10n.saveSleepLabel)
                .accessibilityHint(L10n.saveSleepHint)
            
            if let last = wellness.sleep.last {
                Text(String(format: "%@ %.1f", L10n.lastSleepHours, last.hours))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(JarvisTheme.accent)
            }
        }
        .jarvisSectionCard()
    }
    
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.activitySection)
                .font(.headline.weight(.semibold))
                .foregroundStyle(JarvisTheme.textPrimary)
            
            HStack(spacing: 10) {
                TextField(L10n.activityType, text: $activityTitle)
                    .textFieldStyle(.roundedBorder)
                TextField(L10n.minutesShort, text: $activityMinutes)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                
                Button { addActivity() } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(JarvisTheme.accent)
                }
                .buttonStyle(.plain)
                .bounceOnTap()
                .disabled(activityTitle.isEmpty)
                .accessibilityLabel(L10n.addActivity)
            }
            
            ForEach(wellness.activities.suffix(5).reversed()) { act in
                HStack {
                    VStack(alignment: .leading) {
                        Text(act.title).font(.subheadline)
                        Text(act.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(JarvisTheme.textSecondary)
                    }
                    Spacer()
                    Text("\(act.minutes) \(L10n.minutesShort)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JarvisTheme.accent)
                }
            }
        }
        .jarvisSectionCard()
    }
    
    private func addMeal() {
        if let error = WellnessValidator.validateMeal(title: mealTitle, calories: mealCalories) {
            validationError = error
            Logger.shared.warning("Meal validation: \(error)")
            return
        }
        wellness.addMeal(MealEntry(title: mealTitle, calories: Int(mealCalories) ?? 0))
        mealTitle = ""
        mealCalories = ""
    }
    
    private func addSleep() {
        if let error = WellnessValidator.validateSleep(start: sleepStart, end: sleepEnd) {
            validationError = error
            Logger.shared.warning("Sleep validation: \(error)")
            return
        }
        wellness.addSleep(SleepEntry(start: sleepStart, end: sleepEnd))
    }
    
    private func addActivity() {
        if let error = WellnessValidator.validateActivity(title: activityTitle, minutes: activityMinutes) {
            validationError = error
            Logger.shared.warning("Activity validation: \(error)")
            return
        }
        wellness.addActivity(ActivityEntry(title: activityTitle, minutes: Int(activityMinutes) ?? 0))
        activityTitle = ""
        activityMinutes = ""
    }
    
    #if os(iOS)
    private func analyzePhoto(_ item: PhotosPickerItem) async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        
        do {
            let result = try await NutritionService.shared.analyze(imageData: data)
            await MainActor.run {
                if mealTitle.isEmpty { mealTitle = result.title }
                mealCalories = "\(result.calories)"
                addMeal()
            }
        } catch {
            await MainActor.run {
                validationError = L10n.photoRecognitionFailed
            }
            Logger.shared.error(error, context: "Nutrition analysis")
        }
    }
    #endif
}
#endif
