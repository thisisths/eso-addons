# NdgUrge

An Elder Scrolls Online addon that shows a big red **"Stop Zerging"** warning while you are too far away from your **group leader** (the crown), by default more than 20 m. It is an extension for [NdgCrown](../NdgCrown/): NdgCrown tracks the leader, NdgUrge warns you, and its settings live in NdgCrown's settings panel.

## Features

- Warning text when you are farther from the group leader than a configurable distance (default 20 m). It uses the 3D distance (height counts), the same measure as NdgCrown's range ring, so a 20 m leader ring turns red exactly when the warning appears.
- Optionally shows the distance in the text: "Stop Zerging (34m)".
- Hidden while you lead the group yourself, while you are dead, and while the leader's position is unknown (not grouped, leader offline or in another zone).
- **Ignore beyond**: no warning when you are much farther away (default 100 m), e.g. after respawning at a keep or when the leader ported.
- **Only in PvP areas** (on by default): only active in Cyrodiil, Imperial City and Battlegrounds.
- Text size, color and screen position are configurable.

## Settings

Open **ESC > Settings > Addons > NdgCrown** and expand the **Stop Zerging (NdgUrge)** submenu at the bottom.

To move the warning: check **Unlock position**, close the menu, press "." for the mouse cursor and drag the text. Then uncheck **Unlock position** (or type `/ndgurge lock`). The position is saved.

NdgCrown's own "Only in PvP areas" setting applies to NdgUrge too. If you use RdK Group Tool, disable its "Follow the Crown" warnings to avoid duplicates.

## Slash commands

| Command | Effect |
|---------|--------|
| `/ndgurge` | Print a status overview: enabled/active, locked/unlocked and the current distance to the leader |
| `/ndgurge unlock` | Show the warning and make it draggable |
| `/ndgurge lock` | Lock the warning in place again |

## Installation

1. Copy the files into a `NdgUrge` folder inside your `Elder Scrolls Online/live/AddOns/` directory
2. Install NdgCrown 1.1.0 or newer and its dependencies (see below)
3. Enable the addon in the ESO addon manager

## Dependencies

| Addon / Library | Version | Purpose |
|---------|---------|---------|
| [NdgCrown](../NdgCrown/) | >= 1.1.0 | Group leader tracking and the settings panel |
| [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html) | >= 30 | Settings panel UI (required by NdgCrown) |

## License

This addon is provided as-is for personal use with The Elder Scrolls Online.
