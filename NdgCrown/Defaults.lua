local Addon = NdgCrown

-- Default saved variables. ZO_SavedVars fills in missing keys on load,
-- so adding new defaults later is safe; removing keys leaves stale data behind.
local defaults = {
    general = {
        pvpOnly = false,
        beamWidth = 1.0,           -- meters
        beamHeight = 80,           -- meters
        beamAlpha = 75,            -- percent
        arrowSizeClose = 30,       -- control size at/below min distance
        arrowSizeFar = 75,         -- control size at/above max distance
        arrowMinDistance = 5,      -- meters
        arrowMaxDistance = 100,    -- meters
        arrowRadius = 65,          -- px: how far the arrow orbits from the reticle
        arrowHideBelow = 5,        -- meters; 0 = never hide
        showDistanceLabel = true,
        markTimeout = 60,          -- seconds a mark position stays valid after last seen
    },
    targets = {},
}

for _, target in ipairs(Addon.TARGETS) do
    local isLeader = target.key == 'leader'
    defaults.targets[target.key] = {
        beam = {
            enabled = isLeader,
            color = { r = target.color.r, g = target.color.g, b = target.color.b },
        },
        arrow = {
            enabled = isLeader,
            color = { r = target.color.r, g = target.color.g, b = target.color.b },
        },
    }
end

Addon.defaults = defaults
