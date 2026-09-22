import SwiftUI

/// After a photo: shows each car found, lets the user confirm which model it is, and saves the spots.
struct SpotReviewView: View {
    let app: AppModel
    let photo: UIImage
    let report: ScreenDetector.Report?
    let cars: [SpotPipeline.FoundCar]
    let location: (latitude: Double, longitude: Double)?
    @Environment(\.dismiss) private var dismiss

    /// Chosen model for each found car. `nil` means "none of these".
    @State private var choices: [UUID: String] = [:]
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
                        Text("\(cars.count) car\(cars.count == 1 ? "" : "s") found. Pick the right model for each.")
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
            ForEach(car.suggestions, id: \.carID) { suggestion in
                if let model = app.catalog.car(id: suggestion.carID) {
                    choiceButton(selected: choices[car.id] == model.id) {
                        choices[car.id] = model.id
                    } label: {
                        HStack {
                            TierBadge(tier: model.tier, compact: true)
                            Text(model.displayName).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            OctaneLabel(amount: model.tier.octane, prefix: "+")
                        }
                    }
                }
            }
            choiceButton(selected: choices[car.id] == nil) {
                choices[car.id] = nil
            } label: {
                Text("None of these").foregroundStyle(Theme.textSecondary)
            }
        }
        .card()
    }

    private func choiceButton<L: View>(selected: Bool, action: @escaping () -> Void, @ViewBuilder label: () -> L) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Theme.accent : Theme.textSecondary)
                label()
            }
            .padding(10)
            .background(selected ? Theme.surfaceRaised : .clear, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var addButton: some View {
        let count = choices.values.count
        return Button(action: save) {
            Text(count == 0 ? "Pick at least one car" : "Add \(count) to collection")
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
            for car in cars {
                guard let id = choices[car.id], let model = app.catalog.car(id: id) else { continue }
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
            OctaneLabel(amount: spots.reduce(0) { $0 + $1.octane }, prefix: "+").font(.largeTitle.weight(.heavy))
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
