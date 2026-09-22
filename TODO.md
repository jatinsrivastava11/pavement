# Pavement: end list

Things skipped during the build because they need permission, a real device, or more data.
Everything here keeps the project at $0.

## Needs you (a few minutes each)
1. **Apply the database migrations.** In Supabase → SQL Editor, run in order:
   `supabase/migrations/0001_profiles_and_spots.sql`, `0002_seed_car_tiers.sql`, `0003_friends.sql`.
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
8. **Anti-cheat on picks:** a user can choose any of the top-3 suggestions, even a wrong,
   rarer one (e.g. "Ferrari F40" for a Tahoe). Options: only show suggestions above a
   confidence floor, require stronger evidence for Rare+ tiers, or have friends/community verify
   rare spots.
9. **Rear views:** the pilot model is weak on cars seen from behind. It needs rear-view photos.
10. **Detection misses:** heavily overlapping cars in traffic jams, and very large cars cut off
    at the photo edge.

## Later
11. **Sign in with Apple and push notifications:** when joining the $99/year Apple Developer
    Program (only if publishing).
12. Turn **email confirmation** back on before publishing.
13. **Exact 3D car models** where free, properly licensed ones exist (CC0 / CC-BY).
14. Old commits on GitHub still show the real email (history rewrite was left for later).
