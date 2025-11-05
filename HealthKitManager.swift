import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()

    @Published var isAuthorized = false

    private init() {}

    // MARK: - Authorization

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        // Check if HealthKit is available on this device
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }

        // Define the data types we want to read
        let typesToRead: Set<HKObjectType> = [
            // Activity
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,

            // Nutrition
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,

            // Sleep
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,

            // Body Measurements
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKObjectType.quantityType(forIdentifier: .leanBodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyMassIndex)!,
        ]

        // Define the data types we want to write
        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
        ]

        // Request authorization
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isAuthorized = success
                completion(success)
            }

            if let error = error {
                print("HealthKit authorization error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Fetch Steps

    func fetchSteps(for date: Date, completion: @escaping (Int) -> Void) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(0)
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                DispatchQueue.main.async {
                    completion(0)
                }
                return
            }

            let steps = Int(sum.doubleValue(for: HKUnit.count()))
            DispatchQueue.main.async {
                completion(steps)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Fetch Active Energy (Calories Burned)

    func fetchActiveEnergy(for date: Date, completion: @escaping (Double) -> Void) {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion(0)
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                DispatchQueue.main.async {
                    completion(0)
                }
                return
            }

            let calories = sum.doubleValue(for: HKUnit.kilocalorie())
            DispatchQueue.main.async {
                completion(calories)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Fetch Exercise Minutes

    func fetchExerciseMinutes(for date: Date, completion: @escaping (Int) -> Void) {
        guard let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else {
            completion(0)
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: exerciseType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                DispatchQueue.main.async {
                    completion(0)
                }
                return
            }

            let minutes = Int(sum.doubleValue(for: HKUnit.minute()))
            DispatchQueue.main.async {
                completion(minutes)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Fetch Dietary Energy (Calories Consumed)

    func fetchDietaryEnergy(for date: Date, completion: @escaping (Double) -> Void) {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
            completion(0)
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                DispatchQueue.main.async {
                    completion(0)
                }
                return
            }

            let calories = sum.doubleValue(for: HKUnit.kilocalorie())
            DispatchQueue.main.async {
                completion(calories)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Fetch Sleep Data

    func fetchSleepData(for date: Date, completion: @escaping (Date?, Date?, Double) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(nil, nil, 0)
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let samples = samples as? [HKCategorySample] else {
                DispatchQueue.main.async {
                    completion(nil, nil, 0)
                }
                return
            }

            // Filter for "in bed" or "asleep" samples
            let sleepSamples = samples.filter { sample in
                let value = sample.value
                return value == HKCategoryValueSleepAnalysis.inBed.rawValue ||
                       value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                       value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                       value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                       value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
            }

            guard !sleepSamples.isEmpty else {
                DispatchQueue.main.async {
                    completion(nil, nil, 0)
                }
                return
            }

            // Get the earliest start time and latest end time
            let bedTime = sleepSamples.first!.startDate
            let wakeTime = sleepSamples.last!.endDate

            // Calculate total sleep duration in hours
            let totalSeconds = sleepSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            let totalHours = totalSeconds / 3600.0

            DispatchQueue.main.async {
                completion(bedTime, wakeTime, totalHours)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Fetch Body Mass (Weight)

    func fetchBodyMass(for date: Date, completion: @escaping (Double?) -> Void) {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            completion(nil)
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(sampleType: weightType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            let weight = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
            DispatchQueue.main.async {
                completion(weight)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Fetch Body Fat Percentage

    func fetchBodyFatPercentage(for date: Date, completion: @escaping (Double?) -> Void) {
        guard let bodyFatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else {
            completion(nil)
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(sampleType: bodyFatType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            let bodyFat = sample.quantity.doubleValue(for: HKUnit.percent()) * 100 // Convert to percentage
            DispatchQueue.main.async {
                completion(bodyFat)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Fetch Lean Body Mass

    func fetchLeanBodyMass(for date: Date, completion: @escaping (Double?) -> Void) {
        guard let leanMassType = HKQuantityType.quantityType(forIdentifier: .leanBodyMass) else {
            completion(nil)
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(sampleType: leanMassType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            let leanMass = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
            DispatchQueue.main.async {
                completion(leanMass)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Fetch BMI

    func fetchBMI(for date: Date, completion: @escaping (Double?) -> Void) {
        guard let bmiType = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) else {
            completion(nil)
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(sampleType: bmiType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            let bmi = sample.quantity.doubleValue(for: HKUnit.count())
            DispatchQueue.main.async {
                completion(bmi)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Fetch Week Data

    func fetchWeekHealthData(for endDate: Date, completion: @escaping ([Date: (steps: Int, calories: Double, activeMinutes: Int)]) -> Void) {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: endDate))!

        var results: [Date: (steps: Int, calories: Double, activeMinutes: Int)] = [:]
        let dispatchGroup = DispatchGroup()

        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                let dayStart = calendar.startOfDay(for: date)

                dispatchGroup.enter()
                fetchSteps(for: dayStart) { steps in
                    if results[dayStart] == nil {
                        results[dayStart] = (steps: 0, calories: 0, activeMinutes: 0)
                    }
                    results[dayStart]?.steps = steps
                    dispatchGroup.leave()
                }

                dispatchGroup.enter()
                fetchActiveEnergy(for: dayStart) { calories in
                    if results[dayStart] == nil {
                        results[dayStart] = (steps: 0, calories: 0, activeMinutes: 0)
                    }
                    results[dayStart]?.calories = calories
                    dispatchGroup.leave()
                }

                dispatchGroup.enter()
                fetchExerciseMinutes(for: dayStart) { minutes in
                    if results[dayStart] == nil {
                        results[dayStart] = (steps: 0, calories: 0, activeMinutes: 0)
                    }
                    results[dayStart]?.activeMinutes = minutes
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion(results)
        }
    }

    // MARK: - Write Dietary Energy

    func saveDietaryEnergy(calories: Double, date: Date, completion: @escaping (Bool, Error?) -> Void) {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
            completion(false, nil)
            return
        }

        let quantity = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: calories)
        let sample = HKQuantitySample(type: energyType, quantity: quantity, start: date, end: date)

        healthStore.save(sample) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }

    // MARK: - Fetch Month Weight Data

    func fetchMonthWeightData(for endDate: Date, completion: @escaping ([Date: (weight: Double?, bodyFat: Double?, leanMass: Double?, bmi: Double?)]) -> Void) {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: endDate))!

        var results: [Date: (weight: Double?, bodyFat: Double?, leanMass: Double?, bmi: Double?)] = [:]
        let dispatchGroup = DispatchGroup()

        for i in 0..<31 {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                let dayStart = calendar.startOfDay(for: date)

                dispatchGroup.enter()
                fetchBodyMass(for: dayStart) { weight in
                    if results[dayStart] == nil {
                        results[dayStart] = (weight: nil, bodyFat: nil, leanMass: nil, bmi: nil)
                    }
                    results[dayStart]?.weight = weight
                    dispatchGroup.leave()
                }

                dispatchGroup.enter()
                fetchBodyFatPercentage(for: dayStart) { bodyFat in
                    if results[dayStart] == nil {
                        results[dayStart] = (weight: nil, bodyFat: nil, leanMass: nil, bmi: nil)
                    }
                    results[dayStart]?.bodyFat = bodyFat
                    dispatchGroup.leave()
                }

                dispatchGroup.enter()
                fetchLeanBodyMass(for: dayStart) { leanMass in
                    if results[dayStart] == nil {
                        results[dayStart] = (weight: nil, bodyFat: nil, leanMass: nil, bmi: nil)
                    }
                    results[dayStart]?.leanMass = leanMass
                    dispatchGroup.leave()
                }

                dispatchGroup.enter()
                fetchBMI(for: dayStart) { bmi in
                    if results[dayStart] == nil {
                        results[dayStart] = (weight: nil, bodyFat: nil, leanMass: nil, bmi: nil)
                    }
                    results[dayStart]?.bmi = bmi
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion(results)
        }
    }
}
