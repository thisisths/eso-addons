local Addon = NdgCrown

-- Tracks world positions of the group leader and of units carrying a
-- base-game target marker.
--
-- Position sources, best first:
--   * group unit tags (group1..group12): continuous, always accurate
--   * 'reticleover': snapshot whenever the crosshair is over a marked unit.
--     The game exposes no other way to locate marked units outside the group,
--     so those positions go stale once the unit leaves the crosshair. Entries
--     expire after general.markTimeout seconds.
--
-- Entry layout (Tracker.entries[targetKey]):
--   { zoneId, wx, wy, wz (cm world coords), lastSeenMs, name }
--
-- Additionally, marked units are matched against the compass "center-overed
-- pin" API: whenever a pin whose description matches a known marked unit
-- crosses the compass center, the current camera heading is recorded as a
-- bearing (Tracker.bearings[targetKey] = { heading, atMs }). This works at
-- any range and also for players outside the group, whose positions the game
-- hides from addons - it just yields a direction, not a position.
Addon.Tracker = {}
local Tracker = Addon.Tracker

Tracker.entries = {}
Tracker.bearings = {}
Tracker.markNames = {}   -- targetKey -> { charName, displayName }; learned via crosshair

local function IsTargetWanted(targetKey)
    local settings = Addon.db.targets[targetKey]
    return settings.beam.enabled or settings.arrow.enabled
end

-- groupTag is only set when the position came from a group member; it lets us
-- drop the entry immediately when that member's mark is removed.
local function UpdateEntry(targetKey, unitTag, nowMs, groupTag)
    local zoneId, wx, wy, wz = GetUnitWorldPosition(unitTag)
    if wx == 0 and wz == 0 then return end
    local entry = Tracker.entries[targetKey]
    if not entry then
        entry = {}
        Tracker.entries[targetKey] = entry
    end
    entry.zoneId = zoneId
    entry.wx, entry.wy, entry.wz = wx, wy, wz
    entry.lastSeenMs = nowMs
    entry.groupTag = groupTag
    entry.name = GetUnitDisplayName(unitTag) or entry.name
end

-- Called every update tick. Cheap: a handful of C-side calls per tick.
function Tracker.Update(nowMs)
    -- Group leader (only interesting when someone else leads)
    if IsTargetWanted('leader') and IsUnitGrouped('player') and not IsUnitGroupLeader('player') then
        local leaderTag = GetGroupLeaderUnitTag()
        if leaderTag and leaderTag ~= '' and IsUnitOnline(leaderTag) then
            UpdateEntry('leader', leaderTag, nowMs)
        end
    end

    -- Marks carried by group members: continuous positions
    local groupSize = GetGroupSize()
    for i = 1, groupSize do
        local tag = GetGroupUnitTagByIndex(i)
        if tag and tag ~= '' then
            local markerType = GetUnitTargetMarkerType(tag)
            if markerType and markerType ~= TARGET_MARKER_TYPE_NONE then
                local target = Addon.TARGET_BY_MARKER[markerType]
                if target and IsTargetWanted(target.key) and IsUnitOnline(tag) then
                    UpdateEntry(target.key, tag, nowMs, tag)
                end
            end
        end
    end

    -- Marked unit under the crosshair. Names are always readable (needed to
    -- recognize the unit's compass pin later); the position snapshot only
    -- works for NPCs at close range - players always report 0,0,0.
    local markerType = GetUnitTargetMarkerType('reticleover')
    if markerType and markerType ~= TARGET_MARKER_TYPE_NONE then
        local target = Addon.TARGET_BY_MARKER[markerType]
        if target and IsTargetWanted(target.key) then
            local names = Tracker.markNames[target.key]
            if not names then
                names = {}
                Tracker.markNames[target.key] = names
            end
            names.charName = zo_strformat('<<1>>', GetUnitName('reticleover'))
            names.displayName = GetUnitDisplayName('reticleover')
            UpdateEntry(target.key, 'reticleover', nowMs)
        end
    end

    Tracker.UpdateCompassBearings(nowMs)

    -- Expire stale entries. A mark that was carried by a group member and got
    -- removed (or moved to another unit) is dropped right away instead of
    -- lingering until the timeout.
    local timeoutMs = Addon.db.general.markTimeout * 1000
    for targetKey, entry in pairs(Tracker.entries) do
        local maxAge = targetKey == 'leader' and 2000 or timeoutMs
        if nowMs - entry.lastSeenMs > maxAge then
            Tracker.entries[targetKey] = nil
        elseif entry.groupTag and nowMs - entry.lastSeenMs > 500 then
            Tracker.entries[targetKey] = nil
        end
    end
    for targetKey, bearing in pairs(Tracker.bearings) do
        if nowMs - bearing.atMs > timeoutMs then
            Tracker.bearings[targetKey] = nil
        end
    end
end

---------------------------------------------------------------------------
-- Compass bearings
---------------------------------------------------------------------------
local compassContainer   -- nil = not checked yet, false = unusable

local function MatchesDescription(description, names)
    local displayName, charName = names.displayName, names.charName
    -- pin descriptions can carry suffixes like " |c...(Below)|r", so a prefix
    -- match against the full unit name is enough
    if displayName and displayName ~= '' and string.sub(description, 1, #displayName) == displayName then
        return true
    end
    if charName and charName ~= '' and string.sub(description, 1, #charName) == charName then
        return true
    end
    return false
end

function Tracker.UpdateCompassBearings(nowMs)
    if compassContainer == nil then
        local container = COMPASS and COMPASS.container
        if container and type(container.GetNumCenterOveredPins) == 'function' then
            compassContainer = container
        else
            compassContainer = false
        end
    end
    if not compassContainer then return end

    local numPins = compassContainer:GetNumCenterOveredPins()
    if numPins == 0 then return end

    local heading
    for i = 1, numPins do
        local description = compassContainer:GetCenterOveredPinDescription(i)
        if description and description ~= '' then
            for targetKey, names in pairs(Tracker.markNames) do
                if IsTargetWanted(targetKey) and MatchesDescription(description, names) then
                    local bearing = Tracker.bearings[targetKey]
                    if not bearing then
                        bearing = {}
                        Tracker.bearings[targetKey] = bearing
                    end
                    heading = heading or GetPlayerCameraHeading()
                    bearing.heading = heading
                    bearing.atMs = nowMs
                end
            end
        end
    end
end

local function AgeToAlpha(ageMs)
    local timeoutMs = Addon.db.general.markTimeout * 1000
    if timeoutMs <= 0 then return 1 end
    local fadeStart = timeoutMs * 0.75
    if ageMs <= fadeStart then return 1 end
    return math.max(0, 1 - (ageMs - fadeStart) / (timeoutMs - fadeStart))
end

-- Returns 0..1: how much to fade a target based on the age of its position.
-- Leader positions are continuous, so anything still in the table is fresh.
function Tracker.GetAgeAlpha(targetKey, nowMs)
    local entry = Tracker.entries[targetKey]
    if not entry then return 0 end
    if targetKey == 'leader' then return 1 end
    return AgeToAlpha(nowMs - entry.lastSeenMs)
end

function Tracker.GetBearingAlpha(targetKey, nowMs)
    local bearing = Tracker.bearings[targetKey]
    if not bearing then return 0 end
    return AgeToAlpha(nowMs - bearing.atMs)
end

function Tracker.Reset()
    Tracker.entries = {}
    Tracker.bearings = {}
end
