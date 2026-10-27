# Changelog

## 2.0.0 - Cinema Tycoon: Theatre Empire, expansion update

Built solo by **Jihan Bhagat**. This is an update to the existing 1.0 project. Existing saves load and keep their progress.

### Added
- **Projection: 7 tiers.** Basic, HD, Full HD, 4K, Laser, Premium large-format, Ultra-premium immersive.
  Each tier has its own picture quality, frame colour, screen size, electricity and upkeep.
  The large-format screen needs two open halls and premium upholstered seats. The ultra tier needs three halls and double-seat sofas.
- **Seating: 8 types.** Plastic, upholstered, premium upholstered, recliners, double-seat sofas, VIP lounge,
  executive recliners, ultra-luxury private seats. Each has its own look on the floor, comfort, price and upkeep.
  The two top seat types need additional halls.
- **Audio: 5 tiers** (basic, improved stereo, surround, advanced surround, premium immersive), with more speakers at each tier.
- **Marketing campaigns.** Six campaigns: local radio, posters, student week, family package, premium promo, grand opening.
  Each costs money and runs for a fixed number of days. Only one can run at a time. Campaigns raise guest arrivals by a capped amount.
  The student, family and premium campaigns also make guests from that group more likely. Costs appear under "Marketing" in the finance report.
- **Business events.** Each day has a 30% chance of an event, from day 2 on. Events are announced at the start of the day:
  projector breakdown (charged once), word-of-mouth buzz (+25% guests), supply shortage (food restocks cost 50% more), rainy afternoon (-15% guests).
  Events never cause bankruptcy on their own.
- **Technician** staff role. Halves breakdown repairs. Needs a Full HD projector.
- **Marketing & Events screen** in the toolbar, showing today's event, the running campaign and the campaign list.
- **5 more fictional movies:** Monsoon Diaries (documentary), Pocket Dragons (family), Midnight Mandi (horror),
  Letters from Ladakh (drama), The Raj Mahal Heist (action).
- **8 more achievements:** In the Black, Advertiser, Big Take, Guest Favourite, Premium Picture, VIP Treatment, Unfazed.
- **Credits** on the main menu, crediting Jihan Bhagat as the sole designer and developer.

### Changed
- Electricity and maintenance are now per-tier values in `game_data.gd` instead of flat per-level formulas.
  The earlier tiers cost the same as before. Two real differences: 4K projectors now carry 25 upkeep, and the large-format screen costs more to run.
- Projector "large-format" tier now costs 300 electricity per day (was 180) and is the 6th tier, not the 4th.
- VIP lounge seats now give 0.93 comfort (was 1.00); ultra-luxury private seats are the new 1.00 top tier.
- Technician and new staff roles are created from `Data.STAFF`, so new roles need only a data entry.
- Version bumped to 2.0.0 (export version code 2).

### Save compatibility
- Save format is now **version 2**. A version 1 save still loads.
- On first load of a version 1 save, the original file is copied to `cinema_save_v1_archive.json` (once, never overwritten).
- Upgrade levels are remapped to the same tier in the new lists: seats 0,1,2,3 -> 0,1,3,5; projector 0,1,2,3 -> 0,1,3,5; audio 0,1,2 -> 0,2,4.
  Money, reputation, day, achievements, halls, staff and stock all carry over unchanged.
- New fields (campaigns, today's event, event and campaign counters) default safely when missing.

### Fixed
- Removed an always-true assertion in the test suite (`... or true`) that could never fail.

### How it was tested
- Headless simulation test in Godot 4.3: **81 checks pass** (up from 44 in 1.0), including a version 1 save migration test,
  tier prerequisites, the technician repair discount, campaign demand (+20% exact), and event handling.
- 60-day soak test with random purchases, hiring, campaigns, events and save/load cycles: no script errors and no navigation failures.
- Screenshots rendered in a virtual display for the new world, Marketing and Upgrades screens.

### Not done in 2.0 (honest list)
- **Expandable land and buying new plots of ground.** The map is a fixed grid, so this needs a map rework. Not started.
- **Multiplex of 6 to 8 halls.** The game still has 3 halls. Hall geometry is hard-coded. Not started.
- **Separate screen and sound-system tracks.** Screen size is part of the projector tier. Seats are still upgraded for all halls at once.
- **Per-hall seating layouts, row placement tools and hall-level customer preferences.** Not started.
- **Movie marathons and special evening shows.** Not started.
- **Merchandise shop, photo booth, arcade expansion, security desk and maintenance workshop.** Not started.
- **Exterior facades and neon-sign expansion.** Not started.
- **Android APK.** Not built in this environment. The Android SDK isn't available here. Build with the steps in the README, or use the GitHub Actions workflow.
- **Playtime.** The content was not measured against a 120 to 150 hour target. Balance was checked by simulation only and needs playtesting.

## 1.0.0
- First playable release: single-screen cinema growing into a three-hall multiplex, staff, food, decorations, screenings,
  achievements, saves, and a headless simulation test.
