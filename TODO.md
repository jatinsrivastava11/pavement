# Pavement: end list

Things skipped during the build because they need permission, a real device, or more data.
Everything here keeps the project at $0.

## Needs you (a few minutes each)
1. **Apply the database migrations.** In Supabase → SQL Editor, run in order:
   `supabase/migrations/0001_profiles_and_spots.sql`, `0002_seed_car_tiers.sql`, `0003_friends.sql`,
   `0004_delete_account.sql`.
   This switches on community rankings, friends, and server-side Octane. It hasn't been tested
   against a real database yet, so expect a round of fixes.
2. **Sync spots to Supabase.** After step 1, add the upload of local spots (the code for it
   isn't written yet, on purpose, so it can be tested against the live tables).

## Needs a real iPhone
3. **Fake-photo (screen) detection:** 5 photos of real cars + 5 of a car on a screen; tune the
   thresholds from the numbers on the result screen.
4. **Real car ride:** check the passenger prompt appears, and that red lights don't re-ask.
5. **CarPlay:** check spotting is blocked while connected during a trip.
6. **Camera orientation and depth** on the actual device.

## Recognition (biggest remaining work)
7. **Only 22 of 914 models can be identified.** Scaling up needs many more free photos per
   model (Wikimedia Commons categories, other CC0 sources), then retraining.
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

## Later
11. **Sign in with Apple and push notifications:** when joining the $99/year Apple Developer
    Program (only if publishing).
12. Turn **email confirmation** back on before publishing.
13. **Exact 3D car models** where free, properly licensed ones exist (CC0 / CC-BY).
14. Old commits on GitHub still show the real email (history rewrite was left for later).
15. The full detector model is 59 MB, over GitHub's recommended 50 MB (the hard limit is 100 MB).
    Git LFS is free up to 1 GB if it becomes a problem.
