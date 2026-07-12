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
            local ageAlpha = Tracker.GetAgeAlpha(key, nowMs)
            if ageAlpha > 0 then
                local deltaX = playerX - entry.wx
                local deltaZ = playerZ - entry.wz
                local distance = math.sqrt(deltaX * deltaX + deltaZ * deltaZ) / 100

                if settings.beam.enabled then
                    Beam.Show(key, entry.wx, entry.wy, entry.wz, cameraHeading, ageAlpha)
                    beamDrawn = true
                end
                if settings.arrow.enabled and distance >= general.arrowHideBelow then
                    Arrow.Show(key, deltaX, deltaZ, distance, cameraHeading, ageAlpha)
                    arrowDrawn = true
                end
            end
        end

        -- Direction-only fallback: a compass bearing can't feed the beam, but
        -- it keeps the arrow alive when no (fresh) position is known - e.g.
        -- marked players outside the group. A recent position wins; a bearing
        -- clearly fresher than the position takes over.
        if not arrowDrawn and settings.arrow.enabled then
            local bearing = Tracker.bearings[key]
            if bearing and (not entry or bearing.atMs > entry.lastSeenMs + 2000) then
                local bearingAlpha = Tracker.GetBearingAlpha(key, nowMs)
                if bearingAlpha > 0 then
                    Arrow.ShowBearing(key, bearing.heading, cameraHeading,
                        (nowMs - bearing.atMs) / 1000, bearingAlpha)
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
local lastPinSummary

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

-- Logs the pins currently passing the compass center (type:description).
-- Used to find out whether target-marker pins are exposed there; the engine
-- draws them, but only center-overed pins are queryable from Lua.
local compassProbeBroken = false

local function ProbeCompassInner()
    local container = COMPASS and COMPASS.container
    local numPins = container:GetNumCenterOveredPins()
    local summary = ''
    for i = 1, numPins do
        local part = tostring(container:GetCenterOveredPinType(i))
            .. ':' .. tostring(container:GetCenterOveredPinDescription(i))
        summary = summary == '' and part or (summary .. ' | ' .. part)
    end
    if summary ~= lastPinSummary then
        lastPinSummary = summary
        ProbeOut('[probe] compass center pins (%d): %s | camera heading %.3f', numPins,
            summary == '' and '(none)' or summary, GetPlayerCameraHeading())
    end
end

local function ProbeCompass()
    if compassProbeBroken then return end
    local ok, err = pcall(ProbeCompassInner)
    if not ok then
        compassProbeBroken = true
        ProbeOut('[probe] compass probing FAILED: %s', tostring(err))
    end
end

local function ProbeSelfTest()
    local container = COMPASS and COMPASS.container
    if not container then
        ProbeOut('[probe] self-test: COMPASS.container NOT FOUND - compass probing disabled')
        compassProbeBroken = true
        return
    end
    if type(container.GetNumCenterOveredPins) ~= 'function' then
        ProbeOut('[probe] self-test: center-over API missing on compass container')
        compassProbeBroken = true
        return
    end
    local ok, result = pcall(container.GetNumCenterOveredPins, container)
    if ok then
        ProbeOut('[probe] self-test OK, compass reachable (%d pins at center right now)', result)
    else
        compassProbeBroken = true
        ProbeOut('[probe] self-test FAILED: %s', tostring(result))
    end

    -- one-time: dump pin type constants in the range we saw marker pins use,
    -- to learn their official names
    local found = {}
    for globalName, value in zo_insecurePairs(_G) do
        if type(value) == 'number' and value >= 200 and value <= 260
            and type(globalName) == 'string'
            and string.sub(globalName, 1, 13) == 'MAP_PIN_TYPE_' then
            table.insert(found, globalName .. '=' .. value)
        end
    end
    table.sort(found)
    ProbeOut('[probe] pin types 200-260: %s', table.concat(found, ', '))
end

local function ProbeTick()
    ProbeReticle()
    ProbeCompass()
end

local function ToggleProbe()
    probeRunning = not probeRunning
    if probeRunning then
        lastProbedUnit = ''
        lastPinSummary = nil
        compassProbeBroken = false
        ProbeOut('[probe] ===== probe ON =====')
        ProbeSelfTest()
        EVENT_MANAGER:RegisterForUpdate(PROBE_NAME, 100, ProbeTick)
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
                df('  %s: %s, %.0fm away, seen %.1fs ago', target.name,
                    entry.name or '?', distance, (nowMs - entry.lastSeenMs) / 1000)
            end
            local bearing = Addon.Tracker.bearings[target.key]
            if bearing then
                count = count + 1
                df('  %s: compass bearing %.2f, %.1fs old', target.name,
                    bearing.heading, (nowMs - bearing.atMs) / 1000)
            end
            local names = Addon.Tracker.markNames[target.key]
            if names then
                df('  %s: watching for %s / %s', target.name,
                    names.charName or '?', names.displayName or '?')
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
