import CoreLocation
import SwiftUI

/// A shareable image of one spot: photo, tier, model and Octane. Portrait 4:5, like an Instagram post.
struct ShareCardView: View {
    let car: CarModel
    let photo: UIImage?
    /// City only, never exact coordinates.
    let city: String?

    static let size = CGSize(width: 1080, height: 1350)

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [car.tier.color.opacity(0.55), Theme.background], startPoint: .top, endPoint: .center)
            VStack(alignment: .leading, spacing: 36) {
                HStack {
                    Text("PAVEMENT").font(.system(size: 44, weight: .black)).tracking(8).foregroundStyle(Theme.accent)
                    Spacer()
                    Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 34, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                }
                ZStack {
                    RoundedRectangle(cornerRadius: 48).fill(Theme.surfaceRaised)
                    if let photo {
                        Image(uiImage: photo).resizable().scaledToFill()
                    } else {
                        Image(systemName: car.body.symbol).font(.system(size: 260)).foregroundStyle(car.tier.color)
                    }
                }
                .frame(height: 640)
                .clipShape(RoundedRectangle(cornerRadius: 48))
                TierBadge(tier: car.tier).scaleEffect(2.4, anchor: .leading).frame(height: 70)
                VStack(alignment: .leading, spacing: 8) {
                    Text(car.make).font(.system(size: 48, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                    Text(car.model).font(.system(size: 104, weight: .heavy)).foregroundStyle(Theme.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.4)
                }
                HStack(spacing: 28) {
                    Label("\(car.tier.octane.formatted()) Octane", systemImage: "fuelpump.fill")
                        .font(.system(size: 44, weight: .bold)).foregroundStyle(Theme.accent)
                    if let city {
                        Label(city, systemImage: "mappin.and.ellipse")
                            .font(.system(size: 40, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(72)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Theme.background)
        .environment(\.colorScheme, .dark)
    }

    /// Renders the card to an image for sharing.
    @MainActor
    func render() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 1
        return renderer.uiImage
    }

    /// Text shown on the card, used to check nothing private (like coordinates) leaks.
    var visibleText: [String] {
        [car.make, car.model, car.tier.displayName, "\(car.tier.octane.formatted()) Octane", city].compactMap { $0 }
    }
}

/// Turns a spot's coordinates into a city name for the share card (Apple's free geocoder).
enum SpotCity {
    static func name(latitude: Double?, longitude: Double?) async -> String? {
        guard let latitude, let longitude else { return nil }
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude))
        return placemarks?.first.flatMap { $0.locality ?? $0.administrativeArea }
    }
}

/// Share button for a car: builds the card, then opens the system share sheet.
struct ShareSpotButton: View {
    let entry: CollectionEntry
    let photos: SpotPhotoStore
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                ShareLink(item: Image(uiImage: image),
                          preview: SharePreview("\(entry.car.displayName) on Pavement", image: Image(uiImage: image))) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            } else {
                ProgressView()
            }
        }
        .task {
            let latest = entry.spots.first
            let city = await SpotCity.name(latitude: latest?.latitude, longitude: latest?.longitude)
            image = ShareCardView(car: entry.car,
                                  photo: entry.spots.compactMap(\.photoFile).first.flatMap(photos.image(named:)),
                                  city: city).render()
        }
    }
}
