import SwiftUI

@main
struct PavementApp: App {
    @State private var auth = AuthModel()

    var body: some Scene {
        WindowGroup {
            Group {
                switch auth.state {
                case .loading:
                    ProgressView()
                case .signedOut:
                    LoginView(auth: auth)
                case .signedIn:
                    RootTabView(auth: auth)
                }
            }
            .task { await auth.observeSession() }
        }
    }
}
