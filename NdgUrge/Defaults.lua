local Addon = NdgUrge

-- Default saved variables. ZO_SavedVars fills in missing keys on load,
-- so adding new defaults later is safe; removing keys leaves stale data behind.
Addon.defaults = {
    enabled = true,
    pvpOnly = true,
    maxDistance = 20,          -- meters (3D); warn beyond this
    ignoreBeyond = 100,        -- meters; farther away = respawned/ported, not zerging. 0 = never ignore
    showDistance = true,       -- "Stop Zerging (34m)"
    fontSize = 54,
    color = { r = 1, g = 0, b = 0 },
    position = { x = 0, y = -200 },  -- offset of the text's center from the screen center
}
