# NdgBuffsAndDebuffs

An Elder Scrolls Online addon that tracks and displays buffs, debuffs, and reminders in configurable display groups.

## Features

### Display Groups

NdgBuffsAndDebuffs organizes buff and debuff information into six independent display groups, each freely positionable on screen:

- **Reminders** - Alerts for important combat readiness checks:
  - Ultimate is ready to use
  - Potion is off cooldown
  - No food/drink buff is active
- **Long Duration Buffs** - Buffs with duration above a configurable threshold (default: 30 seconds)
- **Short Duration Buffs** - Buffs with duration below the threshold
- **Debuffs** - Active debuffs on your character
- **Target Buffs** - Buffs on your current target
- **Target Debuffs** - Debuffs on your current target

### Per-Group Settings

Each display group can be individually configured:

| Setting | Description |
|---------|-------------|
| **Enable/Disable** | Toggle the group on or off |
| **Display Mode** | Icon only, text only, or both |
| **Size** | Icon and entry size (20-80 px) |
| **Ordering** | Growth direction: top-to-bottom, bottom-to-top, left-to-right, or right-to-left |
| **Text Position** | When using "Both" mode, place text to the left or right of the icon |

### Filtering

- **Reminders**: Individual toggles to disable ultimate, food/drink, or potion reminders
- **All other groups**: A blacklist field where you can enter buff/debuff names to hide (one per line, case-insensitive)

### General Settings

- **Lock/Unlock** - Unlock to drag display groups to any position on screen. Positions are saved across sessions.
- **Short Buff Threshold** - Configure the duration cutoff (in seconds) between short and long buff groups.
- **Slash command**: `/ndgbuffs lock` and `/ndgbuffs unlock`

## Screenshots

*Coming soon*

## Installation

1. Copy the filse into a `NdgBuffsAndDebuffs` folder into your `Elder Scrolls Online/live/AddOns/` directory
2. Ensure the required libraries are installed (see below)
3. Enable the addon in the ESO addon manager

## Dependencies

| Library | Version | Purpose |
|---------|---------|---------|
| [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html) | >= 30 | Settings panel UI |
| [LibMediaProvider-1.0](https://www.esoui.com/downloads/info44-LibMediaProvider.html) | >= 13 | Media asset management |

## Configuration

Open the settings panel via **ESC > Settings > Addons > Ndg Buffs & Debuffs**, or type `/ndgbuffs settings` in chat.

## License

This addon is provided as-is for personal use with The Elder Scrolls Online.
