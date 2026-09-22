import SwiftUI

@main
struct PavementApp: App {
    @State private var auth = AuthModel()
    @State private var app = AppModel()
    /// Shown once per device, after signing in and before the camera asks for permissions.
    @AppStorage("seenOnboarding") private var seenOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                // Development shortcuts: -previewSpot opens the camera screen, -previewTabs opens the tabs with
                // sample spots. Both skip sign-in and never touch real data.
                if CommandLine.arguments.contains("-previewSpot") {
                    SpotView(app: .demo())
                } else if let path = UserDefaults.standard.string(forKey: "previewReviewImage") {
                    DebugReviewPreview(imagePath: path)
                } else if let engine = UserDefaults.standard.string(forKey: "previewEngine").flatMap(EngineType.init(rawValue:)) {
                    EngineViewer(engine: engine)
                } else if let id = UserDefaults.standard.string(forKey: "previewShareCard"),
                          let car = AppModel.demo().catalog.car(id: id) {
                    ShareCardView(car: car, photo: nil, city: "Chicago")
                        .scaleEffect(0.34).frame(width: 368, height: 459)
                } else if CommandLine.arguments.contains("-previewOnboarding") {
                    OnboardingView {}
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
            if seenOnboarding {
                RootTabView(auth: auth, app: app)
            } else {
                OnboardingView { seenOnboarding = true }
            }
        }
    }
}

#if DEBUG
/// Runs the real spot pipeline on an image file from the Mac, for testing the review screen in the
/// simulator (which has no camera). Launch with `-previewReviewImage /path/to/photo.jpg`.
private struct DebugReviewPreview: View {
    let imagePath: String
    @State private var app = AppModel.demo()
    @State private var cars: [SpotPipeline.FoundCar]?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let cars, let image {
                SpotReviewView(app: app, photo: image, report: nil, cars: cars, location: nil)
            } else {
                ProgressView()
            }
        }
        .task {
            guard let ui = UIImage(contentsOfFile: imagePath), let cg = ui.cgImage,
                  let pipeline = try? SpotPipeline(catalog: app.catalog) else { cars = []; return }
            image = ui
            cars = (try? pipeline.run(on: cg)) ?? []
        }
    }
}
#endif
