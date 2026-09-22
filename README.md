# Pavement

**Spot cars in the wild. Build your collection. Climb the ranks.**

Pavement is an iPhone app for car spotting, played a bit like Pokémon Go. Take a photo of a
street, a parking lot or a car show, and Pavement finds every car in the shot, even ones that are
partly hidden. It adds them to your collection and gives you **Octane** (points) based on how rare they are.

> **Status:** Early development. The app skeleton (five tabs, rarity tiers) builds and runs. Features are next.

---

## Features

### Spot
- Take a photo with the in-app camera.
- Pavement finds **every car in the photo**, including ones that are cut off or partly blocked.
- Each car it identifies goes into your **Spots** collection.

### Passenger check
- Pavement uses the iPhone's motion sensors to tell when you're in a moving vehicle.
- If you are, it asks: *"Are you a passenger?"*
  - **Yes:** you can keep spotting.
  - **No:** spotting is blocked until the car stops. Don't spot and drive.
- A "yes" only lasts until the car stops, and the question comes back on the next trip.
- If the phone is connected to CarPlay (almost always the driver's phone), spotting is blocked.
- Each spot records where it happened (location "While Using" only).

### Octane and rarity
The rarer the car you spot, the more Octane you earn.

| Tier | What it means |
|---|---|
| **Legendary** | Top 10 rarest cars in the world |
| **Exotic** | Top 100 |
| **Rare** | Top 250 |
| **Niche** | Uncommon, but you'll see them |
| **Occasional** | Seen now and then |
| **Common** | Everyday cars |

### Two rarity rankings
Every car in the world is ranked on two scales, shown side by side:
1. **Production rarity:** how many were ever built.
2. **Spot rarity:** how many Pavement users have actually spotted one.

### Spots page
- Your collection, sorted by rarity.
- Tap a car to see its full details and an **interactive 3D model** of the car and its engine.
  You can rotate it, zoom in, and take the engine apart.

### Share
- **Share cards:** turn any spot into an image card (car, tier, Octane, location) and send it
  through iMessage, Instagram, WhatsApp or anything else on the phone.
- **Friends:** add friends by username, see each other's collections, and get alerts when a friend
  spots something rare.

### Accounts
- Sign in with **Apple**, **Google**, or **email and password**.

---

## Tech stack (planned)

| Part | Technology |
|---|---|
| iOS app | Swift, SwiftUI |
| Camera | AVFoundation |
| Motion / driving detection | Core Motion (`CMMotionActivityManager`), Core Location |
| Car detection | On-device only (Vision / Core ML); identifies make and model, e.g. "Porsche 911" |
| 3D models | RealityKit / SceneKit. Engine: one take-apart model per engine type (I4, V6, V8, V12, flat-6, EV…). Car: exact model only where a free, properly licensed one exists; otherwise a color-matched image |
| Backend | Supabase (free plan): accounts, collections, Octane only |
| Photos | Stay on the user's iPhone and are never uploaded |

---

## Cost

Pavement runs at **$0**. There are no paid services and no payment method on file anywhere. Every
asset is free and properly licensed, and the creators are credited in the app.

---

## Team

The app is built by six AI agents, each with its own area:

| Agent | Area |
|---|---|
| **Backbone** | Backend: accounts, user data, Octane, rarity tiers |
| **Scout** | Car recognition and car, engine and 3D model data |
| **Mechanic** | Interactive 3D car and engine models |
| **Lens** | Camera, motion and passenger detection, wiring the camera into the app |
| **Studio** | UI/UX: every screen and interaction |
| **Courier** | Sharing finds with friends |

---

## Getting started

1. Clone the repo and open `Pavement.xcodeproj` in Xcode.
2. Choose an iPhone simulator (or your own iPhone) and press **Run** (⌘R).
3. Run the tests with **⌘U**.

From the command line:

```sh
xcodebuild test -project Pavement.xcodeproj -scheme Pavement \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### Running on your own iPhone for free
Open the **Pavement** target → *Signing & Capabilities*, choose your free Apple ID as the Team,
plug in your iPhone and press Run. Free installs expire after 7 days; just run it again from
Xcode. Your collection is stored online, so nothing is lost.

## Project layout

```
Pavement/            The iOS app
  App/               App entry point and main tab bar
  Features/          One folder per feature (Spot, Spots, Rankings, Friends, Profile)
  Models/            Shared data types (e.g. RarityTier)
PavementTests/       Unit tests
```

Requirements:
- macOS with Xcode 26 or newer
- An iPhone or the iOS simulator (motion detection and the camera need a real iPhone)
