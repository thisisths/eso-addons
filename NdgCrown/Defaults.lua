local Addon = NdgCrown

-- Default saved variables. ZO_SavedVars fills in missing keys on load,
-- so adding new defaults later is safe; removing keys leaves stale data behind.
local defaults = {
    general = {
        pvpOnly = false,
        beamWidth = 1.0,           -- meters
        beamHeight = 80,           -- meters
        beamAlpha = 75,            -- percent
        beamThroughTerrain = false,
        ringAlpha = 60,            -- percent
        ringThroughTerrain = true, -- a flat ring otherwise clips into slopes
        arrowSizeClose = 30,       -- control size at/below min distance
        arrowSizeFar = 75,         -- control size at/above max distance
        arrowMinDistance = 5,      -- meters
        arrowMaxDistance = 100,    -- meters
        arrowRadius = 65,          -- px: how far the arrow orbits from the reticle
        arrowHideBelow = 5,        -- meters; 0 = never hide
        showDistanceLabel = true,
    },
    -- range ring around the player
    selfRing = {
        enabled = false,
        radius = 8,                -- meters
        color = { r = 1, g = 1, b = 1 },
    },
    targets = {},
}

for _, target in ipairs(Addon.TARGETS) do
    local isLeader = target.key == 'leader'
    local g = defaults.general
    defaults.targets[target.key] = {
        beam = {
            enabled = isLeader,
            color = { r = target.color.r, g = target.color.g, b = target.color.b },
        },
        arrow = {
            enabled = isLeader,
            color = { r = target.color.r, g = target.color.g, b = target.color.b },
            -- per-target size/distance values; mirror the global Arrow
            -- defaults and are only used while override is on
            override = false,
            sizeClose = g.arrowSizeClose,
            sizeFar = g.arrowSizeFar,
            minDistance = g.arrowMinDistance,
            maxDistance = g.arrowMaxDistance,
            radius = g.arrowRadius,
            hideBelow = g.arrowHideBelow,
        },
        -- range ring; colored by whether the player is inside it
        ring = {
            enabled = false,
            radius = 8,            -- meters
            inColor = { r = 0.2, g = 1, b = 0.2 },
            outColor = { r = 1, g = 0.2, b = 0.2 },
        },
    }
end

Addon.defaults = defaults
