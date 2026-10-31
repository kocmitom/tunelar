# Changelog

All notable changes to this project are documented here. Versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.26.2] - 2026-10-31

### Changed
- A spice blow's kills count only if the player who set it off survives it; when the blow also destroys that player, nobody gets the kills.

## [0.26.1] - 2026-10-31

### Fixed
- A spice pocket now always blows when even a single grain is shot away: a bullet or shrapnel dent that reaches the pocket sets it off, not only a shot landing right on a spice cell.

### Changed
- The spice blow radius is 40 px instead of 54, about a quarter smaller.

## [0.26.0] - 2026-10-31

### Added
- Spice pockets: every 15 to 25 s the dune worm leaves a small cinnamon-orange pocket of spice in the sand behind its tail. Pockets stay visible in explored fog, like gold.
- A spice blow: shooting a pocket (bullet, shrapnel or laser), digging into it, or a tank's death crater reaching it blows away all the sand within 54 px, the sight radius of a level 1 radar. Gold, energy, drain veins, rock and bases stay. Every tank in the blow is destroyed whatever its shields, except in its own base, and the player who set it off gets the kills; a digger who sets one off dies in it but still gets the kills.
- Pockets within a blow blow too, so one shot can set off a whole chain along the worm's trail.
- Spice values in the developer panel (F1): the worm's laying interval and the blow radius, pocket size and ring duration.

## [0.25.0] - 2026-10-31

### Added
- Dune worms can be killed: 5 bullet or laser hits on any segment (`HEALTH` in the developer panel) turn its whole body into gold where it died, ready to be dug. A shot that reaches a buried segment where it first touches the dirt counts too; a dormant worm cannot be hit, and shrapnel from exploding tanks never hurts it. No kill is credited.
- A killed worm comes back at once, at a random open spot as far as possible from every tank.

## [0.24.2] - 2026-10-31

### Changed
- Every round has exactly one dune worm, whatever the player count, instead of one per 2 players.

## [0.24.1] - 2026-10-31

### Changed
- Dune worms are half as fast: 12 px/s instead of 24.
- The worm's sand road is thinner: its tail refills a radius of 3 px instead of 5, so a tank tunnel keeps a 1-2 px open strip along each edge instead of being sealed completely.

### Fixed
- A worm with no tunnels anywhere on the map no longer circles on the spot; it keeps going straight ahead.

## [0.24.0] - 2026-10-31

### Added
- Spectator mode: a Spectate toggle in the lobby makes this PC watch instead of play. It takes no player slot and is listed in gray as "name (spectating)"; Start still needs 2 players, and the match never waits for a spectator. The choice is kept when the PC comes back to the lobby, and it is picked in the lobby only, not during a running match.
- A spectating PC shows the whole map at once, without fog, zoomed to fit the window, with every player's kills in their color at the top left and the winner banner at the end of the round.
- Up to 16 PCs can join a lobby, so spectators fit next to 6 players.

## [0.23.0] - 2026-10-31

### Added
- Dune worms: one per 2 players (1 for 2-3 players, up to 3 for 6) wakes up 20 s into a round somewhere far from the bases. A worm swims through the ground without digging it, and its tail fills every tunnel it crosses back with dirt. Touching any part of it destroys a tank, whatever its shields, with no kill credited. It cannot be hurt.
- Worms head for the most dug-out part of the map, weighed against the distance, so busy tunnel networks attract them, and an eaten-up network sends them on to the next one. They never go near a base.
- A worm under the ground shows faintly, and only inside your sight; a low rumble lets you hear it coming through the dirt.
- Worm values in the developer panel (F1).

## [0.22.1] - 2026-10-31

### Changed
- The 1991 PC speaker sound style is gone: the lobby Sound row is just Off and On, and On shows a music note.
- Every sound is a quarter lower in pitch (about 5 semitones), with the same length.

## [0.22.0] - 2026-10-31

### Added
- Sound effects for shots, the laser, digging, shells hitting dirt or rock, ricochets off rock, hits absorbed by a shield, a tank blowing up, bumping into rock, and buying an upgrade or switching a special. All sounds are generated in code, with no sound files.
- A Sound row in the lobby picks this PC's style: Off, 1991 (the original PC speaker beeps, rebuilt from the 1991 game's sound queue: a 5000 Hz click per shot, a 40 Hz buzz per dug frame and the crackling explosion sweeps) or Modern (synthesized cannon thumps, dirt crunches, metal clanks and booms; the default). Each PC chooses its own, and a press plays a sample shot.
- Sounds fade with distance from your own tanks: full volume within 60 px, silent beyond 320 px, so you can hear other tanks digging and shooting nearby, even through the dirt.

### Changed
- Digging costs energy per dug cell instead of per second: every dug cell costs 1/15 energy (`ENERGY_PER_DUG_CELL` in the developer panel), so a faster tank drains its battery faster. That is twice the old cost per cell; a full battery now digs about 1500 cells, enough for one level 1 upgrade.
- Other players' jelly drains 9.375 energy per second (`ENERGY_DRAIN_JELLY`), the same as digging at base speed.

## [0.21.0] - 2026-10-31

### Removed
- Turret mode: the lobby toggle, the turret keys (F/H, numpad 4/6, gamepad right stick) and the turret settings in the developer panel are gone. The barrel always points where the tank drives, and a lone player on a PC drives with both WASD and the arrows again.

## [0.20.0] - 2026-10-31

### Added
- Developer settings: F1 opens a panel, in the lobby or during a match, listing the gameplay values of tanks, bullets, explosions, jelly, laser, rounds, map generation, fog and sonar. Changed values are highlighted and Reset all restores the code defaults. In a LAN match a change is sent to every PC and applied on the same tick, so the game stays in sync; a new match starts with the host's values. Map generation values take effect at the next round and the map size values at the next match. Values are not saved and reset on restart.

## [0.19.3] - 2026-10-31

### Changed
- Turret mode for a lone player on a PC: the arrows drive the tank and A/D turn the turret relative to the tank, so turning the tank turns the turret with it. W/S do nothing in turret mode; two keyboard players on one PC keep WASD + F/H and arrows + numpad 4/6.

## [0.19.2] - 2026-10-31

### Changed
- Turret mode keeps the original driving keys: a lone player drives with WASD and the arrows as before, and everyone turns the turret with F/H, numpad 4/6 or the gamepad right stick.
- The turret turns with the tank: its angle is kept relative to the tank front instead of fixed on the map.
- The turret only turns up to 90 degrees to either side of the front, so it can no longer shoot behind the tank.

## [0.19.1] - 2026-10-31

### Changed
- Driving onto the pad of the special you already have in another player's base no longer switches it off; the last special picked stays active until another pad replaces it.

## [0.19.0] - 2026-10-31

### Added
- Turret mode, a lobby toggle for the whole match: the barrel keeps its direction while the tank drives and turns on its own at half a turn per second, so you can drive one way and shoot another. Shots, the 3-way cannon and the laser fire along the barrel. A lone player on a PC drives with WASD and turns the turret with the left/right arrows; with two keyboard players on one PC, player 1 turns with F/H and player 2 with numpad 4/6. Gamepads turn with the right stick.

## [0.18.2] - 2026-10-31

### Changed
- Digging is 25% faster (15.6 px/s instead of 12.5); driving through dug tunnels keeps its speed. The digging drain rises with it (4.7 instead of 3.75 per second), so a pixel of digging still costs the same energy. Jelly slows and drains the same way.
- Upgrades are half as expensive: level N costs N x 1500 instead of N x 3000, so a full battery of digging pays for two level 1 upgrades.

## [0.18.1] - 2026-10-31

### Changed
- Digging is 50% slower (12.5 px/s instead of 25); driving through dug tunnels keeps its speed. Digging drains half as much energy per second (3.75 instead of 7.5), so a pixel of digging costs the same energy and a full battery still digs enough for a level 1 upgrade. Jelly slows and drains the same way.

## [0.18.0] - 2026-10-31

### Added
- A destroyed tank explodes into 12 shrapnel bullets flying out to all sides. Shrapnel dents dirt, stops at rock and takes a shield from every tank it hits; a kill by shrapnel counts for whoever destroyed the exploding tank, so chain explosions score too.

### Changed
- Shields are a bar instead of segments: it absorbs 5 hits by default and each shield level adds 2 more. Any shield left on the bar absorbs a hit; only a hit on an empty bar destroys the tank.
- Tanks fire 3x faster: a shot every 0.083 s instead of every 0.25 s.
- Shots cost a quarter of the energy: 2 for the cannon (was 8), 1.25 for the laser (was 5) and 1 for the 3-way cannon (was 4).

## [0.17.4] - 2026-10-31

### Changed
- Shields recharge 4x faster in a base: one shield per second instead of one every 4 seconds.

## [0.17.3] - 2026-10-31

### Changed
- The map outline is more irregular and less like a round blob: rock bays reach deeper into the map between the bases, lobes can push out toward the corners, and the edge has rough rock fingers and small islands. The area beside every base stays clear.

## [0.17.2] - 2026-10-31

### Changed
- The 5-way cannon is now a 3-way cannon: it fires forward and straight out to both sides, without the diagonal shots. It keeps its icon and still costs half a shot.

## [0.17.1] - 2026-10-31

### Fixed
- The winner banner shows the winner's lobby name instead of "PLAYER N".

## [0.17.0] - 2026-10-31

### Changed
- The map is a square as wide as the old map of the same size, so a 2-player M map is 640x640 instead of 640x400.
- Bases are placed on an invisible circle around the map center, evenly spaced with a random rotation and a little jitter, so every player is roughly the same distance from their neighbors and has plenty of room toward the edge.
- The map edge is a thick, wavy wall of solid rock that fills the corners, so the playable area looks like a cave instead of a square. The camera always stays centered on your tank, and everything past the map looks like unexplored fog, so you cannot tell where the map ends.
- The money line shows the base pad icons in white instead of the SH / EN / SP / RA names.

## [0.16.6] - 2026-10-31

### Changed
- The laser costs 5 energy per shot instead of 10.

## [0.16.5] - 2026-10-31

### Fixed
- A tank pressed against a house wall from outside can no longer shoot through it: bullets and the laser now start in front of the wall and hit it.

## [0.16.4] - 2026-10-31

### Changed
- Houses are easier to get into: they are 33 px instead of 31, and the doors are 11 px wide instead of 9.

## [0.16.3] - 2026-10-31

### Changed
- Driving through another player's jelly drains energy like digging, not only slows you down.

## [0.16.2] - 2026-10-31

### Changed
- The radar sonar flares up in the color of the player it points at instead of yellow, and the closer that player is the longer the flare: twice the normal length within twice your view radius, shrinking linearly to half length at ten times your view radius and beyond.

## [0.16.1] - 2026-10-31

### Changed
- The radar sonar turns yellow while it flares up on another player.
- A 5-way cannon volley takes at most one shield (or the kill) from each tank: when several of its bullets hit the same tank, only one counts. The next volley can take the next shield.

## [0.16.0] - 2026-10-31

### Added
- Drain blobs: red veins, as common and as big as the energy veins, are scattered across the map away from the houses. They dig and stop bullets like dirt and earn 1 money per cell, but every red cell your tank digs drains 1 energy from the battery.

## [0.15.3] - 2026-10-31

### Changed
- Energy veins are half as common: they cover 0.5% of the map instead of 1%.

## [0.15.2] - 2026-10-31

### Changed
- 5-way cannon bullets no longer ricochet: they stop at the first rock.

## [0.15.1] - 2026-10-31

### Changed
- A 5-way cannon volley costs 4 energy, half of a normal shot.

## [0.15.0] - 2026-10-31

### Changed
- Every player sees the special switch icons on the pads of the other players' bases: a fan for the 5-way cannon, a beam for the laser, a drop for the jelly and a sonar for the radar. Your own base still shows the upgrade icons.
- The laser costs 10 energy per shot instead of 25.
- The radar is a sonar instead of an arrow: a line sweeps around your tank, seen only by you, and flares up (thicker and fully opaque instead of half transparent) whenever it points at another player.
- The jelly trail is drawn in its owner's color, half transparent.

## [0.14.0] - 2026-10-31

### Added
- Specials: the corner pads in other players' bases are free switches. Driving onto one selects its special and replaces the one you had; driving onto the active one again switches it off. Only one special is active at a time, and it is kept after a death but resets every round. The money line shows the active special.
  - Shield pad: 5-way cannon, firing forward, to both sides and halfway between, for the cost of one shot.
  - Battery pad: laser instead of the cannon. The beam is instant, shows as a short red line, does one damage and stops at the first dirt or rock without digging it. It costs 25 energy per shot, with the same fire rate.
  - Speed pad: jelly. Your tank leaves a green trail that lasts 5 seconds; other tanks driving over it move at digging speed, without the energy drain.
  - View pad: radar. A red arrow under the money line points toward the closest player.

## [0.13.2] - 2026-10-31

### Changed
- A destroyed tank reappears in its base immediately instead of spectating for 2 seconds, so a death no longer reveals the whole map. The map is still shown when the match ends.

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
