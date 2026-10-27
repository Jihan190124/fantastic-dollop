# Cinema Tycoon: Theatre Empire

An offline Android cinema-management simulation made with **Godot 4.3 (GDScript)**.
Start with a neglected single-screen cinema (cash ₹10,000) and grow it into a luxury multiplex.
No internet, accounts, web views or paid assets. All graphics are drawn procedurally.

## How to play
- **Drag** to pan, **pinch** (or mouse wheel) to zoom, **tap** a guest, seat, counter, hall or room for details.
- Toolbar: **Build** (halls + decorations), **Upgrades** (seats, projector, audio, lobby, food, staff training),
  **Staff**, **Food** (restock), **Screenings** (movie schedule + ticket price), **Finance**, **Overview** (guest feedback).
- Top bar: cash, reputation, guests inside, today's profit, clock, speed (pause / 1x / 2x / 3x).
- First steps: set a fair ticket price (see "Fair price" in Screenings), buy a popcorn stand and hire a food server,
  hire a cleaner, then upgrade seats/lobby and watch the Overview advice.

## Build the APK
### Option A - GitHub Actions (no local setup)
Push this folder to a GitHub repo and run **Actions > Build Android APK**. The debug APK is uploaded as an artifact
(`.github/workflows/build-apk.yml`). *This workflow was written but not run in the authoring environment.*

### Option B - Godot editor
1. Install Godot 4.3, then **Editor > Manage Export Templates > Download and Install**.
2. Install Android Studio's SDK (platform-tools, build-tools 34.0.0, platform android-34) and JDK 17.
3. **Editor > Editor Settings > Export > Android**: set the SDK path, JDK path and a debug keystore
   (`keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999`).
4. **Project > Export > Android > Export Project** (tick *Export With Debug*) and copy the APK to your phone, or run `adb install CinemaTycoon-debug.apk`.

## Run the automated simulation test
```
godot --headless --path . --import
godot --headless --path . res://tests/sim_test.tscn
```

## Project layout
```
project.godot, export_presets.cfg, icon.svg
scenes/    main_menu, game_world, customer, staff_member
scripts/   game_data (all config), economy_manager, upgrade_manager, inventory_manager, screening_manager,
           save_manager, game_manager, navigation_manager (A* grid), service_counter, customer_ai, staff_member,
           game_world, world_view, live_layer, fx_layer, ui/ (game_ui, main_menu, ui_kit)
tests/     sim_test (headless), shot (screenshot dev tool)
```
Balance values (prices, costs, wages, movies, customer types, upgrade levels) live in `scripts/game_data.gd`.
Saves are JSON in `user://cinema_save.json` (with backup + atomic write).

## Implemented features
- Main menu (New Game, Continue with save detection, Settings, Credits, version), pause menu, settings.
- Cinema map: entrance, ticket counter, lobby, food counters, waiting benches, toilets, staff area, storage, up to 3 halls,
  decorations; A* grid navigation (AStarGrid2D) with walls/furniture collision.
- Customer state machine (spawn -> enter -> decide -> queue -> ticket -> food -> wait -> hall -> seat -> watch -> exit -> despawn),
  5 customer types (budget, student, family, premium, enthusiast) with budgets, party sizes, genre and food preferences.
- Central economy (every transaction has a reason and category; purchases beyond funds are refused), daily wages, electricity,
  maintenance, cleaning supplies, supplies, construction and upgrades, daily summary.
- Screenings: fictional movies, per-hall schedules with 5 slots, per-hall ticket price, seat reservation (no double booking,
  capacity respected), boarding/running/finished lifecycle, no overlaps.
- Upgrades with visible changes (seats, projector/screen size, audio speakers, lobby floors, food counters, food court, decor),
  construction overlays, particles and floating money text; staff training; hall construction timer.
- Food inventory (stock, restock, sold, profit, auto-restock); hired cashiers, servers and cleaners that walk and work.
- Reputation driven by 9 satisfaction factors with in-game advice; reputation drives demand and unlocks movies/upgrades/halls.
- Achievements with cash rewards; autosave at end of day and when the app is paused; safe handling of corrupt saves.
- Touch controls (pan, pinch zoom, tap-select), clamped camera, guest cap setting for performance.

## Known limitations
- No APK was compiled in the authoring environment (no Android SDK access); build with the steps above.
- Not tested on a real Android device. The simulation was tested headless on desktop Godot 4.3, and UI screens were
  rendered under software OpenGL. Touch/pinch handling, performance on phones and the APK install are untested.
- No sound or music. Graphics are simple procedural 2D shapes (angled top-down, not true isometric).
- Loading a save mid-day starts a fresh crowd: guests inside at save time are not stored (tickets already sold stay paid).
- Seats are upgraded globally (all halls share one seat/projector/audio level).
