import SwiftUI

@main
struct PavementApp: App {
    @State private var auth = AuthModel()

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                // Development shortcut: launch with -previewSpot to open the Spot screen without signing in.
                if CommandLine.arguments.contains("-previewSpot") {
                    SpotView()
                } else {
                    content
                }
                #else
                content
                #endif
            }
            .task { await auth.observeSession() }
        }
    }

    @ViewBuilder private var content: some View {
        switch auth.state {
        case .loading:
            ProgressView()
        case .signedOut:
            LoginView(auth: auth)
        case .signedIn:
            RootTabView(auth: auth)
        }
    }
}
