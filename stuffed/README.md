# STUFFED

A twin-stick roguelike in the shape of *The Binding of Isaac*. You are a very
large, very hairy man in a dingy white tank top, and everything trying to kill
you is a toy.

**Play it:** open `index.html` in a browser. One self-contained file — no build
step, no dependencies, no network requests. Everything is drawn procedurally on
a 2D canvas and the audio is synthesised at runtime.

## Controls

| | |
|---|---|
| `WASD` | move |
| arrow keys / mouse | throw fists |
| `SPACE` | stomp — radial shockwave, also smashes cover |
| `P` / `Esc` | pause |
| `M` | mute |
| `R` | restart (on the death screen) |

Click the page once before expecting sound; browsers block audio until the page
has had a real user interaction.

## The run

Four floors — **The Nursery → The Playroom → The Attic → The Furnace**. Each is
a procedurally generated branchy map of rooms with a treasure room and a boss
room. Doors bar themselves until a room is cleared; a door marked with a red
`▲` leads to the boss.

**Enemies**

- **Gingerbread runner** — sprints in bursts, brittle, icing smile far too wide
- **Teddy charger** — telegraphs, then commits to a straight-line charge
- **Rattle turret** — stationary, fires radial bursts, beads visible through the cracked shell
- **Wind-up crawler** — ricochets around the room, homes in weakly up close

**MR. SNUGGLES** — three phases. Loses an arm at 66% and gushes stuffing;
his head tears open at 33% and the stitched mouth comes undone.

Eight items drop from treasure rooms and boss kills (damage, fire rate, speed,
health, range, multishot, shot size, piercing).

## Notes for anyone picking this up

The heaps of cover are **destructible** and that is load-bearing, not cosmetic.
An indestructible heap can wall a stationary enemy off from every bullet you
own, and since doors stay locked until a room is cleared, that ends the run
without you dying. Enemies also only spawn on tiles reachable by flood fill
from the room centre, for the same reason.

Collision resolves by penetration push-out rather than by reverting a blocked
move, so bodies slide along walls and around corners instead of catching on
them. Doorways are one tile wide and the player is 34px across, so there is a
funnel that eases you onto the door's centre line as you approach — without it
you jam against the wall unless you are near-perfectly aligned.

Balance is tuned by eye and has not been played to death. Speed, fire rate and
contact damage are the first dials worth turning; they are all near the top of
the `Player` class.
