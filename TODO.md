# Pavement: end list

Things skipped during the build because they need permission, a real device, or more data.
Everything here keeps the project at $0.

## Needs you (a few minutes each)
1. ~~Apply the database migrations~~ **Done and verified on the live project (2026-09-22):**
   914 car tiers loaded, server-side Octane correct (Civic 10, McLaren F1 2,000), community spot
   counts working, signed-out access blocked, account deletion removes profile + spots + login.
2. **Check spot syncing live.** The upload queue is built and tested with a stand-in server
   (offline, retries, no duplicates). After step 1, confirm spots appear in the `spots` table.

## Needs a real iPhone
3. **Fake-photo (screen) detection:** 5 photos of real cars + 5 of a car on a screen; tune the
   thresholds from the numbers on the result screen.
4. **Real car ride:** check the passenger prompt appears, and that red lights don't re-ask.
5. **CarPlay:** check spotting is blocked while connected during a trip.
6. **Camera orientation and depth** on the actual device.

## Recognition (biggest remaining work)
7. **Identification is at a plateau, not a data shortage.** Tried adding ~5,000 more photos
   (median 100 -> 260 per model). Deepening only the known models made recognition better but
   broke refusal of unknown cars (1/61 fooled -> 8/61), because the "other car" category was
   left behind. Rebalancing (two variants tested at a fixed budget) got back to parity but no
   further: differences were within noise. **Create ML on this Mac fails above ~6,500 training
   photos** ("failed to create CVPixelBufferPool"), so more photos per model must come out of
   "other". Real gains need a bigger training budget or a car-specific model, not more scraping.
   Only 44 of 914 models can be identified, and it names ~15% of known cars (it leaves most
   unnamed rather than risk a wrong name; 89% right when it does name one). Commons *categories*
   work far better than search (hundreds of photos per model), so the next batch of models can be
   added the same way. The Toyota Hilux category is named differently on Commons and came back
   empty.
8. ~~Anti-cheat on picks~~ **Done:** users can no longer choose the model. The app names it
   itself, only at 95%+ confidence, and has an "other car" category so unknown models are
   refused (wrongly named unknown cars went from 66% to 20%).
8b. **Identification can't be tested in the simulator**, which returns the same answer for every
   image. Use `Tools/check_identifier.swift` on the Mac, and test on a real iPhone.
8c. **Printed photos on single-camera iPhones and toy cars without depth** aren't caught yet.
   Toy cars are caught on iPhones with depth (size check); printed photos by the flatness check.
9. **Rear views:** the pilot model is weak on cars seen from behind. A VW Beetle from behind is
   named "Bugatti Veyron" at 99.9%: a +500 Octane mistake. It needs rear-view training photos,
   and maybe extra proof (a second photo) before awarding Legendary/Exotic points.
10. **Detection misses:** heavily overlapping cars in traffic jams (a jam with ~30 cars yields
    ~15 boxes). Large cars cut off at the photo edge are fixed. Lowering our confidence cut-off
    changes nothing (0.30 / 0.25 / 0.20 / 0.15 give identical results) because Apple's packaged
    YOLO models apply their own cut-off internally before Vision sees the boxes. Going further
    needs a model rebuilt with coremltools, or a different detector.

## Accessibility
16. The accessibility audit reports 8 contrast issues it can't attach to an element (6 in
    Rankings, 2 in Profile). Trace them with Xcode's Accessibility Inspector on a device. The UI
    test fails if the count grows.

## Later
11. **Sign in with Apple and push notifications:** when joining the $99/year Apple Developer
    Program (only if publishing).
12. Turn **email confirmation** back on before publishing.
13. ~~3D car models~~ **Done** per body style (Kenney, CC0), painted in the photo's color. Exact
    per-model 3D cars remain a "later" idea.
14. Old commits on GitHub still show the real email (history rewrite was left for later).
15. The full detector model is 59 MB, over GitHub's recommended 50 MB (the hard limit is 100 MB).
    Git LFS is free up to 1 GB if it becomes a problem.
