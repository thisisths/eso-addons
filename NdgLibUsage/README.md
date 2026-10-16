# NdgLibUsage

An Elder Scrolls Online addon that shows, on every library in the game's **Add-Ons screen**, which addons use it. That makes it easy to find libraries you can disable or uninstall.

## Features

- **`Used by 2/3`** in the State column of each library: 2 active users out of 3 installed addons that depend on it. Shown in orange when no user is active, and as **`Unused`** when no installed addon depends on it at all.
- **Hover** over the text for the list of users, grouped by status:
  - **active** (green): enabled, and actually needed.
  - **enabled, but not needed itself** (yellow): an enabled library that nothing active needs.
  - **disabled** (grey).
- **Click** the text, or the row's expand arrow, to show the same list inside the row.
- **Follows the chain.** If LibA is only used by LibB, and nothing enabled uses LibB, both show as unused.
- **Live updates.** Counts refresh while you tick addons on and off, before you reload.
- Normal addons that other addons depend on (e.g. data addons) get the same display.
- Works alongside AddonSelector.

## Slash commands

| Command | Effect |
|---------|--------|
| `/ndglibusage` | Lists in chat the libraries without an active user. They are split into "not used by any installed addon" and "only used by disabled or unneeded addons". |
| `/ndglibusage <name>` | Shows who uses the addon or library whose name contains `<name>`. |

## Limitation

The game only tells addons about required dependencies (`## DependsOn`). Optional dependencies (`## OptionalDependsOn`) are not visible, so a library that only an addon's optional features use can show as unused. Check that before deleting it.
