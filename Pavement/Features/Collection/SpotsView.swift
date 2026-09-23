import SwiftUI

/// The Spots tab: every car model the user has spotted, rarest first.
struct SpotsView: View {
    let app: AppModel
    @State private var filter: RarityTier?
    @State private var path: [CollectionEntry] = []

    private var entries: [CollectionEntry] {
        let all = app.spots.collection(catalog: app.catalog)
        return filter.map { tier in all.filter { $0.car.tier == tier } } ?? all
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    summary
                    tierFilter
                    if entries.isEmpty {
                        ContentUnavailableView(filter == nil ? "No spots yet" : "None in this tier yet",
                                               systemImage: "car.side",
                                               description: Text("Head to the Spot tab and snap some cars."))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                            ForEach(entries) { entry in
                                NavigationLink(value: entry) { SpotCard(entry: entry, photos: app.photos) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(Theme.spacing)
            }
            .background(Theme.background)
            #if DEBUG
            // `-previewDetail 0` opens straight into the first spot's detail screen, which is
            // otherwise only reachable by tapping and so cannot be screenshotted from a script.
            .onAppear {
                if let n = UserDefaults.standard.object(forKey: "previewDetail") as? Int,
                   path.isEmpty, entries.indices.contains(n) {
                    path = [entries[n]]
                }
            }
            #endif
            .navigationTitle("Spots")
            .toolbarColorScheme(Theme.colorScheme, for: .navigationBar)
            .navigationDestination(for: CollectionEntry.self) { CarDetailView(entry: $0, app: app) }
            #if DEBUG
            .onAppear {
                // Debug: `-openCar <id>` opens that car's page.
                if let id = UserDefaults.standard.string(forKey: "openCar"), path.isEmpty,
                   let entry = app.spots.collection(catalog: app.catalog).first(where: { $0.car.id == id }) {
                    path = [entry]
                }
            }
            #endif
        }
    }

    private var summary: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Octane").font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                OctaneLabel(amount: app.spots.totalOctane, font: .title)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Models").font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                Text("\(app.spots.collection(catalog: app.catalog).count) / \(app.catalog.cars.count)")
                    .font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(Theme.textPrimary)
            }
        }
        .card()
    }

    /// The row of tier filters. It runs the full width of the screen rather than sitting inside the
    /// page's padding: a horizontal scroller that is inset on both sides clips its chips against the
    /// padding, so the last one looks cut in half at the edge and cannot be scrolled clear of it.
    /// The padding is given back as scroll content margins, so the chips still line up with the page.
    private var tierFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", selected: filter == nil, color: Theme.accent) { filter = nil }
                ForEach(RarityTier.allCases, id: \.self) { tier in
                    chip(tier.displayName, selected: filter == tier, color: tier.color) { filter = tier }
                }
            }
        }
        .contentMargins(.horizontal, Theme.spacing, for: .scrollContent)
        .padding(.horizontal, -Theme.spacing)
        .scrollClipDisabled()
    }

    private func chip(_ title: String, selected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .foregroundStyle(selected ? Theme.onAccent : Theme.textPrimary)
                .background(selected ? color : Theme.surfaceRaised, in: Capsule())
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// One car in the Spots grid.
struct SpotCard: View {
    let entry: CollectionEntry
    let photos: SpotPhotoStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CarThumbnail(car: entry.car, photo: entry.spots.compactMap(\.photoFile).first.flatMap(photos.image(named:)))
                .frame(height: 110)
            // These cards are only about 150pt wide, so a long badge ("LEGENDARY") or a long make
            // ("Mercedes-Benz") has to shrink to fit rather than run out past the card's edge.
            TierBadge(tier: entry.car.tier)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(entry.car.make).font(.caption).foregroundStyle(Theme.textSecondary)
                .lineLimit(1).minimumScaleFactor(0.75)
            Text(entry.car.model).font(.headline).foregroundStyle(Theme.textPrimary)
                .lineLimit(2).minimumScaleFactor(0.8).fixedSize(horizontal: false, vertical: true)
            HStack {
                OctaneLabel(amount: entry.totalOctane)
                Spacer()
                if entry.timesSpotted > 1 {
                    Text("×\(entry.timesSpotted)").font(.caption.weight(.bold)).foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
            .stroke(entry.car.tier.color.opacity(entry.car.tier == .common ? 0.15 : 0.6), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }
}

/// The user's photo of the car, or a tier-colored silhouette when there isn't one.
struct CarThumbnail: View {
    let car: CarModel
    let photo: UIImage?

    var body: some View {
        ZStack {
            LinearGradient(colors: [car.tier.color.opacity(0.35), Theme.surfaceRaised], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                Image(systemName: car.body.symbol).font(.system(size: 44)).foregroundStyle(car.tier.color)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension BodyStyle {
    var symbol: String {
        switch self {
        case .suv, .van: "suv.side.fill"
        case .pickup: "truck.pickup.side.fill"
        case .convertible: "car.side.fill"
        default: "car.side.fill"
        }
    }

    var displayName: String {
        switch self {
        case .suv: "SUV"
        default: rawValue.capitalized
        }
    }
}

#if DEBUG
#Preview {
    SpotsView(app: .demo())
}
#endif
