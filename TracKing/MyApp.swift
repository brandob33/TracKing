import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn

@main struct MyApp: App {
    init() {
        // Reads GoogleService-Info.plist. Firestore keeps an offline copy by default, so
        // times logged at a track with no signal sync once the phone is back online.
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Google's sign-in sheet hands its result back through the app's URL scheme.
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(for: SampleData.modelTypes)
    }
}
