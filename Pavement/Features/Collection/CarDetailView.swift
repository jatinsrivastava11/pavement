import SwiftUI

/// Everything about one car model the user has spotted.
struct CarDetailView: View {
    let entry: CollectionEntry
    let app: AppModel
    @State private var showingEngine = false

    private var car: CarModel { entry.car }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                CarThumbnail(car: car, photo: entry.spots.compactMap(\.photoFile).first.flatMap(app.photos.image(named:)))
                    .frame(height: 220)

                VStack(alignment: .leading, spacing: 6) {
                    TierBadge(tier: car.tier)
                    Text(car.make).font(.title3).foregroundStyle(Theme.textSecondary)
                    Text(car.model).font(.largeTitle.weight(.heavy)).foregroundStyle(Theme.textPrimary)
                }

                HStack(spacing: 12) {
                    stat("Per spot", value: "\(car.tier.octane.formatted())", icon: "fuelpump.fill", tint: Theme.accent)
                    stat("Spotted", value: "×\(entry.timesSpotted)", icon: "camera.fill", tint: Theme.textPrimary)
                    stat("Earned", value: entry.totalOctane.formatted(), icon: "sum", tint: Theme.accent)
                }

                VStack(spacing: 0) {
                    row("Engine", car.engine.displayName)
                    Divider().overlay(Theme.hairline)
                    row("Body", car.body.displayName)
                    if let built = car.approxBuilt {
                        Divider().overlay(Theme.hairline)
                        row("Built", "about \(built.formatted())")
                    }
                    Divider().overlay(Theme.hairline)
                    row("First spotted", (entry.spots.last?.spottedAt ?? .now).formatted(date: .abbreviated, time: .omitted))
                }
                .card()

                Button {
                    showingEngine = true
                } label: {
                    Label("Explore the \(car.engine.displayName) engine in 3D", systemImage: "gearshape.2.fill")
                        .font(.headline).frame(maxWidth: .infinity).padding()
                        .foregroundStyle(.black)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
                }
            }
            .padding(Theme.spacing)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ShareSpotButton(entry: entry, photos: app.photos) }
        .sheet(isPresented: $showingEngine) { EngineSheet(engine: car.engine) }
    }

    private func stat(_ title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(Theme.textSecondary)
            Text(value).font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).foregroundStyle(Theme.textPrimary).fontWeight(.semibold)
        }
        .padding(.vertical, 10)
    }
}

/// The 3D engine for a car, shown as a sheet.
struct EngineSheet: View {
    let engine: EngineType
    var body: some View {
        EngineViewer(engine: engine)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
    }
}
