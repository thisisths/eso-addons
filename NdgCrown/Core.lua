local Addon = NdgCrown

local UPDATE_INTERVAL_MS = 0   -- every frame, so beams/rings don't jitter while moving
local UPDATE_NAME = Addon.NAME .. 'Update'

local logger

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function IsInPvPArea()
    return IsPlayerInAvAWorld() or IsActiveWorldBattleground()
end

local function AnyTargetEnabled()
    if Addon.db.selfRing.enabled then return true end
    for _, target in ipairs(Addon.TARGETS) do
        local settings = Addon.db.targets[target.key]
        if settings.beam.enabled or settings.arrow.enabled or settings.ring.enabled then
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
    local Tracker, Beam, Arrow, Ring = Addon.Tracker, Addon.Beam, Addon.Arrow, Addon.Ring

    Tracker.Update(nowMs)

    local cameraHeading = GetPlayerCameraHeading()
    if cameraHeading > math.pi then
        cameraHeading = cameraHeading - 2 * math.pi
    end
    local playerZoneId, playerX, playerY, playerZ = GetUnitWorldPosition('player')
    local general = Addon.db.general

    local selfRing = Addon.db.selfRing
    if selfRing.enabled then
        Ring.Show('self', playerX, playerY, playerZ, selfRing.radius, selfRing.color)
    else
        Ring.Hide('self')
    end

    for _, target in ipairs(Addon.TARGETS) do
        local key = target.key
        local settings = Addon.db.targets[key]
        local entry = Tracker.entries[key]
        if entry and entry.zoneId ~= playerZoneId then
            entry = nil
        end
        local beamDrawn, arrowDrawn, ringDrawn = false, false, false

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

            -- the ring shows the current range, so like the arrow it only
            -- shows while the position is live; in range = 3D distance
            local ring = settings.ring
            if ring.enabled and Tracker.IsPositionKnown(key, nowMs) then
                local deltaX = playerX - entry.wx
                local deltaY = playerY - entry.wy
                local deltaZ = playerZ - entry.wz
                local distance = math.sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ) / 100
                local color = distance <= ring.radius and ring.inColor or ring.outColor
                Ring.Show(key, entry.wx, entry.wy, entry.wz, ring.radius, color)
                ringDrawn = true
            end
        end

        if not beamDrawn then Beam.Hide(key) end
        if not arrowDrawn then Arrow.Hide(key) end
        if not ringDrawn then Ring.Hide(key) end
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
    Addon.Ring.HideAll()
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
    Addon.Ring.Initialize()
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
-- Beam probe: /ndgcrown beamprobe
-- Logs once per second what the leader beam is fed and where its control
-- actually sits. Positive control: a dummy control with its own 3D render
-- space, set to origin 0 when the probe starts. If the game shifts 3D
-- render-space origins when its floating world origin moves (the suspected
-- cause of the old misplaced beams), the dummy's origin drifts away from 0.
---------------------------------------------------------------------------
local BEAM_PROBE_NAME = Addon.NAME .. 'BeamProbe'
local beamProbeRunning = false
local probeAnchor

local function Fmt(x, y, z)
    return string.format('%.2f,%.2f,%.2f', x or 0, y or 0, z or 0)
end

local function ProbeBeam()
    local ax, ay, az = probeAnchor:Get3DRenderSpaceOrigin()
    local wx0, wy0, wz0 = WorldPositionToGuiRender3DPosition(0, 0, 0)
    ProbeOut('[beamprobe] anchor origin=%s | render pos of world 0=%s', Fmt(ax, ay, az), Fmt(wx0, wy0, wz0))

    local _, px, py, pz = GetUnitWorldPosition('player')
    ProbeOut('  player world=%s render=%s', Fmt(px, py, pz), Fmt(WorldPositionToGuiRender3DPosition(px, py, pz)))

    local leaderTag = GetGroupLeaderUnitTag()
    if not IsUnitGrouped('player') or leaderTag == '' then
        ProbeOut('  not grouped')
        return
    end
    local wZone, wx, wy, wz = GetUnitWorldPosition(leaderTag)
    local rZone, rx, ry, rz = GetUnitRawWorldPosition(leaderTag)
    local dx, dy, dz = (px - wx) / 100, (py - wy) / 100, (pz - wz) / 100
    ProbeOut('  leader %s (%s) zone=%s/%s dist=%.1fm dy=%.1fm', leaderTag, GetUnitDisplayName(leaderTag),
        tostring(wZone), tostring(rZone), math.sqrt(dx * dx + dz * dz), dy)
    ProbeOut('  leader world=%s raw=%s', Fmt(wx, wy, wz), Fmt(rx, ry, rz))

    local beam = Addon.Beam.GetControl('leader')
    local bx, by, bz = beam:Get3DRenderSpaceOrigin()
    local ex, ey, ez = WorldPositionToGuiRender3DPosition(wx, wy + Addon.db.general.beamHeight * 50, wz)
    ProbeOut('  beam origin=%s expected=%s hidden=%s alpha=%.2f', Fmt(bx, by, bz), Fmt(ex, ey, ez),
        tostring(beam:IsHidden()), beam:GetAlpha())
    local window = Addon.GetWorldWindow()
    ProbeOut('  window hidden=%s alpha=%.2f loop=%s', tostring(window:IsHidden()), window:GetAlpha(),
        tostring(updateRunning))
end

local function ToggleBeamProbe()
    beamProbeRunning = not beamProbeRunning
    if beamProbeRunning then
        if not probeAnchor then
            probeAnchor = WINDOW_MANAGER:CreateControl(nil, Addon.GetWorldWindow(), CT_TEXTURE)
            probeAnchor:Create3DRenderSpace()
            probeAnchor:SetHidden(true)
        end
        probeAnchor:Set3DRenderSpaceOrigin(0, 0, 0)
        ProbeOut('[beamprobe] ===== beam probe ON (v%s) =====', Addon.VERSION)
        EVENT_MANAGER:RegisterForUpdate(BEAM_PROBE_NAME, 1000, ProbeBeam)
        d('[' .. Addon.NAME .. '] beam probe ON - logs to LibDebugLogger. /ndgcrown beamprobe to stop.')
    else
        EVENT_MANAGER:UnregisterForUpdate(BEAM_PROBE_NAME)
        ProbeOut('[beamprobe] ===== beam probe off =====')
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
    elseif cmd == 'beamprobe' then
        ToggleBeamProbe()
    else
        d('[' .. Addon.NAME .. '] Unknown command: ' .. cmd)
    end
end

EVENT_MANAGER:RegisterForEvent(Addon.NAME, EVENT_ADD_ON_LOADED, Addon.OnAddOnLoaded)
