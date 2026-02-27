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
    
    #if os(iOS)
    @State private var photoItem: PhotosPickerItem?
    @State private var isAnalyzing = false
    #endif
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    adviceSection
                    mealsSection
                    sleepSection
                    activitySection
                }
                .padding()
            }
            .background(JarvisTheme.background.ignoresSafeArea())
            .navigationTitle("Здоровье")
        }
    }
    
    // MARK: - Advice
    
    private var adviceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Советы")
                .font(.headline.weight(.semibold))
                .foregroundColor(JarvisTheme.textPrimary)
            
            let advice = aiManager.generateAdvice(from: store.tasks)
            if advice.isEmpty {
                Text("Добавь задачи для персональных рекомендаций")
                    .font(.subheadline)
                    .foregroundColor(JarvisTheme.textSecondary)
            } else {
                ForEach(advice, id: \.self) { item in
                    Label(item, systemImage: "lightbulb.fill")
                        .font(.subheadline)
                        .foregroundColor(JarvisTheme.textPrimary)
                }
            }
        }
        .jarvisSectionCard()
    }
    
    // MARK: - Meals
    
    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Питание")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(JarvisTheme.textPrimary)
                Spacer()
                if wellness.todayCalories > 0 {
                    Text("\(wellness.todayCalories) ккал")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(JarvisTheme.accent)
                }
            }
            
            HStack(spacing: 10) {
                TextField("Блюдо", text: $mealTitle)
                    .textFieldStyle(.roundedBorder)
                TextField("ккал", text: $mealCalories)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                
                Button { addMeal() } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(JarvisTheme.accent)
                }
                .buttonStyle(.plain)
                .disabled(mealTitle.isEmpty)
                
                #if os(iOS)
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Image(systemName: isAnalyzing ? "hourglass" : "camera.viewfinder")
                        .font(.title2)
                        .foregroundColor(JarvisTheme.accent)
                }
                .disabled(isAnalyzing)
                .onChange(of: photoItem) { item in
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
                            .foregroundColor(JarvisTheme.textSecondary)
                    }
                    Spacer()
                    Text("\(meal.calories) ккал")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(JarvisTheme.accent)
                }
            }
        }
        .jarvisSectionCard()
    }
    
    // MARK: - Sleep
    
    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Сон")
                .font(.headline.weight(.semibold))
                .foregroundColor(JarvisTheme.textPrimary)
            
            DatePicker("Лёг", selection: $sleepStart, displayedComponents: [.date, .hourAndMinute])
            DatePicker("Встал", selection: $sleepEnd, displayedComponents: [.date, .hourAndMinute])
            
            Button("Сохранить ночь") { addSleep() }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            
            if let last = wellness.sleep.last {
                Text(String(format: "Последний сон: %.1f ч", last.hours))
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(JarvisTheme.accent)
            }
        }
        .jarvisSectionCard()
    }
    
    // MARK: - Activity
    
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Активность")
                .font(.headline.weight(.semibold))
                .foregroundColor(JarvisTheme.textPrimary)
            
            HStack(spacing: 10) {
                TextField("Тип активности", text: $activityTitle)
                    .textFieldStyle(.roundedBorder)
                TextField("мин", text: $activityMinutes)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                
                Button { addActivity() } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(JarvisTheme.accent)
                }
                .buttonStyle(.plain)
                .disabled(activityTitle.isEmpty)
            }
            
            ForEach(wellness.activities.suffix(5).reversed()) { act in
                HStack {
                    VStack(alignment: .leading) {
                        Text(act.title).font(.subheadline)
                        Text(act.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(JarvisTheme.textSecondary)
                    }
                    Spacer()
                    Text("\(act.minutes) мин")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(JarvisTheme.accent)
                }
            }
        }
        .jarvisSectionCard()
    }
    
    // MARK: - Actions
    
    private func addMeal() {
        let entry = MealEntry(title: mealTitle, calories: Int(mealCalories) ?? 0)
        wellness.addMeal(entry)
        mealTitle = ""
        mealCalories = ""
    }
    
    private func addSleep() {
        guard sleepEnd > sleepStart else { return }
        wellness.addSleep(SleepEntry(start: sleepStart, end: sleepEnd))
    }
    
    private func addActivity() {
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
            print("Nutrition analysis failed: \(error)")
        }
    }
    #endif
}
