local Addon = NdgCrown

local UPDATE_INTERVAL_MS = 25
local UPDATE_NAME = Addon.NAME .. 'Update'

local logger

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function IsInPvPArea()
    return IsPlayerInAvAWorld() or IsActiveWorldBattleground()
end

local function AnyTargetEnabled()
    for _, target in ipairs(Addon.TARGETS) do
        local settings = Addon.db.targets[target.key]
        if settings.beam.enabled or settings.arrow.enabled then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Update loop
---------------------------------------------------------------------------
local updateRunning = false

function Addon.OnUpdate()
    local nowMs = GetFrameTimeMilliseconds()
    local Tracker, Beam, Arrow = Addon.Tracker, Addon.Beam, Addon.Arrow

    Tracker.Update(nowMs)

    local cameraHeading = GetPlayerCameraHeading()
    if cameraHeading > math.pi then
        cameraHeading = cameraHeading - 2 * math.pi
    end
    local playerZoneId, playerX, _, playerZ = GetUnitWorldPosition('player')
    local general = Addon.db.general

    for _, target in ipairs(Addon.TARGETS) do
        local key = target.key
        local settings = Addon.db.targets[key]
        local entry = Tracker.entries[key]
        if entry and entry.zoneId ~= playerZoneId then
            entry = nil
        end
        local beamDrawn, arrowDrawn = false, false

        if entry then
            -- the beam marks a fixed spot, so it may linger on the last
            -- known position for a while (alpha fades out toward the end)
            if settings.beam.enabled then
                local beamAlpha = Tracker.GetBeamAlpha(key, nowMs)
                if beamAlpha > 0 then
                    Beam.Show(key, entry.wx, entry.wy, entry.wz, cameraHeading, beamAlpha)
                    beamDrawn = true
                end
            end

            -- the arrow only shows while the position is live: pointing at
            -- a stale spot is misleading, so it disappears immediately once
            -- updates stop
            if settings.arrow.enabled and Tracker.IsPositionKnown(key, nowMs) then
                local deltaX = playerX - entry.wx
                local deltaZ = playerZ - entry.wz
                local distance = math.sqrt(deltaX * deltaX + deltaZ * deltaZ) / 100
                local hideBelow = settings.arrow.override
                    and settings.arrow.hideBelow or general.arrowHideBelow
                if distance >= hideBelow then
                    Arrow.Show(key, deltaX, deltaZ, distance, cameraHeading)
                    arrowDrawn = true
                end
            end
        end

        if not beamDrawn then Beam.Hide(key) end
        if not arrowDrawn then Arrow.Hide(key) end
    end
end

local function StartUpdates()
    if not updateRunning then
        EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, UPDATE_INTERVAL_MS, Addon.OnUpdate)
        updateRunning = true
    end
end

local function StopUpdates()
    if updateRunning then
        EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
        updateRunning = false
    end
    Addon.Beam.HideAll()
    Addon.Arrow.HideAll()
end

-- (Re)evaluate whether the update loop should run. Called after loading
-- screens and whenever relevant settings change.
function Addon.RefreshActivation()
    if not Addon.db then return end
    local shouldRun = AnyTargetEnabled()
        and (not Addon.db.general.pvpOnly or IsInPvPArea())
    if shouldRun then
        StartUpdates()
    else
        StopUpdates()
    end
    if logger then
        logger:Debug('RefreshActivation: running=%s', tostring(shouldRun))
    end
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------
function Addon.OnPlayerActivated()
    -- world positions are per-zone; stale entries would point at nonsense
    Addon.Tracker.Reset()
    Addon.RefreshActivation()
end

function Addon.OnAddOnLoaded(eventCode, addonName)
    if addonName ~= Addon.NAME then return end
    EVENT_MANAGER:UnregisterForEvent(Addon.NAME, EVENT_ADD_ON_LOADED)

    logger = LibDebugLogger and LibDebugLogger(Addon.NAME)

    Addon.db = ZO_SavedVars:NewAccountWide('NdgCrownDB', Addon.DB_VERSION, nil, Addon.defaults)

    Addon.Beam.Initialize()
    Addon.Arrow.Initialize()
    Addon.Settings:Initialize()

    SLASH_COMMANDS[Addon.SLASH] = Addon.SlashCommand

    EVENT_MANAGER:RegisterForEvent(Addon.NAME, EVENT_PLAYER_ACTIVATED, Addon.OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(Addon.NAME, EVENT_PLAYER_DEACTIVATED, StopUpdates)

    if logger then logger:Info('loaded v%s', Addon.VERSION) end
end

---------------------------------------------------------------------------
-- Reticle probe: /ndgcrown probe
-- Logs what the position APIs return for whatever the crosshair touches.
-- Positions of players outside the group are expected to come back 0,0,0
-- (game restriction); this shows it explicitly.
---------------------------------------------------------------------------
local PROBE_NAME = Addon.NAME .. 'Probe'
local probeRunning = false
local lastProbedUnit = ''

-- Probe output goes to chat AND to LibDebugLogger, so results can be read
-- from SavedVariables/LibDebugLogger.lua after /reloadui instead of copying
-- chat lines one by one.
local function ProbeOut(formatString, ...)
    local message = string.format(formatString, ...)
    d(message)
    if logger then logger:Info(message) end
end

local function ProbeReticle()
    local name = GetUnitName('reticleover')
    if name == '' then
        lastProbedUnit = ''
        return
    end
    if name == lastProbedUnit then return end
    lastProbedUnit = name

    local marker = GetUnitTargetMarkerType('reticleover')
    local wZone, wx, wy, wz = GetUnitWorldPosition('reticleover')
    local rZone, rx, ry, rz = GetUnitRawWorldPosition('reticleover')
    ProbeOut('[probe] %s (player=%s, marker=%s)', name,
        tostring(IsUnitPlayer('reticleover')), tostring(marker))
    ProbeOut('  world: zone=%s pos=%s,%s,%s', tostring(wZone), tostring(wx), tostring(wy), tostring(wz))
    ProbeOut('  raw:   zone=%s pos=%s,%s,%s', tostring(rZone), tostring(rx), tostring(ry), tostring(rz))
end

local function ToggleProbe()
    probeRunning = not probeRunning
    if probeRunning then
        lastProbedUnit = ''
        ProbeOut('[probe] ===== probe ON =====')
        EVENT_MANAGER:RegisterForUpdate(PROBE_NAME, 100, ProbeReticle)
        d('[' .. Addon.NAME .. '] probe ON - output also goes to LibDebugLogger. /ndgcrown probe to stop.')
    else
        EVENT_MANAGER:UnregisterForUpdate(PROBE_NAME)
        ProbeOut('[probe] ===== probe off =====')
    end
end

---------------------------------------------------------------------------
-- Slash command: /ndgcrown  (status overview, useful for testing)
---------------------------------------------------------------------------
function Addon.SlashCommand(text)
    local cmd = string.lower(tostring(text)):match('^%s*(.-)%s*$')
    if cmd == '' then
        d('[' .. Addon.NAME .. '] v' .. Addon.VERSION
            .. ' | loop: ' .. (updateRunning and 'running' or 'stopped')
            .. ' | pvpOnly: ' .. tostring(Addon.db.general.pvpOnly))
        local nowMs = GetFrameTimeMilliseconds()
        local _, playerX, _, playerZ = GetUnitWorldPosition('player')
        local count = 0
        for _, target in ipairs(Addon.TARGETS) do
            local entry = Addon.Tracker.entries[target.key]
            if entry then
                count = count + 1
                local deltaX, deltaZ = playerX - entry.wx, playerZ - entry.wz
                local distance = math.sqrt(deltaX * deltaX + deltaZ * deltaZ) / 100
                local state = Addon.Tracker.IsPositionKnown(target.key, nowMs)
                    and 'live' or 'lingering'
                df('  %s: %s, %.0fm away, seen %.1fs ago (%s)', target.name,
                    entry.name or '?', distance, (nowMs - entry.lastSeenMs) / 1000, state)
            end
        end
        if count == 0 then d('  no tracked targets') end
    elseif cmd == 'probe' then
        ToggleProbe()
    else
        d('[' .. Addon.NAME .. '] Unknown command: ' .. cmd)
    end
end

EVENT_MANAGER:RegisterForEvent(Addon.NAME, EVENT_ADD_ON_LOADED, Addon.OnAddOnLoaded)
