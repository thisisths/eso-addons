local Addon = NdgCrown

-- Tracks world positions of the group leader and of units carrying a
-- base-game target marker.
--
-- Position sources, best first:
--   * group unit tags (group1..group12): continuous, always accurate
--   * 'reticleover': while the crosshair is over a marked unit. Only works
--     for NPCs at fairly close range - players outside the group always
--     report 0,0,0 (game restriction), so they are never tracked.
--
-- A position counts as "known" while it keeps being refreshed
-- (POSITION_FRESH_MS). Once refreshes stop, the arrow disappears
-- immediately; the beam keeps marking the last known spot for
-- BEAM_LINGER_MS, then goes away too.
--
-- Entry layout (Tracker.entries[targetKey]):
--   { zoneId, wx, wy, wz (cm world coords), lastSeenMs, name,
--     groupTag, markerType (only for group-sourced marks) }
Addon.Tracker = {}
local Tracker = Addon.Tracker

local POSITION_FRESH_MS = 1000   -- refreshed within this = position is "known"
local BEAM_LINGER_MS    = 10000  -- beam stays on the last known position this long
local BEAM_FADE_PORTION = 0.3    -- fade out over the last part of the linger

Tracker.entries = {}

local function IsTargetWanted(targetKey)
    local settings = Addon.db.targets[targetKey]
    return settings.beam.enabled or settings.arrow.enabled or settings.ring.enabled
end

-- groupTag/markerType are only set when the position came from a group
-- member; they let us drop the entry immediately when that member's mark
-- is removed.
local function UpdateEntry(targetKey, unitTag, nowMs, groupTag, markerType)
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
    entry.markerType = markerType
    local displayName = GetUnitDisplayName(unitTag)
    if displayName and displayName ~= '' then
        entry.name = displayName
    elseif not entry.name or entry.name == '' then
        -- NPCs have no display name; strip grammar markers from the unit name
        entry.name = zo_strformat('<<1>>', GetUnitName(unitTag))
    end
end

-- Called every update tick. Cheap: a handful of C-side calls per tick.
function Tracker.Update(nowMs)
    -- Group leader (only interesting when someone else leads)
    if IsTargetWanted('leader') then
        if IsUnitGrouped('player') and not IsUnitGroupLeader('player') then
            local leaderTag = GetGroupLeaderUnitTag()
            if leaderTag and leaderTag ~= '' and IsUnitOnline(leaderTag) then
                UpdateEntry('leader', leaderTag, nowMs)
            end
        else
            -- no foreign leader (anymore) - don't linger on the old one
            Tracker.entries['leader'] = nil
        end
    end

    -- Marked NPC under the crosshair (players always report 0,0,0 and are
    -- skipped inside UpdateEntry). Runs before the group scan so that for
    -- marked group members the group source wins and keeps its groupTag.
    local markerType = GetUnitTargetMarkerType('reticleover')
    if markerType and markerType ~= TARGET_MARKER_TYPE_NONE then
        local target = Addon.TARGET_BY_MARKER[markerType]
        if target and IsTargetWanted(target.key) then
            UpdateEntry(target.key, 'reticleover', nowMs)
        end
    end

    -- Marks carried by group members: continuous positions
    local groupSize = GetGroupSize()
    for i = 1, groupSize do
        local tag = GetGroupUnitTagByIndex(i)
        if tag and tag ~= '' then
            local groupMarkerType = GetUnitTargetMarkerType(tag)
            if groupMarkerType and groupMarkerType ~= TARGET_MARKER_TYPE_NONE then
                local target = Addon.TARGET_BY_MARKER[groupMarkerType]
                if target and IsTargetWanted(target.key) and IsUnitOnline(tag) then
                    UpdateEntry(target.key, tag, nowMs, tag, groupMarkerType)
                end
            end
        end
    end

    -- Expire entries once the beam linger is over. A mark that was carried
    -- by a group member and got removed (or moved to another unit) is
    -- dropped right away instead of lingering.
    for targetKey, entry in pairs(Tracker.entries) do
        local age = nowMs - entry.lastSeenMs
        if age > POSITION_FRESH_MS + BEAM_LINGER_MS then
            Tracker.entries[targetKey] = nil
        elseif entry.groupTag and age > 500
            and GetUnitTargetMarkerType(entry.groupTag) ~= entry.markerType then
            Tracker.entries[targetKey] = nil
        end
    end
end

-- True while the position keeps being refreshed - the arrow only shows then.
function Tracker.IsPositionKnown(targetKey, nowMs)
    local entry = Tracker.entries[targetKey]
    return entry ~= nil and nowMs - entry.lastSeenMs <= POSITION_FRESH_MS
end

-- 0..1 beam opacity factor: full while the position is known, held through
-- most of the linger, faded out toward its end.
function Tracker.GetBeamAlpha(targetKey, nowMs)
    local entry = Tracker.entries[targetKey]
    if not entry then return 0 end
    local lingerAge = (nowMs - entry.lastSeenMs) - POSITION_FRESH_MS
    if lingerAge <= 0 then return 1 end
    if lingerAge >= BEAM_LINGER_MS then return 0 end
    local fadeStart = BEAM_LINGER_MS * (1 - BEAM_FADE_PORTION)
    if lingerAge <= fadeStart then return 1 end
    return 1 - (lingerAge - fadeStart) / (BEAM_LINGER_MS - fadeStart)
end

function Tracker.Reset()
    Tracker.entries = {}
end
