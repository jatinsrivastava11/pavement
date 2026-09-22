import SwiftUI

/// After a photo: shows each car found and what Pavement identified it as, then saves the spots.
/// The app names every car itself; users can only keep or skip a car, never change what it is.
struct SpotReviewView: View {
    let app: AppModel
    let photo: UIImage
    let report: ScreenDetector.Report?
    let cars: [SpotPipeline.FoundCar]
    let location: (latitude: Double, longitude: Double)?
    @Environment(\.dismiss) private var dismiss

    /// Identified cars the user wants to keep (all of them by default).
    @State private var skipped: Set<UUID> = []
    @State private var earned: [Spot]?
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    if case .reject(let reason) = report?.decision {
                        blocked(reason)
                    } else if let earned {
                        summary(earned)
                    } else if cars.isEmpty {
                        ContentUnavailableView("No cars found", systemImage: "car.side",
                                               description: Text("Get a bit closer, or make sure the car is in the frame."))
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text("\(cars.count) car\(cars.count == 1 ? "" : "s") found.")
                            .font(.subheadline).foregroundStyle(Theme.textSecondary)
                        ForEach(cars) { car in carRow(car) }
                        Text("Pavement can recognize 22 models so far. More are coming.")
                            .font(.footnote).foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(Theme.spacing)
            }
            .background(Theme.background)
            .navigationTitle(earned == nil ? "Review spot" : "Added!")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                if earned == nil, !cars.isEmpty, report?.decision != .reject(reason: ScreenDetector.screenMessage) {
                    addButton
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func carRow(_ car: SpotPipeline.FoundCar) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(decorative: car.crop, scale: 1)
                .resizable().scaledToFit().frame(maxHeight: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            switch car.verdict {
            case .identified(let id):
                if let model = app.catalog.car(id: id) {
                    HStack {
                        TierBadge(tier: model.tier, compact: true)
                        Text(model.displayName).font(.headline).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        OctaneLabel(amount: model.tier.octane, prefix: "+")
                    }
                    Toggle("Add to collection", isOn: Binding(
                        get: { !skipped.contains(car.id) },
                        set: { keep in if keep { skipped.remove(car.id) } else { skipped.insert(car.id) } }))
                        .tint(Theme.accent).foregroundStyle(Theme.textSecondary)
                }
            case .unidentified:
                Label("Couldn't identify this one", systemImage: "questionmark.circle")
                    .foregroundStyle(Theme.textSecondary)
            case .toy:
                Label("Looks like a toy or model car. Real cars only.", systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
            }
        }
        .card()
    }

    private var keptCars: [(SpotPipeline.FoundCar, CarModel)] {
        cars.compactMap { car in
            guard case .identified(let id) = car.verdict, !skipped.contains(car.id),
                  let model = app.catalog.car(id: id) else { return nil }
            return (car, model)
        }
    }

    private var addButton: some View {
        let count = keptCars.count
        return Button(action: save) {
            Text(count == 0 ? "Nothing to add" : "Add \(count) to collection")
                .font(.headline).frame(maxWidth: .infinity).padding()
                .foregroundStyle(.black)
                .background(count == 0 ? Theme.textSecondary : Theme.accent,
                            in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        }
        .disabled(count == 0)
        .padding(Theme.spacing)
        .background(.ultraThinMaterial)
    }

    private func save() {
        var saved: [Spot] = []
        do {
            for (car, model) in keptCars {
                let file = try? app.photos.save(UIImage(cgImage: car.crop))
                saved.append(try app.spots.add(car: model, latitude: location?.latitude,
                                               longitude: location?.longitude, photoFile: file))
            }
            earned = saved
        } catch {
            saveError = "Couldn't save. Try again."
        }
    }

    private func summary(_ spots: [Spot]) -> some View {
        VStack(spacing: Theme.spacing) {
            OctaneLabel(amount: spots.reduce(0) { $0 + $1.octane }, prefix: "+", font: .largeTitle)
            ForEach(spots) { spot in
                if let car = app.catalog.car(id: spot.carID) {
                    HStack {
                        TierBadge(tier: car.tier, compact: true)
                        Text(car.displayName).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        if spot.octane == 0 {
                            Text("Already spotted here").font(.caption).foregroundStyle(Theme.textSecondary)
                        } else {
                            OctaneLabel(amount: spot.octane, prefix: "+")
                        }
                    }
                    .card()
                }
            }
        }
    }

    private func blocked(_ reason: String) -> some View {
        VStack(spacing: 12) {
            Image(uiImage: photo).resizable().scaledToFit().frame(maxHeight: 240)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Label(reason, systemImage: "xmark.octagon.fill").foregroundStyle(.red).font(.headline)
        }
    }
}
