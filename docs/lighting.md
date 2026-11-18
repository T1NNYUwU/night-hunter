# Lighting (2026-11-15)

How the mansion and the flashlight are lit, and why. The look it serves is in [theme.md](theme.md):
mostly darkness, a cold blue-grey fill, small warm pools.

## Rules

1. **Every light has a source you can see** (motivated lighting): a lamp, a candle, a fire, a window, the torch.
   A source gives the light its direction, its colour and a reason for its shadows.
2. **A source lights its surroundings about as much as it glows.** A flame that blazes but lights nothing
   reads as a sticker.
3. **Dark is not black.** A low, cold ambient fill keeps floor, wall and doorway apart in the dark
   (value grouping). Shadows are not crushed by the colour grade.
4. **Layers, brightest to dimmest:** key (one lamp or chandelier per room, casts the shadows, pool ends short
   of the corners) → accents (candles, sconces: small warm pools) → fill (ambient).
5. **Warm against cold.** House lights are warm; ambient, moonlight and the torch are cold. You can always
   tell your own light from the house's.
6. **Lights are landmarks.** A lit doorway at the end of a corridor must still show: the haze is thin
   enough for that, and bloom is a tight glow, not fog.
7. **A fixture never shadows its own lamp**, and **a light that should stop at a wall casts shadows.**
8. **Real-time shadows only where they matter** (room keys, windows, the torch); candles have none.

## Requirements in the place (not in code)

- **Lighting → Technology = Future.** Set by hand in Studio's Properties (scripts cannot change it). The older
  modes compute light on a 4-stud grid: a narrow torch beam turns into a dim, square-edged patch, and candle
  pools smear. Everything in this file assumes Future.
- **Workspace → StreamingEnabled = false.** With streaming on, a client first gets only what is within
  64 studs of the character and the rest arrives over the next seconds: the title screen showed a
  half-loaded, unlit house. The house is small (about 16,000 parts); loading it whole is fine.

## What was wrong before

| Symptom | Cause |
|---|---|
| Lamps glowed but rooms stayed black | The lamp's light sat inside its own brass frame / the chandelier's stem, which cast shadows and blocked it |
| Each lamp was a ball of fog | The place template's own Bloom (intensity 1, size 24) ran on top of the game's |
| Candles lit nothing | Range 3–5 studs, one light per flame (203 lights in the house) |
| Everything outside a pool was pure black | Colour-grade contrast 0.22 on top of a near-zero ambient and thick haze |
| Torch: a flat, burnt-out disc with a hard edge | One cone at brightness 8; an unshadowed halo; no bounce |
| Torch: square-edged patches of light | Lighting technology was not Future (block-grid lighting) |
| Lamps dark at random | The flicker killed each lamp for 0.4–2.5 s about every 11 s: one in eight was dark at any moment |
| House half-loaded and unlit at the title screen | StreamingEnabled was on |

## Where the numbers live

| What | Where |
|---|---|
| Every lamp, candle, fire in the house | `LIGHTS` table, `HouseKit.relight` in `src/server/HouseKit.luau`. Applied on every server start and after a rebuild in Edit mode |
| Ambient by day / night | `MOODS` in `src/server/NightCycle.luau` |
| Haze, colour grade, bloom | `applyLighting` in `src/server/HouseBuilder.luau` |
| Torch cones you see (angle, brightness, range) | `CONES` in `src/client/FlashlightBeam.luau` |
| Torch other players see in your hand | `StarterPack.Flashlight.Handle` in the place (Beam, Halo); the fallback in `src/server/PlayerKit.luau` |
| Torch spill, bounce, shaft | `src/client/FlashlightBeam.luau` |

## Current values

- Ceiling lamp 0.8 / range 28, chandelier 0.9, sconce 0.8 / 14, standing candelabra 0.9 / 14 (one light),
  table candelabra 0.7 / 11 (one light), candle 0.5 / 9, fireplace 1.0 / 18. House total: 107 lights.
- Ambient: day (46, 50, 60), night (20, 23, 32). Haze density 0.26. Grade contrast 0.1.
  Bloom 0.25 / size 10 / threshold 1.3.
- Torch: cool white (232, 238, 255). Six cones, 14° to 74°, each ring about half as bright as the one inside
  it (centre 3.5); the four bright ones cast shadows. Spill 0.35 / range 10 at the lens. Bounce: a point light 1.5 studs in front of the lit
  surface, tinted half by its colour, up to 0.45, fading to nothing at 55 studs.

## Sources

- [Until Dawn: creating the atmosphere](https://www.mcvuk.com/development-news/creating-the-atmosphere-of-until-dawn/) (pools of warm light against flat torch beams)
- [The Level Design Book: lighting, darkness](https://book.leveldesignbook.com/process/lighting/darkness)
- [How to make a convincing horror game on a small budget](https://www.cloudspress.com/how-to-make-a-convincing-horror-game-on-a-small-budget/) (ambient baseline, motivated sources, value grouping)
- [Horror Declassified: lighting in horror games](https://bloody-disgusting.com/news/3227846/horror-declassified-a-look-at-lighting-in-horror-games/)
- [Roblox docs: enhancing indoor environments](https://create.roblox.com/docs/tutorials/building/environments/enhancing-indoor-environments)
