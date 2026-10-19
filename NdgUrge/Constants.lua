-- First file loaded: creates the addon namespace all other files attach to.
NdgUrge = NdgUrge or {}
local Addon = NdgUrge

Addon.NAME       = 'NdgUrge'
Addon.SLASH      = '/ndgurge'
Addon.VERSION    = '0.1.0'   -- keep in sync with ## Version in the manifest
Addon.DB_VERSION = 1         -- bumping this WIPES saved variables

Addon.TEXT = 'Stop Zerging'
