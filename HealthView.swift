import SwiftUI
import Charts

// MARK: - Models

enum HealthViewMode: String, Codable, CaseIterable, Identifiable {
    case daily = "Günlük"
    case weekly = "Haftalık"
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

// MARK: - Health View

struct HealthView: View {
    @EnvironmentObject private var dataStore: DataStore

    var onBackup: (() -> Void)? = nil
    var onRefresh: (() -> Void)? = nil

    @State private var currentMode: HealthViewMode = .daily
    @State private var selectedDate = Date()

    // Data
    @State private var healthEntries: [HealthEntry] = []
    @State private var mealEntries: [MealEntry] = []
    @State private var workoutEntries: [WorkoutEntry] = []
    @State private var sleepEntries: [SleepEntry] = []

    // UI State
    @State private var showHistory = false
    @State private var showAddMeal = false
    @State private var showAddWorkout = false
    @State private var showAddSleep = false

    private let controlSize: CGFloat = 34
    private var surface: Color { Color(UIColor.secondarySystemBackground) }

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                toolbarView
                Divider()

                ScrollView {
                    VStack(spacing: 20) {
                        // Kalori Özeti
                        caloriesSummaryCard

                        // Yemek Menüsü
                        mealSectionCard

                        // Spor Programı
                        workoutSectionCard

                        // Grafikler
                        chartsSection

                        // Uyku Grafiği
                        sleepChartCard

                        // Haftalık Egzersizler
                        weeklyWorkoutsCard
                    }
                    .padding(16)
                }
            }
        }
        .onAppear {
            loadData()
            generateSampleData()
        }
        .sheet(isPresented: $showHistory) { HistorySheet }
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
                    squareButton(systemName: "arrow.clockwise") {
                        onRefresh?()
                        loadData()
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
                DailyWeeklySwitch(currentMode: $currentMode)
                Spacer()
                squareButton(systemName: "clock.arrow.circlepath") { showHistory = true }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .padding(.top, 8)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Calories Summary

    private var caloriesSummaryCard: some View {
        let todayEntry = healthEntries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) ?? HealthEntry(date: selectedDate)

        return VStack(alignment: .leading, spacing: 16) {
            Text("Kalori Özeti")
                .font(.headline)
                .fontWeight(.semibold)

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

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Adım")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(todayEntry.steps)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Divider().frame(height: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Aktif Dakika")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(todayEntry.activeMinutes)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding(16)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
    }

    // MARK: - Meal Section

    private var mealSectionCard: some View {
        let todayMeals = mealEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Günlük Yemek Menüsü")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showAddMeal = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }

            if todayMeals.isEmpty {
                Text("Henüz yemek kaydı yok")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(todayMeals) { meal in
                    mealRow(meal: meal)
                }
            }
        }
        .padding(16)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
    }

    private func mealRow(meal: MealEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.mealType)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(meal.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(Int(meal.calories)) kcal")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Workout Section

    private var workoutSectionCard: some View {
        let todayWorkouts = workoutEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Spor Programı")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showAddWorkout = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                }
            }

            if todayWorkouts.isEmpty {
                Text("Bugün spor programı yok")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(todayWorkouts) { workout in
                    workoutRow(workout: workout)
                }
            }
        }
        .padding(16)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
    }

    private func workoutRow(workout: WorkoutEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workout.workoutType)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(workout.duration) dk")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !workout.exercises.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(workout.exercises.prefix(3)) { exercise in
                        Text("• \(exercise.name) - \(exercise.sets)x\(exercise.reps) @ \(Int(exercise.weight))kg")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Charts Section

    private var chartsSection: some View {
        VStack(spacing: 16) {
            // Kalori Grafiği
            calorieChartCard

            // Kalori Açığı Grafiği
            calorieDeficitChartCard
        }
    }

    private var calorieChartCard: some View {
        let weekData = getWeekData()

        return VStack(alignment: .leading, spacing: 12) {
            Text("Haftalık Kalori")
                .font(.headline)
                .fontWeight(.semibold)

            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(weekData) { entry in
                        BarMark(
                            x: .value("Gün", entry.date, unit: .day),
                            y: .value("Yakılan", entry.caloriesBurned)
                        )
                        .foregroundStyle(.orange)

                        BarMark(
                            x: .value("Gün", entry.date, unit: .day),
                            y: .value("Alınan", entry.caloriesConsumed)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .frame(height: 200)
            } else {
                Text("Grafikler iOS 16+ gerektirir")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            }
        }
        .padding(16)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
    }

    private var calorieDeficitChartCard: some View {
        let weekData = getWeekData()

        return VStack(alignment: .leading, spacing: 12) {
            Text("Kalori Açığı")
                .font(.headline)
                .fontWeight(.semibold)

            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(weekData) { entry in
                        LineMark(
                            x: .value("Gün", entry.date, unit: .day),
                            y: .value("Açık", entry.calorieDeficit)
                        )
                        .foregroundStyle(.green)
                        .symbol(.circle)
                    }
                }
                .frame(height: 180)
            } else {
                Text("Grafikler iOS 16+ gerektirir")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 180)
            }
        }
        .padding(16)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
    }

    // MARK: - Sleep Chart

    private var sleepChartCard: some View {
        let weekSleep = getWeekSleepData()

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Uyku Grafiği")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showAddSleep = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.purple)
                }
            }

            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(weekSleep) { entry in
                        BarMark(
                            x: .value("Gün", entry.date, unit: .day),
                            y: .value("Saat", entry.duration)
                        )
                        .foregroundStyle(.purple)
                    }
                }
                .frame(height: 180)
            } else {
                Text("Grafikler iOS 16+ gerektirir")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 180)
            }
        }
        .padding(16)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
    }

    // MARK: - Weekly Workouts

    private var weeklyWorkoutsCard: some View {
        let weekWorkouts = getWeekWorkouts()

        return VStack(alignment: .leading, spacing: 12) {
            Text("Bu Hafta Yapılan Egzersizler")
                .font(.headline)
                .fontWeight(.semibold)

            if weekWorkouts.isEmpty {
                Text("Bu hafta egzersiz kaydı yok")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(weekWorkouts) { workout in
                    HStack {
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
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.vertical, 6)
                    Divider()
                }
            }
        }
        .padding(16)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
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

    private var HistorySheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Geçmiş")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(healthEntries.sorted(by: { $0.date > $1.date }).prefix(30)) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.date.formatted(.dateTime.month().day().weekday()))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("\(Int(entry.calorieDeficit)) kcal açık")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("🔥 \(Int(entry.caloriesBurned))")
                                    .font(.caption)
                                Text("🍽️ \(Int(entry.caloriesConsumed))")
                                    .font(.caption)
                            }
                        }
                        .padding(12)
                        .background(surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(16)
            }
        }
    }

    private var AddMealSheet: some View {
        VStack(spacing: 16) {
            Text("Yemek Ekle")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Yemek ekleme formu yakında...")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Kapat") {
                showAddMeal = false
            }
            .padding()
        }
        .padding()
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

    // MARK: - Data Helpers

    private func loadData() {
        // Load from UserDefaults or DataStore in the future
        // For now, using sample data
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
    }
}

// MARK: - Daily/Weekly Switch

struct DailyWeeklySwitch: View {
    @Binding var currentMode: HealthViewMode

    private let height: CGFloat = 36
    private let spacing: CGFloat = 6

    var body: some View {
        HStack(spacing: spacing) {
            pill("Günlük", isOn: currentMode == .daily) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    currentMode = .daily
                }
            }
            pill("Haftalık", isOn: currentMode == .weekly) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    currentMode = .weekly
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
