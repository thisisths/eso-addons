# NdgAdvancedFiltersExtension

An Elder Scrolls Online addon that adds a **"Not collected"** filter: it shows only what you can still collect or learn.

## What counts as "not collected"

| Kind | Not collected when |
|---|---|
| Set pieces | the piece isn't unlocked in your set collection (same check as SetCollectionMarker) |
| Items that add a collectible (style pages, runeboxes, collectible fragments, ...) | you don't own the collectible yet. A fragment whose combined result you already own counts as collected. |
| Collectibles a vendor sells directly (mounts, pets, ...) | you don't own the collectible yet |
| Recipes (food, drink, furnishing) | this character doesn't know the recipe |
| Motifs and Lore Library books | this character doesn't know the book |
| Scribing grimoires and scripts | this character hasn't unlocked them |

The rules follow the "add to collection" and "use to learn" lines of the game's own item tooltips. Set pieces and collectibles are account-wide. Recipes, motifs, books and scribing count for the character you're playing.

## Features

- **Vendor Buy tab:** a **Not collected** checkbox at the left of the filter tabs. Tick it to see only the vendor's entries you haven't collected yet. It switches off again when you leave the vendor. The list refreshes when you collect or learn something.
- **AdvancedFilters dropdown:** a **Not collected** entry in the dropdown of every category (All, Weapons, Armor, Consumables, ...). AdvancedFilters shows its filter bars in the inventory, the banks and on the vendor's Sell tab, among other places.

## Requirements

- LibFilters-3.0 (r5.0 or newer), already installed if you use AdvancedFilters
- [AdvancedFilters](https://www.esoui.com/downloads/info245-AdvancedFilters.html), optional, for the dropdown entry. The Buy-tab checkbox works without it.

## Limitations

- **Keyboard UI only** for the Buy-tab checkbox.
- **Why a separate checkbox on the Buy tab:** AdvancedFilters (1.6.5.x) has its support for the vendor's Buy tab switched off, so its dropdown can't appear there. The checkbox filters the Buy list through LibFilters-3.0 directly.
- **Containers with random contents** (for example a coffer that gives a random piece of a set) don't count, because what you get isn't known in advance.
