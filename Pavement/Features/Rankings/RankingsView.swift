import SwiftUI

/// Two rarity scales side by side: how many were built, and how many people have found each car.
struct RankingsView: View {
    let app: AppModel

    enum Scale: String, CaseIterable { case built = "By production", spotted = "By spotting" }
    @State private var scale: Scale = .built
    @State private var search = ""
    @State private var recognizableOnly = false
    @State private var counts: [SpotCount]?
    @State private var countsError: String?

    var body: some View {
        NavigationStack {
            List {
                Picker("Scale", selection: $scale) {
                    ForEach(Scale.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                Toggle(isOn: $recognizableOnly) {
                    Label("Only cars Pavement can recognize (\(CarIdentifier.recognizableIDs.count))", systemImage: "camera.viewfinder")
                        .font(.subheadline)
                }
                .tint(Theme.accent)
                .listRowBackground(Theme.surface)

                switch scale {
                case .built: builtList
                case .spotted: spottedList
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Rankings")
            .searchable(text: $search, prompt: "Search 914 cars")
            .task(id: scale) { if scale == .spotted, counts == nil { await loadCounts() } }
        }
    }

    private func matches(_ car: CarModel) -> Bool {
        (search.isEmpty || car.displayName.localizedCaseInsensitiveContains(search))
            && (!recognizableOnly || CarIdentifier.recognizableIDs.contains(car.id))
    }

    @ViewBuilder private var builtList: some View {
        ForEach(RarityTier.allCases, id: \.self) { tier in
            // Rarest first within each tier (fewest built); cars without a number go last.
            let cars = app.catalog.cars(in: tier).filter(matches)
                .sorted { ($0.approxBuilt ?? .max, $0.displayName) < ($1.approxBuilt ?? .max, $1.displayName) }
            if !cars.isEmpty {
                Section {
                    ForEach(cars) { car in row(car, trailing: car.approxBuilt.map { "~\($0.formatted()) built" }) }
                } header: {
                    HStack { TierBadge(tier: tier); Spacer(); Text("\(cars.count)").foregroundStyle(Theme.textSecondary) }
                }
            }
        }
    }

    @ViewBuilder private var spottedList: some View {
        if let counts {
            let ranked = SpotRanking.rank(catalog: app.catalog, counts: counts).filter { matches($0.car) }
            Section("Hardest to find first") {
                ForEach(Array(ranked.enumerated()), id: \.element.car.id) { index, item in
                    row(item.car, rank: index + 1,
                        trailing: item.spotters == 0 ? "Never spotted" : "\(item.spotters) spotter\(item.spotters == 1 ? "" : "s")")
                }
            }
        } else if let countsError {
            ContentUnavailableView("Community rankings aren't live yet", systemImage: "person.3",
                                   description: Text(countsError))
                .listRowBackground(Color.clear)
        } else {
            ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
        }
    }

    private func row(_ car: CarModel, rank: Int? = nil, trailing: String?) -> some View {
        HStack(spacing: 12) {
            if let rank {
                Text("\(rank)").font(.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary).frame(width: 34, alignment: .trailing)
            }
            Image(systemName: car.tier.symbol).foregroundStyle(car.tier.color)
            VStack(alignment: .leading) {
                Text(car.model).foregroundStyle(Theme.textPrimary)
                Text(car.make).font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if CarIdentifier.recognizableIDs.contains(car.id) {
                Image(systemName: "camera.viewfinder").font(.caption).foregroundStyle(Theme.accent)
                    .accessibilityLabel("Pavement can recognize this car")
            }
            if let trailing { Text(trailing).font(.caption).foregroundStyle(Theme.textSecondary) }
        }
        .listRowBackground(Theme.surface)
    }

    private func loadCounts() async {
        do {
            counts = try await SpotCountService.fetch()
        } catch {
            countsError = "They'll appear once the online spot database is switched on."
        }
    }
}
