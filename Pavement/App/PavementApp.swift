import SwiftUI

@main
struct PavementApp: App {
    @State private var auth = AuthModel()
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                // Development shortcuts: -previewSpot opens the camera screen, -previewTabs opens the tabs with
                // sample spots. Both skip sign-in and never touch real data.
                if CommandLine.arguments.contains("-previewSpot") {
                    SpotView()
                } else if CommandLine.arguments.contains("-previewTabs") {
                    RootTabView(auth: auth, app: .demo())
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
            RootTabView(auth: auth, app: app)
        }
    }
}
