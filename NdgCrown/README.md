# NdgCrown

An Elder Scrolls Online addon that shows a tall 3D beam and/or a direction arrow next to your reticle for the **group leader** ("the crown") and for units carrying **base-game target marks** — find your raid lead at a glance, and follow marked targets even when they are not in your group.

## Screenshot

![NdgCrown settings panel with per-mark beam and arrow options](docs/crown.png)

The settings panel: the group leader and each of the eight base-game target marks get their own beam/arrow toggles and colors.

## Features

- **Group leader**: a colored beam at the leader's position plus an arrow orbiting your reticle that points toward them (enabled by default, blue). Uses live group positions, so it is always accurate. Inactive while you are the leader yourself.
- **Target marks**: the same beam and arrow for units carrying any of the eight base-game target markers (Blue Square, Gold Star, Green Circle, Orange Triangle, Pink Moons, Purple Oblivion, Red Weapons, White Skull). Each mark has its own toggles and colors — defaults match the marker's color, all marks are disabled by default.
- The arrow scales with distance, can show a distance label, and can hide when the target is closer than a configurable distance.
- Optional **PvP only** mode: only active in Cyrodiil, Imperial City and Battlegrounds.

## How mark tracking works (and its limits)

The game restricts what addons can know about unit positions, so marks are tracked from three sources, best first:

1. **Group members**: live, continuous positions — beam and arrow are always exact.
2. **NPCs under your crosshair**: a position snapshot is taken whenever your reticle touches the marked NPC. The beam/arrow then point at the last known spot and fade out as the position ages (configurable timeout).
3. **Players outside your group**: the game hides their positions completely. The arrow instead follows the mark's **compass pin** — whenever that pin crosses the middle of your compass, the direction is re-captured, and the label shows how old the direction is in seconds. Aim your crosshair at the marked unit once so the addon learns which compass pin belongs to which mark.

This is what makes it possible to, for example, mark another group's leader in a PvP raid and keep an arrow pointing at them.

## Settings

Open the settings panel via **ESC > Settings > Addons > NdgCrown**. General options cover beam size and opacity, arrow sizing and behavior over distance, the distance label, and the mark position timeout; below that, every tracked target has its own submenu (beam on/off + color, arrow on/off + color).

If you enable the leader beam/arrow here, disable the "Follow the Crown" beam and arrow in RdK Group Tool to avoid duplicates.

## Slash commands

| Command | Effect |
|---------|--------|
| `/ndgcrown` | Print a status overview: update loop, tracked targets, position/bearing ages |
| `/ndgcrown probe` | Toggle a diagnostic probe that logs what the position and compass APIs return (also to LibDebugLogger) |

## Installation

1. Copy the files into a `NdgCrown` folder inside your `Elder Scrolls Online/live/AddOns/` directory
2. Ensure the required library is installed (see below)
3. Enable the addon in the ESO addon manager

## Dependencies

| Library | Version | Purpose |
|---------|---------|---------|
| [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html) | >= 30 | Settings panel UI |
| [LibDebugLogger](https://www.esoui.com/downloads/info2275-LibDebugLogger.html) | optional | Debug logging for the probe and troubleshooting |

## License

This addon is provided as-is for personal use with The Elder Scrolls Online.
