# Car catalog source

Each `.tsv` file is a tab-separated list of car models. `Tools/build_cars.py` combines them into
`Pavement/Resources/cars.json`, which ships inside the app.

Columns: `make`, `model`, `tier`, `engine`, `body`, `approx_built`

- **tier**: `legendary`, `exotic`, `rare`, `niche`, `occasional`, `common`. Placement is a judgment
  call from what's widely known about each car (limited edition vs. mass-produced, price class).
  It doesn't need to be exact.
- **engine**: the engine the model is best known for: `i3 i4 i5 i6 v6 v8 v10 v12 v16 w12 w16
  flat4 flat6 rotary electric`.
- **body**: `sedan hatchback wagon coupe convertible suv pickup van supercar`.
- **approx_built**: rough total production, used only to sanity-check tiers. It's approximate and
  can be blank.
