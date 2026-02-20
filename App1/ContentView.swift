import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var allTargets: [UserTargets]
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab = 0
    @State private var showingSetup = false

    private var targets: UserTargets? {
        allTargets.first
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "checklist")
                }
                .tag(0)

            TrendsView()
                .tabItem {
                    Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .tint(Color("AccentColor"))
        .onAppear {
            if targets == nil || targets?.hasCompletedSetup == false {
                showingSetup = true
            }
        }
        .sheet(isPresented: $showingSetup) {
            SetupView()
        }
    }
}

// MARK: - First Launch Setup View

struct SetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allTargets: [UserTargets]

    @State private var wakeHour = 7
    @State private var wakeMinute = 0
    @State private var bedHour = 23
    @State private var bedMinute = 0

    private var wakeDate: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = wakeHour
                components.minute = wakeMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                wakeHour = components.hour ?? 7
                wakeMinute = components.minute ?? 0
            }
        )
    }

    private var bedDate: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = bedHour
                components.minute = bedMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                bedHour = components.hour ?? 23
                bedMinute = components.minute ?? 0
            }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.accentColor)

                Text("Welcome to HealthCheck")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Set your wake and bedtime targets to get started. You can adjust everything else later in Settings.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 16) {
                    HStack {
                        Label("Wake Time", systemImage: "sunrise.fill")
                            .frame(width: 140, alignment: .leading)
                        Spacer()
                        DatePicker("", selection: wakeDate, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 24)

                    HStack {
                        Label("Bedtime", systemImage: "moon.fill")
                            .frame(width: 140, alignment: .leading)
                        Spacer()
                        DatePicker("", selection: bedDate, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 16)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    completeSetup()
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .interactiveDismissDisabled()
    }

    private func completeSetup() {
        let targets = allTargets.first ?? UserTargets()
        if allTargets.isEmpty {
            modelContext.insert(targets)
        }
        targets.targetWakeTimeHour = wakeHour
        targets.targetWakeTimeMinute = wakeMinute
        targets.targetBedtimeHour = bedHour
        targets.targetBedtimeMinute = bedMinute
        targets.hasCompletedSetup = true

        // Insert default supplements if needed
        let descriptor = FetchDescriptor<Supplement>()
        let existingSupplements = (try? modelContext.fetch(descriptor)) ?? []
        if existingSupplements.isEmpty {
            for supplement in Supplement.defaults {
                modelContext.insert(supplement)
            }
        }

        // Insert default weekly activities if needed
        let activityDescriptor = FetchDescriptor<WeeklyActivity>()
        let existingActivities = (try? modelContext.fetch(activityDescriptor)) ?? []
        if existingActivities.isEmpty {
            for activity in WeeklyActivity.defaults {
                modelContext.insert(activity)
            }
        }

        try? modelContext.save()

        // Request notifications
        Task {
            await NotificationManager.shared.requestAuthorization()
            NotificationManager.shared.scheduleAllNotifications(targets: targets)
        }

        dismiss()
    }
}
