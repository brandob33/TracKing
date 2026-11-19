import SwiftUI
import SwiftData

/// Who is using the app on this phone. It decides which tabs they get.
///
/// For now it's picked on the opening screen and can be changed from the Team tab (coach) or
/// the Profile tab (athlete). When sign-in is added, the account type will set it instead.
enum AppRole: String {
    case coach
    case athlete

    /// Where the choice is saved.
    static let storageKey = "app.role"
}

/// The app's root: the opening screen the first time, then the coach's tabs (Workout, Results,
/// Team) or the athlete's tabs (Today, History, Profile).
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]
    @Query private var eventGroups: [EventGroup]
    @AppStorage(AppRole.storageKey) private var roleName = ""
    /// Every group's clock and rest, kept here so timing carries on across tabs.
    @State private var board = TrackBoardModel()
    @State private var isShowingSplash = true

    private var role: AppRole? {
        AppRole(rawValue: roleName)
    }

    /// The athlete using this device, as opposed to teammates on the coach's roster.
    private var deviceAthlete: Athlete? {
        athletes.first { $0.isDeviceUser }
    }

    /// Athlete screens show and log only this athlete's own sets and times.
    private var athleteProfile: AthleteProfile {
        deviceAthlete?.profile ?? .sample
    }

    var body: some View {
        Group {
            switch role {
            case .coach?:
                coachTabs
            case .athlete?:
                athleteTabs
            case nil:
                if let deviceAthlete {
                    WelcomeView(athlete: deviceAthlete) { chosen in
                        roleName = chosen.rawValue
                    }
                } else {
                    Color.screenBackground.ignoresSafeArea()
                }
            }
        }
        .overlay {
            if isShowingSplash {
                SplashView()
                    .transition(.opacity)
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

            // The launch screen already showed the logo, so only hold it long enough for the
            // name to fade in, then reveal the app.
            try? await Task.sleep(for: .seconds(0.35))
            withAnimation(.easeOut(duration: 0.25)) {
                isShowingSplash = false
            }
        }
    }

    private var coachTabs: some View {
        TabView {
            Tab("Workout", systemImage: "stopwatch.fill") {
                CoachWorkoutView()
            }
            Tab("Results", systemImage: "tablecells") {
                CoachResultsView()
            }
            Tab("Team", systemImage: "person.3.fill") {
                CoachView()
            }
        }
    }

    private var athleteTabs: some View {
        TabView {
            Tab("Today", systemImage: "figure.run") {
                DashboardView()
            }
            Tab("History", systemImage: "clock.arrow.circlepath") {
                PastWorkoutsView()
            }
            Tab("Profile", systemImage: "person.crop.circle") {
                if let deviceAthlete {
                    ProfileView(athlete: deviceAthlete)
                }
            }
        }
        .environment(\.athleteProfile, athleteProfile)
    }
}

/// The logo, shown for a moment while the app opens.
/// Picks up where the system launch screen (`UILaunchScreen` in Info.plist) leaves off: the
/// logo in the same spot and size, so there's no jump, with the app's name fading in below.
private struct SplashView: View {
    @State private var isShowingName = false

    var body: some View {
        // Matches LaunchLogo: a 384px image at 3x, centered in the safe area.
        LogoMark(size: 128)
            .overlay(alignment: .bottom) {
                Text("TracKing")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.blue)
                    .fixedSize()
                    .offset(y: 56)
                    .opacity(isShowingName ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.easeOut(duration: 0.25)) { isShowingName = true }
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(SampleData.previewContainer)
}
