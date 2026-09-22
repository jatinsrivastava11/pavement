# Pavement

**Spot cars in the wild. Build your collection. Climb the ranks.**

Pavement is an iPhone app for car spotting, played a bit like Pokémon Go. Take a photo of a
street, a parking lot or a car show, and Pavement finds every car in the shot, even ones that are
partly hidden. It adds them to your collection and gives you **Octane** (points) based on how rare they are.

> **Status:** Working prototype. Spotting (camera, fake-photo and passenger checks, car detection,
> 22-model identification), collection, rankings, 3D engines, share cards and friends are built.
> See [TODO.md](TODO.md) for what's left.

---

## Features

### Spot
- Take a photo with the in-app camera.
- Pavement finds **every car in the photo**, including ones that are cut off or partly blocked.
- Each car it identifies goes into your **Spots** collection.

### Real cars only
- Photos can only come from the **live in-app camera**. There's no photo library upload, so
  screenshots and saved pictures can't be spotted.
- **Screen detection:** on iPhones with two or more rear cameras, Pavement measures depth. A
  monitor, TV or phone is a flat surface up close, while a real street isn't. On every iPhone it also
  looks for the stripes and moiré a camera picks up from screens. Neither check is perfect; they're
  tuned on real devices.

### Passenger check
- Pavement uses the iPhone's motion sensors to tell when you're in a moving vehicle.
- If you are, it asks: *"Are you a passenger?"*
  - **Yes:** you can keep spotting.
  - **No:** spotting is blocked until the car stops. Don't spot and drive.
- Passengers confirm with a **slide**, not a tap, so it can't be done without looking.
- A "yes" lasts for the trip. Red lights don't end a trip; getting out and walking, or about
  3 minutes stopped, does. The next trip asks again.
- If the phone is connected to **CarPlay** during a trip (almost always the driver's phone),
  spotting is blocked.
- Each spot records where it happened (location "While Using" only).

### Octane and rarity
The rarer the car you spot, the more Octane you earn.

| Tier | World rarity rank | Octane per spot |
|---|---|---|
| **Legendary** | 1–10 | 2,000 |
| **Exotic** | 11–100 | 500 |
| **Rare** | 101–250 | 200 |
| **Niche** | 251–750 | 75 |
| **Occasional** | 751–1,500 | 25 |
| **Common** | 1,501+ | 10 |

The catalog currently lists **914 car models** across the six tiers.

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
- Sign in with **email and password**. **Sign in with Apple** comes later (it needs the paid Apple
  Developer Program).

---

## Tech stack (planned)

| Part | Technology |
|---|---|
| iOS app | Swift, SwiftUI |
| Camera | AVFoundation |
| Motion / driving detection | Core Motion (`CMMotionActivityManager`), Core Location |
| Car detection | YOLOv3-Tiny with tiling (small cars) + full YOLOv3 (big cars at the edge), public domain |
| Car identification | Own Create ML classifier (22 models + "other"); the app names cars itself only when confident and consistent |
| 3D engines | RealityKit, built from code for every engine type (no downloaded models) |
| 3D cars | Kenney Car Kit (CC0) per body style, repainted in the color of the car in your photo |
| Car images | The user's own cropped photo |
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

1. Clone the repo.
2. Copy `Secrets.example.swift` to `Pavement/Config/Secrets.swift` and fill in your Supabase
   project URL and **publishable** key. That file is gitignored.
3. Open `Pavement.xcodeproj` in Xcode (it downloads the Supabase package on first open).
4. Choose an iPhone simulator (or your own iPhone) and press **Run** (⌘R).
5. Run the tests with **⌘U**. (One test contacts Supabase, so it needs internet.)

The full account test creates a real throwaway user, so it only runs when asked:

```sh
TEST_RUNNER_PAVEMENT_E2E=1 xcodebuild test -project Pavement.xcodeproj -scheme Pavement \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

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
  Config/            Secrets.swift (gitignored: Supabase URL and key)
  DesignSystem/      Colors, tier badges, shared styles
  Features/          Auth, Spot (camera, detection, driving), Collection, Rankings,
                     Engine (3D), Sharing, Friends, Profile
  Models/            Shared data types (RarityTier, CarModel, CarCatalog)
  Resources/         cars.json (generated, don't edit by hand)
  Services/          Connections to outside services (Supabase)
PavementTests/       Unit tests
Data/cars/           Car catalog source (.tsv), one row per car model
Data/training/       Sources of the photos the identifier was trained on
supabase/migrations/ Database schema (apply in the Supabase SQL editor)
Tools/build_cars.py  Builds Pavement/Resources/cars.json from Data/cars
```

After editing anything in `Data/cars/`, run `python3 Tools/build_cars.py`.

Requirements:
- macOS with Xcode 26 or newer
- An iPhone or the iOS simulator (motion detection and the camera need a real iPhone)
