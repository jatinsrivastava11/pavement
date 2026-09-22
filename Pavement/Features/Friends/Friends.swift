import Foundation
import Supabase

/// A Pavement user as seen by others: username and Octane only.
struct PublicProfile: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let username: String?
    let octane: Int
}

struct FriendshipRow: Codable, Hashable, Sendable {
    let requester: UUID
    let addressee: UUID
    let status: String
}

/// Your friendships, sorted into friends, requests you've received, and requests you've sent.
struct FriendLists: Equatable, Sendable {
    var friends: [UUID] = []
    var incoming: [UUID] = []
    var outgoing: [UUID] = []

    init(rows: [FriendshipRow], me: UUID) {
        for row in rows where row.requester == me || row.addressee == me {
            let other = row.requester == me ? row.addressee : row.requester
            if row.status == "accepted" { friends.append(other) }
            else if row.addressee == me { incoming.append(other) }
            else { outgoing.append(other) }
        }
    }

    init() {}
}

enum Username {
    /// 3–20 characters: lowercase letters, numbers, underscores. Matches the database rule.
    static func validate(_ raw: String) -> Result<String, UsernameError> {
        let name = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard (3...20).contains(name.count) else { return .failure(.length) }
        guard name.allSatisfy({ ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "_" }) else {
            return .failure(.characters)
        }
        return .success(name)
    }

    enum UsernameError: Error, Equatable {
        case length, characters
        var message: String {
            switch self {
            case .length: "Usernames are 3–20 characters."
            case .characters: "Use only letters, numbers and underscores."
            }
        }
    }
}

/// Talks to the friends tables. Needs `supabase/migrations/0001` and `0003` applied.
struct FriendsService: Sendable {
    var client: SupabaseClient = supabase
    /// Who "I" am. Normally the signed-in session; tests can supply an id directly.
    var currentUserID: @Sendable (SupabaseClient) async throws -> UUID = { try await $0.auth.session.user.id }

    func myID() async throws -> UUID { try await currentUserID(client) }

    func myProfile() async throws -> PublicProfile {
        try await client.from("profiles").select("id, username, octane").eq("id", value: myID()).single().execute().value
    }

    func setUsername(_ name: String) async throws {
        try await client.from("profiles").update(["username": name]).eq("id", value: myID()).execute()
    }

    func find(username: String) async throws -> PublicProfile? {
        let rows: [PublicProfile] = try await client.from("profiles").select("id, username, octane")
            .eq("username", value: username).limit(1).execute().value
        return rows.first
    }

    func lists() async throws -> FriendLists {
        let rows: [FriendshipRow] = try await client.from("friendships").select("requester, addressee, status").execute().value
        return FriendLists(rows: rows, me: try await myID())
    }

    func profiles(_ ids: [UUID]) async throws -> [PublicProfile] {
        guard !ids.isEmpty else { return [] }
        return try await client.from("profiles").select("id, username, octane")
            .in("id", values: ids.map(\.uuidString)).execute().value
    }

    func sendRequest(to user: UUID) async throws {
        try await client.from("friendships").insert(["addressee": user.uuidString]).execute()
    }

    func accept(from user: UUID) async throws {
        try await client.from("friendships").update(["status": "accepted"])
            .eq("requester", value: user).eq("addressee", value: myID()).execute()
    }

    struct RemoteSpot: Codable, Hashable, Sendable {
        let carID: String
        let spottedAt: Date
        let userID: UUID
        enum CodingKeys: String, CodingKey { case carID = "car_id", spottedAt = "spotted_at", userID = "user_id" }
    }

    /// A friend's spots, newest first (RLS only returns them if you're friends).
    func spots(of user: UUID) async throws -> [RemoteSpot] {
        try await client.from("spots").select("car_id, spotted_at, user_id").eq("user_id", value: user)
            .order("spotted_at", ascending: false).limit(500).execute().value
    }

    /// Friends' recent spots in the Rare tier or rarer, for in-app alerts.
    func recentRareFinds(friends: [UUID], catalog: CarCatalog, days: Int = 14) async throws -> [RemoteSpot] {
        guard !friends.isEmpty else { return [] }
        let since = Date.now.addingTimeInterval(-Double(days) * 86_400)
        let rows: [RemoteSpot] = try await client.from("spots").select("car_id, spotted_at, user_id")
            .in("user_id", values: friends.map(\.uuidString))
            .gte("spotted_at", value: since.ISO8601Format())
            .order("spotted_at", ascending: false).limit(200).execute().value
        return RareFinds.filter(rows, catalog: catalog)
    }
}

enum RareFinds {
    /// Keeps spots of Rare, Exotic or Legendary cars.
    static func filter(_ spots: [FriendsService.RemoteSpot], catalog: CarCatalog) -> [FriendsService.RemoteSpot] {
        spots.filter { [.rare, .exotic, .legendary].contains(catalog.car(id: $0.carID)?.tier) }
    }
}
