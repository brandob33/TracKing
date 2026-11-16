import SwiftUI
import SwiftData

/// Which version of the app to show. Until sign-in adds real roles, it's picked with `RoleSwitchButton`.
enum AppRole: String {
    case coach
    case athlete
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]
    @Query private var eventGroups: [EventGroup]
    @AppStorage("appRole") private var role = AppRole.coach
    /// Every group's clock and rest, kept here so timing carries on across tabs.
    @State private var board = TrackBoardModel()

    /// The athlete using this device, as opposed to teammates on the coach's roster.
    private var deviceAthlete: Athlete? {
        athletes.first { $0.isDeviceUser }
    }

    var body: some View {
        Group {
            switch role {
            case .coach:
                TabView {
                    Tab("Workout", systemImage: "stopwatch.fill") {
                        CoachWorkoutView()
                    }
                    Tab("Team", systemImage: "list.clipboard") {
                        CoachView()
                    }
                }
            case .athlete:
                TabView {
                    Tab("Dashboard", systemImage: "house.fill") {
                        DashboardView()
                    }
                    Tab("Past Workouts", systemImage: "clock.arrow.circlepath") {
                        PastWorkoutsView()
                    }
                    Tab("Analytics", systemImage: "chart.xyaxis.line") {
                        AnalyticsView()
                    }
                    Tab("Profile", systemImage: "person.crop.circle") {
                        if let deviceAthlete {
                            ProfileView(athlete: deviceAthlete)
                        }
                    }
                }
                // Athlete screens filter workouts by this athlete's groups.
                .environment(\.athleteProfile, deviceAthlete?.profile ?? .sample)
            }
        }
        .environment(board)
        .environment(\.eventGroupNames, Dictionary(eventGroups.map { ($0.groupID, $0.name) }, uniquingKeysWith: { first, _ in first }))
        .task {
            SampleData.seedIfNeeded(modelContext)
            if deviceAthlete == nil {
                modelContext.insert(Athlete(isDeviceUser: true))
            }
        }
    }
}

/// Switches between the coach and athlete versions of the app.
struct RoleSwitchButton: View {
    let role: AppRole

    @AppStorage("appRole") private var currentRole = AppRole.coach

    init(to role: AppRole) {
        self.role = role
    }

    var body: some View {
        Button {
            currentRole = role
        } label: {
            Label(
                role == .coach ? "Switch to Coach" : "Switch to Athlete",
                systemImage: role == .coach ? "list.clipboard" : "figure.run"
            )
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(SampleData.previewContainer)
}
