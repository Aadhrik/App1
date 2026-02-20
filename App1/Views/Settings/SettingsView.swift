import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allTargets: [UserTargets]
    @Query private var allLogs: [DailyLog]
    @Query(sort: \Supplement.sortOrder) private var supplements: [Supplement]
    @Query(sort: \WeeklyActivity.sortOrder) private var weeklyActivities: [WeeklyActivity]

    @State private var healthKit = HealthKitManager.shared
    @State private var showingResetAlert = false
    @State private var showingAddActivitySheet = false
    @State private var activityToEdit: WeeklyActivity?

    private var targets: UserTargets {
        allTargets.first ?? UserTargets.defaults
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Targets
                Section("Targets") {
                    NavigationLink {
                        TargetsEditor(targets: targets)
                    } label: {
                        Label("Edit Targets", systemImage: "target")
                    }
                }

                // MARK: - Customize
                Section("Customize") {
                    NavigationLink {
                        SupplementsEditor()
                    } label: {
                        Label {
                            HStack {
                                Text("Supplements")
                                Spacer()
                                Text("\(supplements.filter(\.isActive).count) active")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "pill")
                        }
                    }

                    NavigationLink {
                        ChecklistEditor()
                    } label: {
                        Label("Checklist Items", systemImage: "checklist")
                    }

                    // Weekly Activities inline
                    DisclosureGroup {
                        ForEach(weeklyActivities) { activity in
                            HStack(spacing: 12) {
                                Image(systemName: activity.icon)
                                    .foregroundStyle(activity.isActive ? .blue : .gray)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(activity.name)
                                        .font(.body)
                                    Text("\(activity.targetFrequency)x per week")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    activityToEdit = activity
                                } label: {
                                    Image(systemName: "pencil.circle")
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete(perform: deleteActivities)

                        Button {
                            showingAddActivitySheet = true
                        } label: {
                            Label("Add Activity", systemImage: "plus.circle")
                        }
                    } label: {
                        Label {
                            HStack {
                                Text("Weekly Activities")
                                Spacer()
                                Text("\(weeklyActivities.filter(\.isActive).count) active")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "calendar")
                        }
                    }
                }

                // MARK: - Notifications
                Section("Notifications") {
                    NavigationLink {
                        NotificationSettings(targets: targets)
                    } label: {
                        Label("Notification Settings", systemImage: "bell")
                    }
                }

                // MARK: - Health
                Section("Health") {
                    NavigationLink {
                        BloodworkTrackerView()
                    } label: {
                        Label("Bloodwork Tracker", systemImage: "drop.fill")
                    }
                }

                // MARK: - Data
                Section("Data") {
                    ShareLink(
                        item: ExportManager.exportAsCSV(logs: allLogs),
                        subject: Text("HealthCheck Export"),
                        message: Text("My HealthCheck data export")
                    ) {
                        Label("Export as CSV", systemImage: "tablecells")
                    }

                    ShareLink(
                        item: ExportManager.exportAsJSON(logs: allLogs),
                        subject: Text("HealthCheck Export"),
                        message: Text("My HealthCheck data export")
                    ) {
                        Label("Export as JSON", systemImage: "curlybraces")
                    }

                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        Label("Reset All Data", systemImage: "trash")
                    }
                }

                // MARK: - About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("HealthKit")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(healthKit.isAuthorized ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(healthKit.isAuthorized ? "Connected" : "Not Connected")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Reset All Data", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("This will permanently delete all your logs, checklist entries, and settings. This action cannot be undone.")
            }
            .sheet(isPresented: $showingAddActivitySheet) {
                ActivityFormSheet(activity: nil) { name, frequency, icon in
                    let maxOrder = weeklyActivities.map(\.sortOrder).max() ?? -1
                    let newActivity = WeeklyActivity(
                        name: name,
                        targetFrequency: frequency,
                        icon: icon,
                        sortOrder: maxOrder + 1
                    )
                    modelContext.insert(newActivity)
                    try? modelContext.save()
                }
            }
            .sheet(item: $activityToEdit) { activity in
                ActivityFormSheet(activity: activity) { name, frequency, icon in
                    activity.name = name
                    activity.targetFrequency = frequency
                    activity.icon = icon
                    try? modelContext.save()
                }
            }
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func deleteActivities(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(weeklyActivities[index])
        }
        try? modelContext.save()
    }

    private func resetAllData() {
        // Delete all logs (cascade will delete checklist entries)
        for log in allLogs {
            modelContext.delete(log)
        }

        // Delete all supplements
        for supplement in supplements {
            modelContext.delete(supplement)
        }

        // Delete all weekly activities
        for activity in weeklyActivities {
            modelContext.delete(activity)
        }

        // Delete all targets
        for target in allTargets {
            modelContext.delete(target)
        }

        // Re-insert defaults
        modelContext.insert(UserTargets.defaults)
        for supplement in Supplement.defaults {
            modelContext.insert(supplement)
        }
        for activity in WeeklyActivity.defaults {
            modelContext.insert(activity)
        }

        try? modelContext.save()
    }
}

// MARK: - Activity Form Sheet

private struct ActivityFormSheet: View {
    @Environment(\.dismiss) private var dismiss

    let activity: WeeklyActivity?
    let onSave: (String, Int, String) -> Void

    @State private var name: String = ""
    @State private var targetFrequency: Int = 1
    @State private var icon: String = "figure.run"
    @State private var isActive: Bool = true

    private let commonIcons = [
        "figure.run",
        "figure.strengthtraining.traditional",
        "figure.pool.swim",
        "figure.yoga",
        "figure.hiking",
        "figure.basketball",
        "figure.pickleball",
        "figure.tennis",
        "figure.soccer",
        "figure.cooldown",
        "figure.dance",
        "figure.martial.arts",
        "bicycle",
        "figure.elliptical",
        "figure.rowing"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Activity Name", text: $name)

                    Stepper(value: $targetFrequency, in: 1...7) {
                        HStack {
                            Text("Frequency")
                            Spacer()
                            Text("\(targetFrequency)x per week")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(commonIcons, id: \.self) { iconName in
                            Button {
                                icon = iconName
                            } label: {
                                Image(systemName: iconName)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .background(icon == iconName ? Color.blue.opacity(0.2) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .foregroundStyle(icon == iconName ? .blue : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if activity != nil {
                    Section {
                        Toggle("Active", isOn: $isActive)
                    }
                }
            }
            .navigationTitle(activity == nil ? "Add Activity" : "Edit Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let activity {
                            activity.isActive = isActive
                        }
                        onSave(name, targetFrequency, icon)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let activity {
                    name = activity.name
                    targetFrequency = activity.targetFrequency
                    icon = activity.icon
                    isActive = activity.isActive
                }
            }
        }
    }
}
