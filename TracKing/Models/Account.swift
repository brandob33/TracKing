import Foundation
import Observation
import CryptoKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import UIKit

// MARK: - Firestore documents

/// `users/{uid}`: the signed-in person. The account type is picked when the account is made
/// and decides whether they get the coach's tabs or the athlete's.
struct UserAccount: Codable, Equatable {
    var name: String
    var role: AppRole
    /// The team they coach or belong to, once they've created or joined one.
    var teamID: String?
    var createdAt: Date = .now
}

/// `teams/{teamID}`: a team, and the code athletes type to join it.
struct Team: Codable, Equatable {
    var name: String
    var joinCode: String
    /// The coach who made the team.
    var createdBy: String
    var createdAt: Date = .now
}

/// `teams/{teamID}/members/{uid}`: someone on the team. Coaches assign the groups.
struct TeamMember: Codable, Equatable {
    var name: String
    var role: AppRole
    var eventGroupID: String = ""
    var genderGroupID: String = ""
    /// The code an athlete joined with. The security rules check it against the team's code.
    var joinCode: String?
}

enum AccountError: LocalizedError {
    case noTeamForCode
    case notSignedIn
    case appleSignInFailed
    case googleSignInFailed

    var errorDescription: String? {
        switch self {
        case .noTeamForCode: "No team uses that code. Check it with your coach."
        case .notSignedIn: "You're signed out. Sign in and try again."
        case .appleSignInFailed: "Sign in with Apple didn't finish. Try again."
        case .googleSignInFailed: "Google sign-in didn't finish. Try again."
        }
    }
}

// MARK: - Auth model

/// Who's signed in, their account, and their team. Watches Firebase Auth and loads the
/// matching Firestore documents, so the app can show sign-in, account setup, or the tabs.
@MainActor
@Observable
final class AuthModel {
    enum State: Equatable {
        case loading
        case signedOut
        /// Signed in, but hasn't picked an account type yet.
        case needsAccount
        case ready
        /// The account couldn't be loaded, e.g. offline on first launch.
        case failed(String)
    }

    private(set) var state: State = .loading
    private(set) var uid: String?
    private(set) var account: UserAccount?
    private(set) var team: Team?
    /// The name Sign in with Apple gave us, offered on the account screen.
    var suggestedName = ""

    private(set) var email: String?

    @ObservationIgnored private var listener: AuthStateDidChangeListenerHandle?
    @ObservationIgnored private var db: Firestore { Firestore.firestore() }
    /// The random value for the Sign in with Apple request in progress.
    @ObservationIgnored private var appleNonce: String?

    func start() {
        guard listener == nil else { return }
        // Xcode previews don't run the app's startup, so Firebase isn't configured there.
        guard FirebaseApp.app() != nil else {
            state = .signedOut
            return
        }
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            let email = user?.email
            Task {
                self?.email = email
                await self?.userChanged(user?.uid)
            }
        }
    }

    private func userChanged(_ uid: String?) async {
        guard let uid else {
            self.uid = nil
            account = nil
            team = nil
            state = .signedOut
            return
        }
        self.uid = uid
        await loadAccount()
    }

    func loadAccount() async {
        guard let uid else { return }
        do {
            let snapshot = try await db.collection("users").document(uid).getDocument()
            if snapshot.exists {
                account = try snapshot.data(as: UserAccount.self)
                await loadTeam()
                state = .ready
            } else {
                state = .needsAccount
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func loadTeam() async {
        guard let teamID = account?.teamID else {
            team = nil
            return
        }
        team = try? await db.collection("teams").document(teamID).getDocument().data(as: Team.self)
    }

    // MARK: Email

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func createUser(email: String, password: String) async throws {
        try await Auth.auth().createUser(withEmail: email, password: password)
    }

    func sendPasswordReset(to email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    // MARK: Apple

    /// A fresh random value for a Sign in with Apple request. The request carries its hash,
    /// and Firebase checks the original, so a stolen Apple token can't be replayed.
    func prepareAppleNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let nonce = bytes.map { String(format: "%02x", $0) }.joined()
        appleNonce = nonce
        return SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func signInWithApple(idToken: Data?, fullName: PersonNameComponents?) async throws {
        guard let idToken, let token = String(data: idToken, encoding: .utf8), let nonce = appleNonce else {
            throw AccountError.appleSignInFailed
        }
        if let fullName {
            suggestedName = PersonNameComponentsFormatter().string(from: fullName)
        }
        let credential = OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce, fullName: fullName)
        try await Auth.auth().signIn(with: credential)
        appleNonce = nil
    }

    // MARK: Google

    /// Shows Google's sign-in sheet, then signs in to Firebase with the Google account.
    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID, let presenter = Self.topViewController() else {
            throw AccountError.googleSignInFailed
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AccountError.googleSignInFailed
        }
        if let name = result.user.profile?.name {
            suggestedName = name
        }
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
        try await Auth.auth().signIn(with: credential)
    }

    /// The screen Google's sign-in sheet is shown over.
    private static func topViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    func signOut() {
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    // MARK: Account and team

    /// Saves the account type and name. Team setup comes next, or later from Team or Profile.
    func createAccount(name: String, role: AppRole) async throws {
        guard let uid else { throw AccountError.notSignedIn }
        let account = UserAccount(name: name, role: role)
        let batch = db.batch()
        try batch.setData(from: account, forDocument: db.collection("users").document(uid))
        try await batch.commit()
        self.account = account
    }

    /// Makes a team with this coach on it, and a join code for their athletes.
    func createTeam(named name: String) async throws {
        guard let uid, let account else { throw AccountError.notSignedIn }
        let code = try await unusedJoinCode()
        let teamRef = db.collection("teams").document()
        let team = Team(name: name, joinCode: code, createdBy: uid)
        let coach = TeamMember(name: account.name, role: .coach)

        // All at once, so the security rules see the team, the coach, and the code together.
        let batch = db.batch()
        try batch.setData(from: team, forDocument: teamRef)
        try batch.setData(from: coach, forDocument: teamRef.collection("members").document(uid))
        batch.setData(["teamID": teamRef.documentID], forDocument: db.collection("joinCodes").document(code))
        batch.setData(["teamID": teamRef.documentID], forDocument: db.collection("users").document(uid), merge: true)
        try await batch.commit()

        self.account?.teamID = teamRef.documentID
        self.team = team
    }

    /// Joins the team that uses this code, as an athlete.
    func joinTeam(code: String) async throws {
        guard let uid, let account else { throw AccountError.notSignedIn }
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { throw AccountError.noTeamForCode }
        let lookup = try await db.collection("joinCodes").document(code).getDocument()
        guard let teamID = lookup.data()?["teamID"] as? String else { throw AccountError.noTeamForCode }

        let member = TeamMember(name: account.name, role: .athlete, joinCode: code)
        let batch = db.batch()
        try batch.setData(from: member, forDocument: db.collection("teams").document(teamID).collection("members").document(uid))
        batch.setData(["teamID": teamID], forDocument: db.collection("users").document(uid), merge: true)
        try await batch.commit()

        self.account?.teamID = teamID
        await loadTeam()
    }

    /// Done with setup: show the tabs.
    func finishSetup() {
        if account != nil {
            state = .ready
        }
    }

    /// Six letters and numbers, leaving out ones that are easy to mix up (0/O, 1/I/L).
    private func unusedJoinCode() async throws -> String {
        let characters = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        for _ in 0..<5 {
            let code = String((0..<6).map { _ in characters.randomElement()! })
            let existing = try await db.collection("joinCodes").document(code).getDocument()
            if !existing.exists {
                return code
            }
        }
        throw AccountError.noTeamForCode
    }
}
