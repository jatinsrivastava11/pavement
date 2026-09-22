import SwiftUI

/// Friends tab: your username, find friends, requests, friends' rare finds and collections.
struct FriendsView: View {
    let app: AppModel
    private let service = FriendsService()

    enum Load: Equatable { case loading, ready, notLive(String) }
    @State private var load: Load = .loading
    @State private var me: PublicProfile?
    @State private var lists = FriendLists()
    @State private var people: [UUID: PublicProfile] = [:]
    @State private var rareFinds: [FriendsService.RemoteSpot] = []
    @State private var usernameDraft = ""
    @State private var search = ""
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                switch load {
                case .loading:
                    ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
                case .notLive(let reason):
                    ContentUnavailableView("Friends aren't live yet", systemImage: "person.2", description: Text(reason))
                        .listRowBackground(Color.clear)
                case .ready:
                    content
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Friends")
            .refreshable { await reload() }
            .task { await reload() }
            .navigationDestination(for: PublicProfile.self) { FriendCollectionView(friend: $0, app: app) }
        }
    }

    @ViewBuilder private var content: some View {
        if me?.username == nil {
            Section("Pick a username so friends can find you") {
                TextField("username", text: $usernameDraft).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Save username") { Task { await saveUsername() } }
            }
        } else {
            Section("Find a friend") {
                HStack {
                    TextField("Their username", text: $search).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Add") { Task { await addFriend() } }.disabled(search.isEmpty)
                }
                if let message { Text(message).font(.footnote).foregroundStyle(Theme.textSecondary) }
            }
        }

        if !lists.incoming.isEmpty {
            Section("Requests") {
                ForEach(lists.incoming, id: \.self) { id in
                    HStack {
                        Text("@\(people[id]?.username ?? "someone")")
                        Spacer()
                        Button("Accept") { Task { try? await service.accept(from: id); await reload() } }
                            .buttonStyle(.borderedProminent).tint(Theme.accent).foregroundStyle(.black)
                    }
                }
            }
        }

        if !rareFinds.isEmpty {
            Section("Friends' rare finds") {
                ForEach(rareFinds, id: \.self) { spot in
                    if let car = app.catalog.car(id: spot.carID) {
                        HStack {
                            TierBadge(tier: car.tier, compact: true)
                            VStack(alignment: .leading) {
                                Text(car.displayName)
                                Text("@\(people[spot.userID]?.username ?? "friend") · \(spot.spottedAt.formatted(.relative(presentation: .named)))")
                                    .font(.caption).foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                }
            }
        }

        Section("Friends") {
            if lists.friends.isEmpty {
                Text("No friends yet. Add someone by username.").foregroundStyle(Theme.textSecondary)
            }
            ForEach(lists.friends.compactMap { people[$0] }.sorted { $0.octane > $1.octane }) { friend in
                NavigationLink(value: friend) {
                    HStack {
                        Text("@\(friend.username ?? "friend")")
                        Spacer()
                        OctaneLabel(amount: friend.octane)
                    }
                }
            }
            if !lists.outgoing.isEmpty {
                Text("Waiting on \(lists.outgoing.count) request\(lists.outgoing.count == 1 ? "" : "s")")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func reload() async {
        do {
            me = try await service.myProfile()
            lists = try await service.lists()
            let everyone = lists.friends + lists.incoming + lists.outgoing
            people = Dictionary(uniqueKeysWithValues: try await service.profiles(everyone).map { ($0.id, $0) })
            rareFinds = (try? await service.recentRareFinds(friends: lists.friends, catalog: app.catalog)) ?? []
            load = .ready
        } catch {
            load = .notLive("Friends will work once the online database is switched on.")
        }
    }

    private func saveUsername() async {
        switch Username.validate(usernameDraft) {
        case .failure(let e): message = e.message
        case .success(let name):
            do { try await service.setUsername(name); await reload() }
            catch { message = "That username is taken." }
        }
    }

    private func addFriend() async {
        guard case .success(let name) = Username.validate(search) else { message = "No one has that username."; return }
        do {
            guard let user = try await service.find(username: name), user.id != me?.id else { message = "No one has that username."; return }
            try await service.sendRequest(to: user.id)
            message = "Request sent to @\(name)."
            search = ""
            await reload()
        } catch {
            message = "Couldn't send the request. Maybe you already did?"
        }
    }
}

/// A friend's collection, rarest first.
struct FriendCollectionView: View {
    let friend: PublicProfile
    let app: AppModel
    @State private var spots: [FriendsService.RemoteSpot] = []

    var body: some View {
        let grouped = Dictionary(grouping: spots, by: \.carID)
            .compactMap { id, s in app.catalog.car(id: id).map { ($0, s.count) } }
            .sorted { RarityTier.allCases.firstIndex(of: $0.0.tier)! < RarityTier.allCases.firstIndex(of: $1.0.tier)! }
        List(grouped, id: \.0.id) { car, count in
            HStack {
                TierBadge(tier: car.tier, compact: true)
                Text(car.displayName)
                Spacer()
                if count > 1 { Text("×\(count)").foregroundStyle(Theme.textSecondary) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("@\(friend.username ?? "friend")")
        .task { spots = (try? await FriendsService().spots(of: friend.id)) ?? [] }
    }
}
