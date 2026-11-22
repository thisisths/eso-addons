-- First file loaded: creates the addon namespace all other files attach to.
NdgAdvancedFiltersExtension = NdgAdvancedFiltersExtension or {}
local Addon = NdgAdvancedFiltersExtension

Addon.NAME    = 'NdgAdvancedFiltersExtension'
Addon.VERSION = '0.1.0'   -- keep in sync with ## Version in the manifest

Addon.STR = {
    NOT_COLLECTED      = 'Not collected',
    BUY_TOGGLE_TOOLTIP = 'Show only what you haven\'t collected or learned yet: set pieces, style pages, '
        .. 'runeboxes and other collectibles, motifs, lore books, recipes and scribing. '
        .. 'Recipes, motifs, lore books and scribing count for this character.',
}
