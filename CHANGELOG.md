# Changelog

All notable changes to this project are documented here. Versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Fixed 30 Hz simulation ticks with a tick counter (`GameManager.tick`); each tick always advances by `TICK_DT`, independent of frame rate.
- `GameManager.simulate(inputs)` runs one tick from per-player input dictionaries (`move`, `fire`, `radar`), ready to be fed from the network.
- `InputRouter.sample()` reads input once per tick and latches fire/radar taps that happen between ticks.
- Game version shown in the window title and in the bottom-right corner.
- LAN auto-update: exported games announce their version on the LAN (UDP/TCP port 47800); an older game shows an "Update to vX.Y.Z" button that downloads the newer pack from that PC and restarts with it.
- Windows Desktop export preset (exe with a separate `.pck`, tests excluded).

### Changed
- Physics runs at 30 ticks per second with physics interpolation enabled for smooth rendering.
- The round-end freeze is measured in ticks (`ROUND_FREEZE_TICKS`).
- Cameras follow their tank at the end of each tick instead of in a separate physics callback.

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
