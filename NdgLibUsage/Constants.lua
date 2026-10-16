-- First file loaded: creates the addon namespace all other files attach to.
NdgLibUsage = NdgLibUsage or {}
local Addon = NdgLibUsage

Addon.NAME    = 'NdgLibUsage'
Addon.SLASH   = '/ndglibusage'
Addon.VERSION = '0.0.1'   -- keep in sync with ## Version in the manifest

-- How a single user (dependent addon) of a library counts
Addon.STATUS_ACTIVE   = 1   -- enabled and actually needed (a normal addon, or a library something needs)
Addon.STATUS_UNNEEDED = 2   -- enabled, but itself a library nothing enabled needs
Addon.STATUS_DISABLED = 3   -- not enabled

Addon.COLOR_ACTIVE   = ZO_ColorDef:New('3FD13F')   -- green
Addon.COLOR_UNNEEDED = ZO_ColorDef:New('E6C84C')   -- yellow
Addon.COLOR_DISABLED = ZO_ColorDef:New('8C8C8C')   -- grey
Addon.COLOR_UNUSED   = ZO_ColorDef:New('FF9933')   -- orange: library with no active user
Addon.COLOR_HEADER   = ZO_ColorDef:New('C5C29E')   -- ESO's default tooltip header tone

Addon.STR = {
    USED_BY        = 'Used by %d/%d',
    UNUSED         = 'Unused',
    USED_BY_HEADER = 'Used by (%d active / %d installed):',
    NO_USERS       = 'No installed addon depends on this.',
    STATUS_ACTIVE   = 'active',
    STATUS_UNNEEDED = 'enabled, but not needed itself',
    STATUS_DISABLED = 'disabled',
    FOOTNOTE       = 'Only required dependencies (DependsOn) are counted, optional ones are invisible to addons.',
    CLICK_HINT     = 'Click to show the list in the row.',
}
