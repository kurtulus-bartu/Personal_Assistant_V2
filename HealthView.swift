import SwiftUI
import Charts
import HealthKit

// MARK: - View Extensions

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Models

enum HealthViewMode: String, Codable, CaseIterable, Identifiable {
    case health = "Health"
    case fitness = "Fitness"
    var id: String { rawValue }
}

enum HealthMetricType: String, Codable, CaseIterable, Identifiable {
    case sleep = "Uyku"
    case movement = "Hareket"
    case calories = "Kalori"
    var id: String { rawValue }
}

enum WeightDataType: String, Codable, CaseIterable, Identifiable {
    case weight = "Kilo"
    case bodyFat = "Yağ Oranı"
    case muscleMass = "Kas Kütlesi"
    case bmi = "BMI"
    var id: String { rawValue }
}

struct HealthEntry: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var caloriesBurned: Double = 0
    var caloriesConsumed: Double = 0
    var steps: Int = 0
    var activeMinutes: Int = 0

    var calorieDeficit: Double {
        caloriesBurned - caloriesConsumed
    }
}

struct MealEntry: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var mealType: String = "Kahvaltı" // Kahvaltı, Öğle, Akşam, Atıştırmalık
    var description: String = ""
    var calories: Double = 0
    var notes: String = ""
}

struct WorkoutEntry: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var workoutType: String = "Gym" // Gym, Cardio, Yoga, etc.
    var exercises: [Exercise] = []
    var duration: Int = 0 // minutes
    var caloriesBurned: Double = 0
    var notes: String = ""
}

struct Exercise: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String = ""
    var sets: Int = 0
    var reps: Int = 0
    var weight: Double = 0
    var notes: String = ""
}

struct SleepEntry: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var bedTime: Date = Date()
    var wakeTime: Date = Date()
    var quality: Int = 3 // 1-5 scale
    var notes: String = ""

    var duration: Double {
        wakeTime.timeIntervalSince(bedTime) / 3600 // hours
    }
}

struct WeightEntry: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var weight: Double = 0 // kg
    var bodyFat: Double = 0 // percentage
    var muscleMass: Double = 0 // kg
    var bmi: Double = 0
    var notes: String = ""
}

// MARK: - Health View

struct HealthView: View {
    @EnvironmentObject private var dataStore: DataStore
    @StateObject private var healthKitManager = HealthKitManager.shared

    var onBackup: (() -> Void)? = nil
    var onRefresh: (() -> Void)? = nil

    @State private var currentMode: HealthViewMode = .health
    @State private var selectedDate = Date()
    @State private var selectedMetric: HealthMetricType = .calories
    @State private var selectedWeightDataType: WeightDataType = .weight
    @State private var selectedMealType: String = "Kahvaltı" // Kahvaltı, Öğle, Akşam

    // Data
    @State private var healthEntries: [HealthEntry] = []
    @State private var mealEntries: [MealEntry] = []
    @State private var workoutEntries: [WorkoutEntry] = []
    @State private var sleepEntries: [SleepEntry] = []
    @State private var weightEntries: [WeightEntry] = []

    // UI State
    @State private var showCalendar = false
    @State private var showAddMeal = false
    @State private var showAddWorkout = false
    @State private var showAddSleep = false
    @State private var showGoalInput = false
    @State private var isLoadingHealthData = false

    // Meal editing states
    @State private var editingMealID: UUID? = nil
    @State private var editingField: String = "" // "description" or "calories"
    @State private var editingText: String = ""
    @State private var newMealDescription: String = ""
    @State private var newMealCalories: String = ""

    // Goal states
    @State private var weightGoal: String = "75"

    private let controlSize: CGFloat = 34
    private let smallControlSize: CGFloat = 30
    private var surface: Color { Color(UIColor.secondarySystemBackground) }

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                toolbarView
                Divider()

                ScrollView {
                    VStack(spacing: 20) {
                        if currentMode == .health {
                            healthModeContent
                        } else {
                            fitnessModeContent
                        }
                    }
                    .frame(maxWidth: 650)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                }
            }

            // Takvim popup
            if showCalendar {
                Color.black.opacity(0.3).ignoresSafeArea()
                    .onTapGesture { showCalendar = false }

                CalendarPickerView(selectedDate: $selectedDate, isPresented: $showCalendar)
                    .transition(.scale.combined(with: .opacity))
            }

            // Goal Input popup
            if showGoalInput {
                Color.black.opacity(0.35).ignoresSafeArea()
                    .onTapGesture { showGoalInput = false }
                    .zIndex(999)

                GoalInputPopup
                    .zIndex(1000)
            }
        }
        .onAppear {
            requestHealthKitAuthorization()
        }
        .sheet(isPresented: $showAddMeal) { AddMealSheet }
        .sheet(isPresented: $showAddWorkout) { AddWorkoutSheet }
        .sheet(isPresented: $showAddSleep) { AddSleepSheet }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Text("Health")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(minWidth: 100, alignment: .leading)

                Spacer()

                HStack(spacing: 8) {
                    squareButton(systemName: "square.grid.2x2") { showAddMeal = true }
                    squareButton(systemName: "arrow.clockwise") {
                        onRefresh?()
                        loadHealthKitData()
                    }
                    squareButton(systemName: "square.and.arrow.up") {
                        onBackup?()
                        backupData()
                    }
                }
                .frame(minWidth: 100, alignment: .trailing)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                HealthFitnessSwitch(currentMode: $currentMode)
                Spacer()
                squareButton(systemName: "calendar") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showCalendar = true }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .padding(.top, 8)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Content Modes

    private var healthModeContent: some View {
        VStack(spacing: 20) {
            // Sağlık verileri başlığı
            VStack(alignment: .leading, spacing: 12) {
                Text("Sağlık verileri")
                    .font(.headline)
                    .fontWeight(.semibold)

                // Uyku/Hareket/Kalori Switch
                healthMetricSwitch

                // Seçilen metriğe göre günlük değer
                selectedMetricCompact
            }

            // Seçilen metriğin haftalık grafiği
            selectedMetricWeeklyChart

            // Tartı Verileri Bölümü
            weightDataSection
        }
    }

    private var fitnessModeContent: some View {
        VStack(spacing: 20) {
            // Haftalık Egzersizler
            weeklyWorkoutsCard

            // AI Fitness Koçu
            aiFitnessCoachCard
        }
    }

    // MARK: - Health Mode Components

    private var healthMetricSwitch: some View {
        HStack {
            Spacer()
            HStack(spacing: 6) {
                metricPill("Uyku", metric: .sleep)
                metricPill("Hareket", metric: .movement)
                metricPill("Kalori", metric: .calories)
            }
            .padding(.horizontal, 8)
            .frame(height: 36)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
            Spacer()
        }
    }

    private func metricPill(_ title: String, metric: HealthMetricType) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedMetric = metric
            }
        }) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selectedMetric == metric ? .blue : .primary.opacity(0.75))
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(selectedMetric == metric ? Capsule().fill(Color.blue.opacity(0.14)) : nil)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private var selectedMetricCompact: some View {
        let todayEntry = healthEntries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) ?? HealthEntry(date: selectedDate)
        let todaySleep = sleepEntries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) })

        return HStack(spacing: 12) {
            switch selectedMetric {
            case .sleep:
                if let sleep = todaySleep {
                    HStack(spacing: 4) {
                        Text("Uyku:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f saat", sleep.duration))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                } else {
                    HStack(spacing: 4) {
                        Text("Uyku:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("—")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }

            case .movement:
                HStack(spacing: 4) {
                    Text("Hareket:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(Int(todayEntry.caloriesBurned)) kcal")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

            case .calories:
                HStack(spacing: 4) {
                    Text("Kalori:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(Int(todayEntry.calorieDeficit)) açık")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            Spacer()
        }
    }

    // Keep old card view for reference if needed
    private var selectedMetricCard: some View {
        let todayEntry = healthEntries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) ?? HealthEntry(date: selectedDate)
        let todaySleep = sleepEntries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) })

        return VStack(alignment: .leading, spacing: 16) {
            Text(selectedMetric.rawValue)
                .font(.headline)
                .fontWeight(.semibold)

            switch selectedMetric {
            case .sleep:
                if let sleep = todaySleep {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Süre")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f saat", sleep.duration))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Kalite")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(sleep.quality)/5")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                    }
                } else {
                    Text("Bugün uyku verisi yok")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

            case .movement:
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Adım")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(todayEntry.steps)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aktif Dakika")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(todayEntry.activeMinutes)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }

            case .calories:
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Yakılan")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(todayEntry.caloriesBurned))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Alınan")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(todayEntry.caloriesConsumed))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Açık")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(todayEntry.calorieDeficit))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(todayEntry.calorieDeficit >= 0 ? .green : .red)
                    }
                }
            }
        }
        .padding(16)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
    }

    private var selectedMetricWeeklyChart: some View {
        let weekData = getWeekData()
        let weekSleep = getWeekSleepData()

        return VStack(alignment: .leading, spacing: 12) {
            if #available(iOS 16.0, *) {
                Chart {
                    switch selectedMetric {
                    case .sleep:
                        ForEach(weekSleep) { entry in
                            BarMark(
                                x: .value("Gün", entry.date, unit: .day),
                                y: .value("Uyku Süresi", entry.duration)
                            )
                            .foregroundStyle(.blue)
                        }
                    case .movement:
                        ForEach(weekData) { entry in
                            BarMark(
                                x: .value("Gün", entry.date, unit: .day),
                                y: .value("Adım", entry.steps)
                            )
                            .foregroundStyle(.blue)
                        }
                    case .calories:
                        ForEach(weekData) { entry in
                            LineMark(
                                x: .value("Gün", entry.date, unit: .day),
                                y: .value("Açık", entry.calorieDeficit)
                            )
                            .foregroundStyle(.blue)
                            .symbol(.circle)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 200)
            } else {
                Text("Grafikler iOS 16+ gerektirir")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            }
        }
    }

    private func getSleepHour(from date: Date) -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return Double(hour) + Double(minute) / 60.0
    }

    private func formatSleepTime(_ bedTime: Date, _ wakeTime: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: bedTime))-\(formatter.string(from: wakeTime))"
    }

    private var weightDataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tartı Verileri")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            // Dropdown for data type
            Menu {
                ForEach(WeightDataType.allCases) { type in
                    Button(action: { selectedWeightDataType = type }) {
                        HStack {
                            Text(type.rawValue)
                            if selectedWeightDataType == type {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedWeightDataType.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(UIColor.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Monthly chart
            monthlyWeightChart
        }
    }

    private var monthlyWeightChart: some View {
        let monthData = getMonthWeightData()

        // Calculate min and max values for better trend visibility
        let values = monthData.map { valueForWeightDataType($0) }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 100
        let range = maxValue - minValue
        let padding = range * 0.1 // 10% padding
        let yMin = minValue - padding
        let yMax = maxValue + padding

        return VStack(alignment: .leading, spacing: 12) {
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(monthData) { entry in
                        LineMark(
                            x: .value("Tarih", entry.date, unit: .day),
                            y: .value("Değer", valueForWeightDataType(entry))
                        )
                        .foregroundStyle(.blue)
                        .symbol(.circle)
                    }
                }
                .chartYScale(domain: yMin...yMax)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 180)
            } else {
                Text("Grafikler iOS 16+ gerektirir")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 180)
            }
        }
    }

    private func valueForWeightDataType(_ entry: WeightEntry) -> Double {
        switch selectedWeightDataType {
        case .weight: return entry.weight
        case .bodyFat: return entry.bodyFat
        case .muscleMass: return entry.muscleMass
        case .bmi: return entry.bmi
        }
    }

    // MARK: - Fitness Mode Components

    private var aiFitnessCoachCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("AI Fitness Koçu")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 12) {
                aiCoachMessage(
                    icon: "💪",
                    title: "Bugünün Önerisi",
                    message: "Geçen hafta üst vücut çalışmanız az kaldı. Bugün göğüs ve omuz egzersizlerine odaklanmanızı öneririm."
                )

                Divider()

                aiCoachMessage(
                    icon: "🎯",
                    title: "Hedef Takibi",
                    message: "Bu hafta 3/5 antrenmanı tamamladınız. Haftalık hedefinize ulaşmak için 2 antrenman daha yapmalısınız."
                )

                Divider()

                aiCoachMessage(
                    icon: "📊",
                    title: "Performans Analizi",
                    message: "Bench press kaldırma kapasitesinde son 2 haftada %8 artış gözlemlendi. Harika ilerleme!"
                )
            }

            Button(action: {
                // AI koçu ile etkileşim
            }) {
                HStack {
                    Image(systemName: "message.fill")
                    Text("Koçla Konuş")
                        .fontWeight(.medium)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func aiCoachMessage(icon: String, title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(icon)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }


    // MARK: - Weekly Workouts

    private var weeklyWorkoutsCard: some View {
        let weekWorkouts = getWeekWorkouts()

        return VStack(alignment: .leading, spacing: 12) {
            Text("Egzersizler")
                .font(.headline)
                .fontWeight(.semibold)

            if weekWorkouts.isEmpty {
                Text("Bu hafta egzersiz kaydı yok")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(weekWorkouts) { workout in
                    HStack(spacing: 12) {
                        // Egzersiz ikonu
                        Image(systemName: workoutIcon(for: workout.workoutType))
                            .font(.title3)
                            .foregroundColor(.blue)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.workoutType)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(workout.date.formatted(.dateTime.month().day().weekday()))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(workout.duration) dk")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("\(Int(workout.caloriesBurned)) kcal")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func workoutIcon(for type: String) -> String {
        switch type.lowercased() {
        case "gym": return "dumbbell.fill"
        case "cardio": return "figure.run"
        case "yoga": return "figure.mind.and.body"
        case "swimming": return "figure.pool.swim"
        default: return "figure.strengthtraining.traditional"
        }
    }

    // MARK: - Helper Views

    private func squareButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary.opacity(0.85))
                .frame(width: controlSize, height: controlSize)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.2), lineWidth: 1))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sheets


    private var AddMealSheet: some View {
        VStack(spacing: 0) {
            // Header (Kanban/Pomodoro benzeri)
            HStack(spacing: 12) {
                Text("Yemek")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                smallSquareButton(systemName: "target") {
                    showAddMeal = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showGoalInput = true
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)
            .background(Color(UIColor.systemBackground))

            // Meal Type Switch
            HStack(spacing: 8) {
                mealTypeSwitch
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))

            Divider()

            // Liste (direkt arka planda)
            ScrollView {
                VStack(spacing: 12) {
                    let mealsForType = mealEntries.filter {
                        Calendar.current.isDate($0.date, inSameDayAs: selectedDate) && $0.mealType == selectedMealType
                    }

                    // Mevcut yemekler
                    ForEach(mealsForType) { meal in
                        mealRow(meal: meal)
                    }

                    // Yeni yemek ekleme satırı
                    newMealRow
                }
                .padding(16)
            }
        }
        .background(Color(UIColor.systemBackground))
    }

    private func smallSquareButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary.opacity(0.9))
                .frame(width: smallControlSize, height: smallControlSize)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.2), lineWidth: 1))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private var mealTypeSwitch: some View {
        HStack(spacing: 6) {
            mealTypePill("Kahvaltı")
            mealTypePill("Öğle")
            mealTypePill("Akşam")
        }
        .padding(.horizontal, 8)
        .frame(height: 36)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }

    private func mealTypePill(_ type: String) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedMealType = type
            }
        }) {
            Text(type)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selectedMealType == type ? .blue : .primary.opacity(0.75))
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(selectedMealType == type ? Capsule().fill(Color.blue.opacity(0.14)) : nil)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func mealRow(meal: MealEntry) -> some View {
        HStack(spacing: 12) {
            // Eksi butonu (sol tarafta)
            Button(action: {
                deleteMeal(meal)
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)

            // Yemek adı (tıklanabilir)
            if editingMealID == meal.id && editingField == "description" {
                TextField("Yemek adı", text: $editingText, onCommit: {
                    saveMealEdit(meal: meal)
                })
                .font(.subheadline)
                .textFieldStyle(.plain)
            } else {
                Text(meal.description)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .onTapGesture {
                        startEditing(meal: meal, field: "description", initialValue: meal.description)
                    }
            }

            Spacer()

            // Kalori (tıklanabilir)
            if editingMealID == meal.id && editingField == "calories" {
                TextField("Kalori", text: $editingText, onCommit: {
                    saveMealEdit(meal: meal)
                })
                .font(.caption)
                .keyboardType(.numberPad)
                .textFieldStyle(.plain)
                .frame(width: 60)
            } else {
                Text("\(Int(meal.calories)) kcal")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .onTapGesture {
                        startEditing(meal: meal, field: "calories", initialValue: String(Int(meal.calories)))
                    }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color(UIColor.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var newMealRow: some View {
        HStack(spacing: 12) {
            // Artı butonu
            Button(action: {
                addNewMeal()
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)

            // Yemek adı text field
            TextField("Yemek adı", text: $newMealDescription)
                .font(.subheadline)
                .textFieldStyle(.plain)

            Spacer()

            // Kalori text field
            TextField("Kalori", text: $newMealCalories)
                .font(.caption)
                .keyboardType(.numberPad)
                .textFieldStyle(.plain)
                .frame(width: 60)
        }
        .padding(.vertical, 8)
    }

    private func startEditing(meal: MealEntry, field: String, initialValue: String) {
        editingMealID = meal.id
        editingField = field
        editingText = initialValue
    }

    private func saveMealEdit(meal: MealEntry) {
        if let index = mealEntries.firstIndex(where: { $0.id == meal.id }) {
            if editingField == "description" {
                mealEntries[index].description = editingText
            } else if editingField == "calories" {
                if let calories = Double(editingText) {
                    mealEntries[index].calories = calories
                }
            }
        }
        editingMealID = nil
        editingField = ""
        editingText = ""
    }

    private func deleteMeal(_ meal: MealEntry) {
        mealEntries.removeAll { $0.id == meal.id }
    }

    private func addNewMeal() {
        guard !newMealDescription.isEmpty else { return }
        let calories = Double(newMealCalories) ?? 0

        let newMeal = MealEntry(
            date: selectedDate,
            mealType: selectedMealType,
            description: newMealDescription,
            calories: calories
        )
        mealEntries.append(newMeal)

        // Save to Apple Health if authorized
        if healthKitManager.isAuthorized && calories > 0 {
            healthKitManager.saveDietaryEnergy(calories: calories, date: selectedDate) { success, error in
                if success {
                    print("Meal data saved to Apple Health")
                } else if let error = error {
                    print("Error saving meal to Apple Health: \(error.localizedDescription)")
                }
            }
        }

        // Reset fields
        newMealDescription = ""
        newMealCalories = ""
    }

    private var AddWorkoutSheet: some View {
        VStack(spacing: 16) {
            Text("Antrenman Ekle")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Antrenman ekleme formu yakında...")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Kapat") {
                showAddWorkout = false
            }
            .padding()
        }
        .padding()
    }

    private var AddSleepSheet: some View {
        VStack(spacing: 16) {
            Text("Uyku Ekle")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Uyku ekleme formu yakında...")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Kapat") {
                showAddSleep = false
            }
            .padding()
        }
        .padding()
    }

    private var GoalInputPopup: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Hedef Kilo")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showGoalInput = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)

            Divider()

            // Content
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hedef Kilo")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    TextField("Örn: 75", text: $weightGoal)
                        .textFieldStyle(.plain)
                        .keyboardType(.decimalPad)
                        .padding(12)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                // Buttons
                Button(action: {
                    // Save weight goal
                    showGoalInput = false
                }) {
                    Text("Kaydet")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(weightGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(weightGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }
            .padding(20)
        }
        .frame(maxWidth: 400)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 30, y: 15)
        .padding(.horizontal, 24)
    }

    // MARK: - Data Helpers

    private func requestHealthKitAuthorization() {
        healthKitManager.requestAuthorization { success in
            if success {
                print("HealthKit authorization granted")
                // Data will be loaded when user taps refresh button
            } else {
                print("HealthKit authorization denied")
                // Fallback to sample data if authorization is denied
                generateSampleData()
            }
        }
    }

    private func loadHealthKitData() {
        guard healthKitManager.isAuthorized else {
            print("HealthKit not authorized, using sample data")
            generateSampleData()
            return
        }

        isLoadingHealthData = true

        // Load week health data
        healthKitManager.fetchWeekHealthData(for: selectedDate) { [self] weekData in
            // Clear existing health entries
            healthEntries.removeAll()

            for (date, data) in weekData.sorted(by: { $0.key < $1.key }) {
                // Fetch dietary energy for each day
                healthKitManager.fetchDietaryEnergy(for: date) { caloriesConsumed in
                    let entry = HealthEntry(
                        date: date,
                        caloriesBurned: data.calories,
                        caloriesConsumed: caloriesConsumed,
                        steps: data.steps,
                        activeMinutes: data.activeMinutes
                    )
                    healthEntries.append(entry)
                }
            }
        }

        // Load week sleep data
        let calendar = Calendar.current
        let startOfWeek = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: selectedDate))!

        sleepEntries.removeAll()
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                healthKitManager.fetchSleepData(for: date) { bedTime, wakeTime, duration in
                    if let bedTime = bedTime, let wakeTime = wakeTime {
                        let sleepEntry = SleepEntry(
                            date: date,
                            bedTime: bedTime,
                            wakeTime: wakeTime,
                            quality: 4, // HealthKit doesn't provide quality directly
                            notes: ""
                        )
                        sleepEntries.append(sleepEntry)
                    }
                }
            }
        }

        // Load month weight data
        healthKitManager.fetchMonthWeightData(for: selectedDate) { [self] monthData in
            weightEntries.removeAll()

            for (date, data) in monthData.sorted(by: { $0.key < $1.key }) {
                if let weight = data.weight {
                    let weightEntry = WeightEntry(
                        date: date,
                        weight: weight,
                        bodyFat: data.bodyFat ?? 0,
                        muscleMass: data.leanMass ?? 0,
                        bmi: data.bmi ?? 0,
                        notes: ""
                    )
                    weightEntries.append(weightEntry)
                }
            }

            isLoadingHealthData = false
        }
    }

    private func backupData() {
        print("Health data backing up...")
        // Implement backup logic
    }

    private func getWeekData() -> [HealthEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: selectedDate)
        let weekAgo = calendar.date(byAdding: .day, value: -6, to: today)!

        return healthEntries.filter { entry in
            entry.date >= weekAgo && entry.date <= today
        }.sorted(by: { $0.date < $1.date })
    }

    private func getWeekSleepData() -> [SleepEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: selectedDate)
        let weekAgo = calendar.date(byAdding: .day, value: -6, to: today)!

        return sleepEntries.filter { entry in
            entry.date >= weekAgo && entry.date <= today
        }.sorted(by: { $0.date < $1.date })
    }

    private func getWeekWorkouts() -> [WorkoutEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: selectedDate)
        let weekAgo = calendar.date(byAdding: .day, value: -6, to: today)!

        return workoutEntries.filter { entry in
            entry.date >= weekAgo && entry.date <= today
        }.sorted(by: { $0.date > $1.date })
    }

    private func getMonthWeightData() -> [WeightEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: selectedDate)
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: today)!

        return weightEntries.filter { entry in
            entry.date >= monthAgo && entry.date <= today
        }.sorted(by: { $0.date < $1.date })
    }

    private func generateSampleData() {
        // Generate sample health data for the past week
        let calendar = Calendar.current
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                let entry = HealthEntry(
                    date: date,
                    caloriesBurned: Double.random(in: 2000...2500),
                    caloriesConsumed: Double.random(in: 1800...2200),
                    steps: Int.random(in: 5000...12000),
                    activeMinutes: Int.random(in: 30...90)
                )
                healthEntries.append(entry)

                // Sample sleep
                if let bedTime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: date),
                   let wakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 1, to: date)!) {
                    let sleep = SleepEntry(
                        date: date,
                        bedTime: bedTime,
                        wakeTime: wakeTime,
                        quality: Int.random(in: 3...5)
                    )
                    sleepEntries.append(sleep)
                }
            }
        }

        // Generate sample weight data for the past month
        for i in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                let weight = WeightEntry(
                    date: date,
                    weight: 75.0 + Double.random(in: -2...2),
                    bodyFat: 18.0 + Double.random(in: -1...1),
                    muscleMass: 32.0 + Double.random(in: -0.5...0.5),
                    bmi: 23.5 + Double.random(in: -0.5...0.5)
                )
                weightEntries.append(weight)
            }
        }

        // Generate sample workout data
        let workoutTypes = ["Gym", "Cardio", "Yoga", "Swimming"]
        for i in 0..<5 {
            if let date = calendar.date(byAdding: .day, value: -i * 2, to: Date()) {
                let workout = WorkoutEntry(
                    date: date,
                    workoutType: workoutTypes.randomElement() ?? "Gym",
                    exercises: [],
                    duration: Int.random(in: 30...90),
                    caloriesBurned: Double.random(in: 200...500)
                )
                workoutEntries.append(workout)
            }
        }
    }
}

// MARK: - Health/Fitness Switch

struct HealthFitnessSwitch: View {
    @Binding var currentMode: HealthViewMode

    private let height: CGFloat = 36
    private let spacing: CGFloat = 6

    var body: some View {
        HStack(spacing: spacing) {
            pill("Health", isOn: currentMode == .health) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    currentMode = .health
                }
            }
            pill("Fitness", isOn: currentMode == .fitness) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    currentMode = .fitness
                }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: height)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }

    private func pill(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isOn ? .blue : .primary.opacity(0.75))
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(isOn ? Capsule().fill(Color.blue.opacity(0.14)) : nil)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
