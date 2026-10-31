# Changelog

All notable changes to this project are documented here. Versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.13.1] - 2026-10-31

### Changed
- You see 3 times farther than you explore: in areas you have already explored, enemy tanks, bullets and fresh digging show live up to 3 times the explore radius. Unexplored dirt stays dark, and new terrain is still only explored close to your tank.

## [0.13.0] - 2026-10-31

### Added
- Your own base is a safe zone: bullets stop on your tank there without doing any damage. Tanks in someone else's base can still be hit.

### Changed
- A match is a race to 3 kills instead of last tank standing. A destroyed tank spectates for 2 seconds, then reappears in its base with a full battery and shields, keeping its money and upgrades. The first player to 3 kills wins.
- The HUD shows your kills out of 3 instead of your wins.

## [0.12.1] - 2026-10-31

### Changed
- Energy nuggets are smaller, the same size as gold nuggets.
- A base refills an empty battery in the same time whatever its size, so energy upgrades no longer slow down recharging.
- Tanks can no longer shoot from inside a base.

## [0.12.0] - 2026-10-31

### Changed
- Fog of war works like Age of Empires 2: explored areas outside your view show the map as you last saw it, dimmed, but hide tanks and bullets. Only the circle around your tank shows enemies and fresh digging live.

## [0.11.0] - 2026-10-31

### Added
- Map size in the lobby: S, M, L or XL, picked by anyone and shown on every PC. M is the previous size; S has half its area, L twice and XL three times. The map still grows with the player count.
- Energy nuggets: blue veins of varying size are scattered across the map, away from the houses. They dig and stop bullets like dirt, and every blue cell your tank digs recharges 1 energy, so a bigger vein recharges more.

### Changed
- The fog of war is dark slate blue instead of black, so it no longer looks like dug tunnels.
- The button under the end-of-round banner is now "Lobby" and sends every PC back to the lobby instead of starting another round.

## [0.10.0] - 2026-10-31

### Added
- Gold nuggets: small golden veins are scattered across the map, away from the houses. They dig and stop bullets like dirt, but every gold cell your tank digs earns 10 instead of 1.

## [0.9.1] - 2026-10-31

### Changed
- At the start of a round, the fog of war is cleared in a circle twice as wide around your base.

## [0.9.0] - 2026-10-31

### Changed
- The end of a round no longer starts the next one after 3 seconds. Everyone's fog drops and their movement controls pan the camera around the map, and the game waits until anyone, on any PC, clicks the Restart button under the banner. The next round then starts on every PC at the same tick.
- The bottom-left button that sends everyone back to the lobby is now labeled "Lobby".

## [0.8.0] - 2026-10-31

### Added
- Money: every dirt cell your tank digs earns 1, shown under the shields together with your upgrade levels. Money and upgrades reset every round.
- Powerups: each corner of your own house has an upgrade pad, marked with an icon. Driving onto a pad buys its next level if you can afford it, one level per visit. Level N costs N x 3000, so one full battery of digging pays for level 1. Max level 5.
  - Top-left: +1 shield per level.
  - Top-right: +50% battery per level.
  - Bottom-left: +25% speed per level.
  - Bottom-right: +25% view radius per level.
- Energy and shields now recharge in any house, not just your own.

### Changed
- Tanks start with 1 shield instead of 2; one shield refills in 4 seconds in a house.
- Houses are bigger (31 px instead of 21), so the corner pads are out of the way of tanks just driving through.

## [0.7.0] - 2026-10-31

### Added
- Spectating after death: when your tank is destroyed, your view drops the fog of war and your movement controls pan the camera around the map to watch the other players, also during the end-of-round banner. The view returns to your tank, fogged again, when the next round starts.

## [0.6.0] - 2026-10-31

### Added
- Several players per PC in LAN matches: "Add player" and "Remove player" in the lobby add this PC's next player (named "name 2", "name 3", ...), up to 6 players in total and one per available device. The lobby shows each local player's controls.
- A PC with 2 or more players shows split-screen for its own players, while still playing together with the other PCs over the LAN.
- Two players on one PC can start a match without any other PC.

### Changed
- A lone player on a PC still drives their tank with any keyboard or gamepad; with 2 or more, player 1 uses WASD + Space, player 2 arrows + Enter, then gamepads.
- If a PC leaves mid-match, all of its players' tanks stay idle.

## [0.5.2] - 2026-10-31

### Fixed
- LAN update no longer crashes the game on start: the official export templates refuse `--main-pack`, so the downloaded pack now replaces `Tunneler.pck` next to the exe and the game restarts normally. Packs downloaded into the user data folder are ignored.

## [0.5.1] - 2026-10-31

### Changed
- Tanks have 2 shields instead of 3 (the third hit destroys the tank). An empty set still refills in 4 seconds in the base.

## [0.5.0] - 2026-10-31

### Added
- Fog of war: each player's view is dark except where their own tank has been. A tank reveals a circle 4 tank sizes across (radius 14 px); explored areas stay revealed for the rest of the round, including enemies and bullets in them. The fog resets with every new map.

## [0.4.1] - 2026-10-31

### Changed
- Shields recharge in the player's own base at the same pace as energy (an empty set refills in 4 seconds). A recharging segment fills in gradually, and only a full segment absorbs a hit.

## [0.4.0] - 2026-10-31

### Added
- Restart button (bottom-left of the game screen): anyone can press it to send every PC back to the lobby. If the host is gone, it takes only this PC back, where it finds or hosts a new lobby.
- Shields: every tank has 3 shields, shown as blue segments under the energy bar. Each hit removes one, and a hit with no shields left destroys the tank. Shields refill every round.

### Changed
- Players who leave during a match are removed from the lobby list.

## [0.3.0] - 2026-10-31

### Added
- LAN lobby as the main menu: the first PC to open the game hosts the lobby (UDP discovery on port 47801, ENet on 47802) and the others join it automatically; anyone in the lobby can press Start once 2 or more PCs are in.
- Lockstep LAN matches: one player per PC, every PC sends its input for 2 ticks ahead and runs the same simulation once all inputs for a tick have arrived; a disconnected player's tank stays idle.
- `InputRouter.sample_all()` lets every keyboard and gamepad on a PC drive its single LAN tank.

### Changed
- Round maps are generated from a per-match seed (`GameManager.setup(player_count, match_seed, local_slots)`), so every PC builds the same maps.
- `ViewportManager.build()` takes the local slots, so a LAN PC shows only its own player full screen; local split-screen still shows every player.

## [0.2.0] - 2026-10-31

### Added
- Fixed 30 Hz simulation ticks with a tick counter (`GameManager.tick`); each tick always advances by `TICK_DT`, independent of frame rate.
- `GameManager.simulate(inputs)` runs one tick from per-player input dictionaries (`move`, `fire`), ready to be fed from the network.
- `InputRouter.sample()` reads input once per tick and latches fire taps that happen between ticks.
- Game version shown in the window title and in the bottom-right corner.
- LAN auto-update: exported games announce their version on the LAN (UDP/TCP port 47800); an older game shows an "Update to vX.Y.Z" button that downloads the newer pack from that PC and restarts with it.
- Windows Desktop export preset (exe with a separate `.pck`, tests excluded).

### Changed
- Physics runs at 30 ticks per second with physics interpolation enabled for smooth rendering.
- The round-end freeze is measured in ticks (`ROUND_FREEZE_TICKS`).
- Cameras follow their tank at the end of each tick instead of in a separate physics callback.

### Removed
- Radar compass and radar action (Q / Right Shift / gamepad B).

## [0.1.0] - 2026-10-30

First playable version of the 6-player local split-screen Tunneler remake (Godot 4.7).

### Added
- Destructible terrain stored as a byte grid (air, dirt, bedrock, base) and rendered through a single `Image`/`ImageTexture`.
- Seeded map generation: bedrock border, rare solid rock formations (about 5% coverage, no stray specks) and walled home bases with doors.
- Map size scales with the player count (640x400 for 2 players up to about 1107x692 for 6).
- Input router: keyboard A (WASD, Space, Q), keyboard B (arrows, Enter/Numpad 0, Right Shift) and up to 6 gamepads, all routed per player slot.
- Tanks with 8-direction movement, digging at reduced speed through tunnels one pixel wider than the tank, and blocking by bedrock.
- Energy: digging, firing and radar cost energy; moving through dug tunnels is free; slow passive regeneration everywhere; fast recharge in the player's own base; digging slows down when the battery is low.
- 3x2 split-screen with one shared `World2D` and a camera per viewport.
- Combat: bullets that dent dirt, ricochet off bedrock up to 2 times and destroy tanks, leaving an explosion crater.
- Per-player HUD with energy bar, radar compass, win counter and round banner.
- Round loop: last tank standing wins, 3 second freeze, new map, respawn with full energy.
- Bases drawn in their owner's color.
- Headless test harness (`godot --headless --path . -s tests/test_runner.gd`).
