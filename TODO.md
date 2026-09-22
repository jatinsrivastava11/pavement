# Pavement: end list

Things skipped during the build because they need permission, a real device, or more data.
Everything here keeps the project at $0.

## Needs you (a few minutes each)
1. **Apply the database migrations.** In Supabase → SQL Editor, run in order:
   `supabase/migrations/0001_profiles_and_spots.sql`, `0002_seed_car_tiers.sql`, `0003_friends.sql`,
   `0004_delete_account.sql`.
   They've been tested locally against real Postgres 17 with a Supabase stand-in
   (`Tools/test_database.sh`): server-side Octane, anti-farming, RLS privacy, friends and account
   deletion all pass. Supabase's real `auth` setup could still differ slightly, so check the app
   after applying.
   This switches on community rankings, friends, and server-side Octane. It hasn't been tested
   against a real database yet, so expect a round of fixes.
2. **Check spot syncing live.** The upload queue is built and tested with a stand-in server
   (offline, retries, no duplicates). After step 1, confirm spots appear in the `spots` table.

## Needs a real iPhone
3. **Fake-photo (screen) detection:** 5 photos of real cars + 5 of a car on a screen; tune the
   thresholds from the numbers on the result screen.
4. **Real car ride:** check the passenger prompt appears, and that red lights don't re-ask.
5. **CarPlay:** check spotting is blocked while connected during a trip.
6. **Camera orientation and depth** on the actual device.

## Recognition (biggest remaining work)
7. **Only 41 of 914 models can be identified**, and it names only ~14% of known cars (it leaves
   most unnamed rather than risk a wrong name; 91% right when it does name one). Scaling up needs
   more photos per model. Commons search is thin for some (Toyota Camry, Corolla, RAV4, Hilux),
   so try Commons *categories* instead of search.
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
10. **Detection misses:** heavily overlapping cars in traffic jams, and very large cars cut off
    at the photo edge.

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
