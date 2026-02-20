import Foundation
import HealthKit

@Observable
class HealthKitManager {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    var isAuthorized = false
    var authorizationDenied = false

    // Today's data
    var todaySteps: Int = 0
    var todaySleepHours: Double = 0
    var todayBedtime: Date?
    var todayWakeTime: Date?
    var todayActiveEnergy: Double = 0
    var todayWorkoutDetected: Bool = false
    var todayWorkoutType: String?
    var todayWorkoutDuration: Int = 0
    var todayWater: Double = 0
    var todayRestingHeartRate: Double = 0
    var latestWeight: Double = 0

    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        if let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepCount)
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        types.insert(HKObjectType.workoutType())
        if let water = HKQuantityType.quantityType(forIdentifier: .dietaryWater) {
            types.insert(water)
        }
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMass)
        }
        return types
    }()

    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async {
        guard isHealthKitAvailable else {
            authorizationDenied = true
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            await MainActor.run {
                isAuthorized = true
            }
            await refreshTodayData()
        } catch {
            await MainActor.run {
                authorizationDenied = true
            }
        }
    }

    func refreshTodayData() async {
        async let steps = fetchTodaySteps()
        async let sleep = fetchSleepData()
        async let energy = fetchTodayActiveEnergy()
        async let workout = fetchTodayWorkouts()
        async let water = fetchTodayWater()
        async let hr = fetchRestingHeartRate()
        async let weight = fetchLatestWeight()

        let (s, sl, e, w, wa, h, wt) = await (steps, sleep, energy, workout, water, hr, weight)

        await MainActor.run {
            todaySteps = s
            todaySleepHours = sl.hours
            todayBedtime = sl.bedtime
            todayWakeTime = sl.wakeTime
            todayActiveEnergy = e
            todayWorkoutDetected = w.detected
            todayWorkoutType = w.type
            todayWorkoutDuration = w.duration
            todayWater = wa
            todayRestingHeartRate = h
            latestWeight = wt
        }
    }

    // MARK: - Step Count

    private func fetchTodaySteps() async -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let (start, end) = todayRange()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            healthStore.execute(query)
        }
    }

    func fetchSteps(for date: Date) async -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? date

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Sleep Analysis

    private func fetchSleepData() async -> (hours: Double, bedtime: Date?, wakeTime: Date?) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return (0, nil, nil)
        }

        // Look at last night's sleep (from yesterday 6pm to today noon)
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let yesterday6pm = calendar.date(byAdding: .hour, value: -6, to: todayStart) ?? todayStart
        let todayNoon = calendar.date(byAdding: .hour, value: 12, to: todayStart) ?? now

        let predicate = HKQuery.predicateForSamples(withStart: yesterday6pm, end: todayNoon, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: (0, nil, nil))
                    return
                }

                // Filter for asleep states (not inBed)
                let asleepSamples = samples.filter { sample in
                    sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                    sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                }

                guard !asleepSamples.isEmpty else {
                    continuation.resume(returning: (0, nil, nil))
                    return
                }

                let totalSeconds = asleepSamples.reduce(0.0) { sum, sample in
                    sum + sample.endDate.timeIntervalSince(sample.startDate)
                }
                let hours = totalSeconds / 3600.0
                let bedtime = asleepSamples.first?.startDate
                let wakeTime = asleepSamples.last?.endDate

                continuation.resume(returning: (hours, bedtime, wakeTime))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Active Energy

    private func fetchTodayActiveEnergy() async -> Double {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        let (start, end) = todayRange()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let energy = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: energy)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Workouts

    private func fetchTodayWorkouts() async -> (detected: Bool, type: String?, duration: Int) {
        let (start, end) = todayRange()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let workout = samples?.first as? HKWorkout else {
                    continuation.resume(returning: (false, nil, 0))
                    return
                }

                let type = self.workoutTypeName(workout.workoutActivityType)
                let duration = Int(workout.duration / 60)
                continuation.resume(returning: (true, type, duration))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Water

    private func fetchTodayWater() async -> Double {
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return 0 }
        let (start, end) = todayRange()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: waterType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let water = result?.sumQuantity()?.doubleValue(for: .fluidOunceUS()) ?? 0
                continuation.resume(returning: water)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Heart Rate

    private func fetchRestingHeartRate() async -> Double {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return 0 }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: hrType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: 0)
                    return
                }
                let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                continuation.resume(returning: bpm)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Weight

    private func fetchLatestWeight() async -> Double {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return 0 }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: 0)
                    return
                }
                let weight = sample.quantity.doubleValue(for: .pound())
                continuation.resume(returning: weight)
            }
            healthStore.execute(query)
        }
    }

    func fetchWeightHistory(days: Int = 90) async -> [(date: Date, weight: Double)] {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return [] }
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: weightType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                let results = (samples as? [HKQuantitySample])?.map { sample in
                    (date: sample.startDate, weight: sample.quantity.doubleValue(for: .pound()))
                } ?? []
                continuation.resume(returning: results)
            }
            healthStore.execute(query)
        }
    }

    func fetchDailySteps(days: Int = 90) async -> [(date: Date, steps: Int)] {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate

        var interval = DateComponents()
        interval.day = 1

        let anchorDate = calendar.startOfDay(for: startDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: nil,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, _ in
                var stepData: [(date: Date, steps: Int)] = []
                results?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let steps = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    stepData.append((date: statistics.startDate, steps: Int(steps)))
                }
                continuation.resume(returning: stepData)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Helpers

    private func todayRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? Date()
        return (start, end)
    }

    private func workoutTypeName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength Training"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .basketball: return "Basketball"
        case .tennis: return "Tennis"
        case .racquetball: return "Racquetball"
        case .walking: return "Walking"
        case .hiking: return "Hiking"
        case .coreTraining: return "Core Training"
        case .highIntensityIntervalTraining: return "HIIT"
        default: return "Workout"
        }
    }
}
