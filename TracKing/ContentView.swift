import SwiftUI
import SwiftData

/// One tab bar with everything in it. For now we assume the person using the app is the
/// coach, so the coach's tabs come first and the athlete's screens sit alongside them.
///
/// When sign-in is added, the account type (coach or athlete) is chosen when the account is
/// created, and decides which of these tabs someone sees: coaches get Workout and Team,
/// athletes get My Training, History, and Profile.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]
    @Query private var eventGroups: [EventGroup]
    /// Every group's clock and rest, kept here so timing carries on across tabs.
    @State private var board = TrackBoardModel()

    /// The athlete using this device, as opposed to teammates on the coach's roster.
    private var deviceAthlete: Athlete? {
        athletes.first { $0.isDeviceUser }
    }

    /// Athlete screens show and log only this athlete's own sets and times.
    private var athleteProfile: AthleteProfile {
        deviceAthlete?.profile ?? .sample
    }

    var body: some View {
        TabView {
            // Coach
            Tab("Workout", systemImage: "stopwatch.fill") {
                CoachWorkoutView()
            }
            Tab("Team", systemImage: "list.clipboard") {
                CoachView()
            }

            // Athlete
            Tab("My Training", systemImage: "figure.run") {
                DashboardView()
                    .environment(\.athleteProfile, athleteProfile)
            }
            Tab("History", systemImage: "clock.arrow.circlepath") {
                PastWorkoutsView()
                    .environment(\.athleteProfile, athleteProfile)
            }
            Tab("Profile", systemImage: "person.crop.circle") {
                if let deviceAthlete {
                    ProfileView(athlete: deviceAthlete)
                        .environment(\.athleteProfile, athleteProfile)
                }
            }
        }
        .tint(Theme.blue)
        .environment(board)
        .environment(\.eventGroupNames, Dictionary(eventGroups.map { ($0.groupID, $0.name) }, uniquingKeysWith: { first, _ in first }))
        .task {
            SampleData.seedIfNeeded(modelContext)
            if deviceAthlete == nil {
                modelContext.insert(Athlete(isDeviceUser: true))
            }
            // Bring back any clocks, rests, and un-named times from before the app was closed.
            let sets = (try? modelContext.fetch(FetchDescriptor<WorkoutSet>())) ?? []
            let everyone = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
            board.restore(sets: sets, athletes: everyone)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(SampleData.previewContainer)
}
