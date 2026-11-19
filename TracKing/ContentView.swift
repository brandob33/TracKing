import SwiftUI
import SwiftData

/// What kind of account someone has. It's picked when the account is created and decides
/// which tabs they get: the coach's (Workout, Results, Team) or the athlete's (Today, History, Profile).
enum AppRole: String, Codable {
    case coach
    case athlete
}

/// The app's root: sign in, set up the account the first time, then the tabs for that
/// account type.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]
    @Query private var eventGroups: [EventGroup]
    @State private var auth = AuthModel()
    /// Every group's clock and rest, kept here so timing carries on across tabs.
    @State private var board = TrackBoardModel()
    @State private var isShowingSplash = true

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
            switch auth.state {
            case .loading:
                Color.screenBackground.ignoresSafeArea()
            case .signedOut:
                SignInView()
            case .needsAccount:
                AccountSetupView()
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't Load Your Account", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") { Task { await auth.loadAccount() } }
                        .buttonStyle(.borderedProminent)
                    Button("Sign Out", role: .destructive) { auth.signOut() }
                }
            case .ready:
                switch auth.account?.role {
                case .coach?: coachTabs
                case .athlete?: athleteTabs
                case nil: AccountSetupView()
                }
            }
        }
        .overlay {
            // Hold the logo until we know whether someone is signed in, so the sign-in
            // screen doesn't flash up first.
            if isShowingSplash || auth.state == .loading {
                SplashView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: auth.state)
        .tint(Theme.blue)
        .environment(auth)
        .environment(board)
        .environment(\.eventGroupNames, Dictionary(eventGroups.map { ($0.groupID, $0.name) }, uniquingKeysWith: { first, _ in first }))
        .onChange(of: auth.account) { linkDeviceAthlete() }
        .task {
            auth.start()
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

    /// Ties this phone's athlete to the signed-in account, so times they log are saved under
    /// their account ID, ready to sync to Firestore.
    private func linkDeviceAthlete() {
        guard let uid = auth.uid, let account = auth.account, let deviceAthlete else { return }
        if deviceAthlete.athleteID != uid {
            deviceAthlete.athleteID = uid
        }
        if deviceAthlete.name != account.name {
            deviceAthlete.name = account.name
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
