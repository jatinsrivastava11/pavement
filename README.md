# Pavement

**Spot cars in the wild. Build your collection. Climb the ranks.**

Pavement is an iPhone app for car spotting, played a bit like Pokémon Go. Take a photo of a
street, a parking lot or a car show, and Pavement finds every car in the shot, even ones that are
partly hidden. It adds them to your collection and gives you HP based on how rare they are.

> **Status:** Early development. Nothing is built yet. This README describes what we're building.

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
  - **No:** spotting is blocked. Don't spot and drive.

### HP and rarity
The rarer the car you spot, the more HP you earn.

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
- Send your finds to friends.

### Accounts
- Sign in with **Google** or **email and password**.

---

## Tech stack (planned)

| Part | Technology |
|---|---|
| iOS app | Swift, SwiftUI |
| Camera | AVFoundation |
| Motion / driving detection | Core Motion (`CMMotionActivityManager`), Core Location |
| Car detection | Vision / Core ML, plus a car-identification service (to be chosen) |
| 3D models | RealityKit / SceneKit |
| Backend | To be chosen (Firebase or Supabase) |

---

## Team

The app is built by six AI agents, each with its own area:

| Agent | Area |
|---|---|
| **Backbone** | Backend: accounts, user data, HP, rarity tiers |
| **Scout** | Car recognition and car, engine and 3D model data |
| **Mechanic** | Interactive 3D car and engine models |
| **Lens** | Camera, motion and passenger detection, wiring the camera into the app |
| **Studio** | UI/UX: every screen and interaction |
| **Courier** | Sharing finds with friends |

---

## Getting started

Setup instructions will be added once the Xcode project exists.

Requirements:
- macOS with Xcode 26 or newer
- An iPhone or the iOS simulator (motion detection and the camera need a real iPhone)
