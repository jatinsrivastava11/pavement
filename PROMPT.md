# Prompt — paste this whole file into the other AI

You are being asked to solve real engineering problems on a working iPhone app. Everything below is
true and measured; none of it is hypothetical. Read all of it before you answer, especially section
5, which lists ideas that have already been built and measured and have failed. Proposing those
again wastes the effort.

**Your task:** work through the problems in section 3, in the priority order given in section 4, and
propose concrete solutions.

**What a good answer looks like**

- **Specific enough to build.** Name the technique, the library or API, and how it fits an iPhone
  app that must run recognition on-device. "Use a better model" is not an answer; "replace the
  trained classifier with a nearest-neighbour search over scenePrint embeddings, which needs roughly
  N examples per car" is.
- **Comes with a way to measure it that can actually fail.** State what you would measure, against
  what baseline, and what result would mean the idea is wrong. Ideas here get tested and several
  good-sounding ones have lost to simpler methods.
- **Respects the constraints in section 1.** Zero cost is absolute — no paid APIs, no cloud
  inference, no paid datasets, no free trials that later bill. Training data must be public domain
  or CC0. Recognition runs on the phone.
- **Says when something cannot be done.** If a problem has no good solution under these constraints,
  say so and explain why, rather than proposing something that will not survive contact with the
  measurements. An honest "this is the ceiling, and here is why" is more useful than an optimistic
  plan.
- **Challenge the framing where you think it is wrong.** The current architecture — a router picking
  between five body-shape experts — was arrived at by measurement, but measurement of a narrow set
  of options. If the whole shape of it is a mistake, say so and say what to do instead. Do not
  assume the existing design is a requirement.

**Where to concentrate.** The single most valuable thing is reducing how many photographs it takes
to learn one car (problem P3). It is the constraint underneath the coverage problem and the memory
problem both. If you solve only one thing, solve that.

Please be concrete about trade-offs, and give a rough ordering of what to try first and why.

---

A complete brief for someone joining cold. Everything here is measured unless it says otherwise.
Read the whole thing before proposing anything: a lot of the obvious ideas have already been tried
and have failed, and the failures are listed at the end with their numbers.

---

## 1. What the app is

**Pavement** is an iPhone app for car spotting — Pokémon Go for cars. You point the camera at cars
in the street, it finds every car in the photo, names the ones it knows, and adds them to your
collection. Rarer cars are worth more points (called **Octane**).

It is a personal project. It is not on the App Store. It is installed directly onto one iPhone and
re-installed every seven days, which is how long a free Apple developer certificate lasts.

### What it does

- Email/password and Google sign-in.
- Camera capture, with a waiting screen while the photo is examined.
- Detects whether you are in a moving car. If you are, it asks whether you are a passenger. It
  blocks spotting if you say you are driving.
- Finds **all** cars in a photo, including partly hidden ones.
- Names the cars it recognises. The user cannot type or choose a name — the app decides or says
  "couldn't identify this one". This is deliberate: the collection is worthless if you can claim
  anything.
- Rejects photos of screens and photos of toy cars.
- Two rarity scales: how many of that car were built, and how often app users find one.
- A collection screen sorted by rarity; tapping a car shows its details, an interactive 3D car and
  an interactive 3D engine that explodes apart to show its parts.

### How it is built

| Part | Technology |
|---|---|
| App | Swift, SwiftUI |
| 3D | RealityKit, physically based materials, a procedurally generated studio environment for reflections |
| Finding cars in a photo | YOLOv3 via Vision (59 MB), with image tiling so small/distant cars are found |
| Naming the car | Create ML image classifiers using Apple's `scenePrint` feature extractor |
| Motion / driving detection | Core Motion activity, Core Location speed, CarPlay via audio session |
| Screen and toy detection | The depth map: plane fitting for screens, real-world size estimation for toys |
| Accounts and sync | Supabase (Postgres) with row-level security; Octane is calculated server-side so the app's number is never trusted |
| Car photos for training | Wikimedia Commons, public domain and CC0 only |
| 3D car models | Kenney's Car Kit (CC0) |

### Hard constraints — these are not negotiable

1. **Zero cost. Not one dollar, ever.** Every service, dataset and asset must be free. Supabase's
   free tier is used deliberately and must never be exceeded in a way that bills.
2. **No personal information anywhere** — no email addresses in code, configs, commits, requests or
   third-party services.
3. **Only free-to-use data.** Photos must be public domain or CC0. Licence must be checked, not
   assumed.
4. **On-device recognition.** No cloud inference — that would cost money and leak photos.
5. If something needs a paid account or a permission that isn't available, skip it and move on.

### The machine it is developed on

Apple M4, 16 GB RAM, macOS 26. This matters: the training memory ceiling below is a property of
this machine, not of the technique.

---

## 2. The state of things, measured

The recogniser is a **router** plus **five experts**. The router looks at a cropped car and picks a
body-shape group (SUV, utility, compact, saloon, sporty). The expert for that group, which knows
only those cars, names it. Each expert is also trained on other groups' cars under a label called
`other`, so an expert handed a car outside its group answers "other" rather than guessing.

A car is only named if the expert is at least 95% confident, the answer is not `other`, and the
answer survives the photo being mirrored and slightly zoomed.

**Measured on 4,837 photos of 128 cars, plus 61 photos of car models the recogniser was never
taught. Test photos are by photographers whose work never appears in training** — one person's
shots of one car are near-duplicates, so splitting them across training and testing would flatter
the score.

| | named right | named wrong | unknown cars wrongly named | precision |
|---|---|---|---|---|
| Previous 75-car recogniser | 219 | 330 | 5 / 61 | 40% |
| **Current, 175 cars** | **575** | **190** | **8 / 61** | **74%** |

Other measured facts:

- **175 cars** are recognisable, out of **914** in the catalogue. 164 of the 174 "common" tier are
  covered.
- The **router is only 62% accurate.** Its most common error by far is calling a hatchback a
  saloon.
- **34,812 free photos** have been downloaded and cropped to the car.
- **Training ceiling: roughly 7,500–8,100 photos** in a single Create ML run on this machine.
  8,101 succeeded; 8,690 failed while other work was running; 11,012 failed outright. It depends on
  what else is using memory, so it is a soft ceiling.
- **Photos per car drive quality, steeply.** 190 photos per car gives 93% precision; 90 photos per
  car gives 78%; 45 gives 81%. Fitting five experts under the memory ceiling forced the larger
  groups down to 125–164 photos per car, and that is part of why precision is 74%.

---

## 3. The problems

### P1 — One name in four is wrong *(the big one)*

74% precision. When the app names a car, it is wrong about a quarter of the time. For a collection
game this is corrosive: a collection full of cars you never saw is worse than a smaller honest one.

The confidence floor is a dial, not a bug — raising it names fewer cars and lies less. Where it
should sit is an unanswered product question. But moving the dial only trades one failure for
another. Something needs to make the underlying recogniser better.

### P2 — 175 cars out of 914

The app can only name 19% of its own catalogue. Everything else comes back "couldn't identify". The
remaining 739 cars are rarer, which means fewer free photos exist for them, which is exactly where
the current approach is weakest.

### P3 — It takes ~150 photos to learn one car

This is the constraint underneath P2. At 150 photos per car, the remaining 739 cars need ~110,000
photographs that in many cases do not exist. Rare and exotic cars — the ones worth the most points —
are the hardest to get photos of. The approach does not degrade gracefully; it just stops.

### P4 — The training memory ceiling caps cars per expert

~8,000 photos per training run on 16 GB. More cars per expert means fewer photos each, which costs
accuracy (see the numbers in section 2). More experts means more routing errors. There is no
setting that avoids both.

### P5 — The router is weak

62% accurate. It works despite this, because a misrouted car gets refused rather than misnamed —
but every misroute is a car that could have been named and wasn't. Tall-vs-low routing was 89%
accurate at 75 cars and fell to 82% at 175. A two-level tree would compound to roughly 66%.

### P6 — The 3D cars look like toys

The app shows a Kenney CC0 model matching the car's body style — not the actual car. They have
realistic materials now (clearcoat paint, transparent glass, metal), but they are still stylised
toy shapes, and they are generic: every saloon shows the same saloon.

The engine models are similarly generic — a car known to have an inline-four shows a generic
inline-four, not its actual engine.

**This has been investigated and there is no easy fix.** See F7–F9 in section 5.

### P7 — Some cars can never be learned

A few catalogue entries have no usable free photographs at all. No training design fixes a car with
no pictures. Related and now fixed, but worth knowing: cars were previously getting **zero photos
silently** because Wikimedia names categories differently from the catalogue (Mazda2 not "Mazda
Mazda2", Renault Scénic with an accent, Ford F-Series Super Duty, Toyota HiLux with a capital L).
A search fallback now recovers these. The Toyota Hilux went from 0 photos to 508.

### P8 — Identification cannot be tested in the simulator

Apple's `scenePrint` feature extractor returns the same answer for every image in the simulator, so
recognition quality can only be checked on a real device or by evaluating models directly on the
Mac. Automated tests therefore cannot cover the thing most likely to break.

### P9 — Device installation is currently blocked

Code signing fails with `errSecInternalComponent`, which is macOS refusing access to the signing key
in the keychain. It needs a human to click "Always Allow" on a dialog. Unresolved as of writing.

### P10 — Repository hygiene

- Twelve early commits contain a real email address in their metadata. Rewriting history would fix
  it but changes every commit hash.
- The YOLOv3 detector is 59 MB, over GitHub's recommended 50 MB per file.
- About 1% of downloaded photo records are duplicates, and a few dozen photos appear under two
  different cars. This does not corrupt the evaluation — test photos are held out by photographer,
  so a duplicate lands on the same side of the split — but it inflates the apparent photo counts.

### P11 — Accessibility items unverified

Several VoiceOver and Dynamic Type issues were found and fixed. Nine remaining warnings were judged
false alarms by screenshotting at the largest accessibility text size, but have not been confirmed
with Accessibility Inspector on a real device.

### P12 — Features never tested by a human

Photographing a toy car; photographing a printed photo of a car; spotting the same car twice and
confirming it awards 0 Octane the second time; CarPlay detection; the friends feature (needs a
second account); account deletion.

### P13 — Unmade product decisions

- Where the confidence floor should sit (more cars named, or fewer wrong names).
- Whether to keep a light "Paper" theme as an option or delete it. The dark "Asphalt" theme is the
  default and preferred.

---

## 4. What would count as a good answer

In rough priority order:

1. **Raise precision above 74%** without losing cars, or show convincingly why it cannot be done
   with on-device, zero-cost, free-data constraints.
2. **Learn a car from far fewer photographs.** This unlocks P2, P3 and P4 at once. The current
   method trains a classifier, which is inherently data-hungry.
3. **Make the 3D cars look like the actual car**, within the constraints, or establish that the
   honest best is a better generic model per body shape.
4. Anything that makes the router's 38% error rate cheaper, or removes the need for a router.

---

## 5. Already tried and failed — do not repeat these

Every one of these was built and measured. The numbers are from the same held-out test sets.

**F1 — A much larger `other` pool.** Theory: more examples of "not a car I know" would make refusal
sharper. Built at equal total training size. Result: 65 cars named right versus the then-current
64 — statistically a tie, no gain. Spending the same budget on more photos per car gave 91.

**F2 — Looking at each car from more angles.** Eight views instead of three, with several voting
rules. Result: roughly a wash. It halved the unknown cars wrongly named (4→2 of 61) but added wrong
names among known cars (8→12). Not worth the time it costs.

**F3 — Routing on four finer body groups** (suv / sedan / small / sports). Router accuracy 74%,
pipeline precision 86% — *worse* than the single recogniser's 90% at the time. Sedan, hatchback and
coupé are genuinely ambiguous in a photograph.

**F4 — Asking every expert and taking the most confident answer.** Tried twice, at two different
scales. Both times the worst option: 80% precision against a single recogniser's 90% at small scale;
60% against routing's 74% at large scale. An expert that has never seen the car still answers
confidently, and those answers outvote the one expert that knows.

**F5 — Fewer photos per car to fit more cars.** 190 → 90 photos per car dropped precision from 93%
to 78%. The recogniser becomes bolder, not better: it names more cars and gets far more of them
wrong.

**F6 — Using the photo's depth map to help identification.** No measurable gain. The iPhone's LiDAR
reaches about five metres and street cars are usually further away. Depth is genuinely useful for
detecting toy cars close up, which is what it is used for.

**F7 — Finding free 3D models of real cars.** They do not exist. Manufacturers treat car CAD as core
intellectual property. Free CC0 car models are concept and generic cars.

**F8 — Building 3D models from patent drawings.** Design patents do cover car bodies and US patent
drawings are free to use, but they are 2D line drawings: flat ink outlines, no surfaces, no
materials, no texture, usually one model year and often only part of the car.

**F9 — Photogrammetry from the downloaded photos.** Apple ships a photogrammetry engine that runs
locally for free, and 128 of 138 cars have 20+ photos from a single photographer. Run on the Lexus
ES with 120 photos: all 120 read, reconstruction then failed outright. The reason is in the
filenames — they are close-ups of lamps, and photos of two different generations of the car.
Photogrammetry needs many views of **one physical object**; a Wikimedia category is many different
cars of the same model in different colours, years and lighting. The raw material is wrong in kind,
not in quantity.

**F10 — Tuning the car detector's confidence cut-off.** No effect; Apple's detector filters
internally before the app sees results.

**F11 — Two different rarity/points balance schemes.** Both landed within noise of each other.

---

## 6. Things worth knowing that are not problems

- **Testing philosophy.** Results are reported honestly including when an idea loses. Several
  sections above exist because a clever idea was measured and beaten by a simpler one. Any proposal
  should come with a way to measure it that can actually fail.
- **Test photos are held out by photographer, never by photo.** One person's shots of one car at one
  event are near-duplicates. Splitting them across training and testing would let the recogniser
  recognise the photograph rather than the car.
- **Server-authoritative points.** Octane is computed by the database, not the app, so a modified
  app cannot award itself points.
- **The app never lets the user name a car.** Deliberate.
- **A quiet zero is a bug, not a fact.** Cars silently came back with no photos because a guessed
  category name was wrong. Anything that can return empty should say so loudly.
