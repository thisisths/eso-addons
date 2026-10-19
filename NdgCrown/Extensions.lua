local Addon = NdgCrown

-- Public API for extension addons (e.g. NdgUrge). An extension lists
-- NdgCrown in its DependsOn and registers itself during its own
-- EVENT_ADD_ON_LOADED:
--
--   NdgCrown.RegisterExtension({
--       name      = 'NdgFoo',          -- unique
--       title     = 'Foo (NdgFoo)',    -- submenu label in NdgCrown's settings
--       IsActive  = function() ... end, -- true = needs the update loop
--       OnUpdate  = function(nowMs) ... end,  -- every frame while active
--       OnStop    = function() ... end, -- loop stopped or extension inactive: hide everything
--       GetOptions = function() return { --[[ LAM controls ]] } end,  -- optional
--   })
--
-- Nothing starts on registration; the next EVENT_PLAYER_ACTIVATED (which
-- follows every addon load) evaluates IsActive(). Call
-- NdgCrown.RefreshActivation() whenever the answer of IsActive() may have
-- changed (e.g. a setting was toggled). While any extension is active, the
-- group leader is tracked even if all leader visuals are disabled.
Addon.extensions = {}

function Addon.RegisterExtension(extension)
    table.insert(Addon.extensions, extension)
end

function Addon.IsInPvPArea()
    return IsPlayerInAvAWorld() or IsActiveWorldBattleground()
end

-- 3D distance from the player to the group leader in meters (height counts,
-- the same measure as the range ring), or nil while the leader's position
-- isn't live: not grouped, being the leader yourself, leader offline or in
-- another zone.
function Addon.GetLeaderDistance(nowMs)
    local Tracker = Addon.Tracker
    if not Tracker.IsPositionKnown('leader', nowMs) then return nil end
    local entry = Tracker.entries['leader']
    local zoneId, playerX, playerY, playerZ = GetUnitWorldPosition('player')
    if entry.zoneId ~= zoneId then return nil end
    local deltaX = playerX - entry.wx
    local deltaY = playerY - entry.wy
    local deltaZ = playerZ - entry.wz
    return math.sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ) / 100
end
