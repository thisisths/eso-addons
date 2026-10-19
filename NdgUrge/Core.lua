local Addon = NdgUrge

-- NdgUrge is an NdgCrown extension (see NdgCrown/Extensions.lua): NdgCrown
-- tracks the group leader and calls OnUpdate every frame while IsActive()
-- is true; the settings show up as a submenu in NdgCrown's settings panel.

-- once shown, the warning only hides again 1m inside the limit, so it
-- doesn't flicker while you run right at the edge
local HYSTERESIS_M = 1

---------------------------------------------------------------------------
-- Extension callbacks
---------------------------------------------------------------------------
function Addon.IsActive()
    local db = Addon.db
    return db.enabled and (not db.pvpOnly or NdgCrown.IsInPvPArea())
end

function Addon.OnUpdate(nowMs)
    local Warning = Addon.Warning
    if Warning.IsUnlocked() then return end

    local db = Addon.db
    -- nil while the leader's position isn't live (not grouped, you lead,
    -- leader offline or in another zone)
    local distance = NdgCrown.GetLeaderDistance(nowMs)
    local tooFar = false
    if distance and not IsUnitDead('player') then
        local limit = db.maxDistance
        if Warning.IsShown() then
            limit = limit - HYSTERESIS_M
        end
        -- far beyond the limit you respawned or the leader ported: no warning
        tooFar = distance > limit
            and (db.ignoreBeyond == 0 or distance <= db.ignoreBeyond)
    end

    if tooFar then
        Warning.Show(distance)
    else
        Warning.Hide()
    end
end

function Addon.OnStop()
    Addon.Warning.Hide()
end

---------------------------------------------------------------------------
-- Lock / unlock
---------------------------------------------------------------------------
function Addon.SetUnlocked(value)
    if value == Addon.Warning.IsUnlocked() then return end
    Addon.Warning.SetUnlocked(value)
    if value then
        d('[' .. Addon.NAME .. '] Unlocked: close the menu, press "." for the mouse cursor and drag the text. '
            .. 'Lock it again in the settings or with ' .. Addon.SLASH .. ' lock.')
    else
        d('[' .. Addon.NAME .. '] Locked.')
    end
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------
function Addon.OnAddOnLoaded(eventCode, addonName)
    if addonName ~= Addon.NAME then return end
    EVENT_MANAGER:UnregisterForEvent(Addon.NAME, EVENT_ADD_ON_LOADED)

    Addon.db = ZO_SavedVars:NewAccountWide('NdgUrgeDB', Addon.DB_VERSION, nil, Addon.defaults)

    Addon.Warning.Initialize()

    NdgCrown.RegisterExtension({
        name = Addon.NAME,
        title = 'Stop Zerging (' .. Addon.NAME .. ')',
        IsActive = Addon.IsActive,
        OnUpdate = Addon.OnUpdate,
        OnStop = Addon.OnStop,
        GetOptions = Addon.Settings.GetOptions,
    })

    SLASH_COMMANDS[Addon.SLASH] = Addon.SlashCommand
end

---------------------------------------------------------------------------
-- Slash command: /ndgurge [lock|unlock]
---------------------------------------------------------------------------
function Addon.SlashCommand(text)
    local cmd = string.lower(tostring(text)):match('^%s*(.-)%s*$')
    if cmd == '' then
        local db = Addon.db
        d('[' .. Addon.NAME .. '] v' .. Addon.VERSION
            .. ' | enabled: ' .. tostring(db.enabled)
            .. ' | active: ' .. tostring(Addon.IsActive())
            .. ' | ' .. (Addon.Warning.IsUnlocked() and 'unlocked' or 'locked'))
        local distance = NdgCrown.GetLeaderDistance(GetFrameTimeMilliseconds())
        if distance then
            df('  leader %.1fm away, warning beyond %dm', distance, db.maxDistance)
        else
            d('  leader position not known right now')
        end
    elseif cmd == 'unlock' then
        Addon.SetUnlocked(true)
    elseif cmd == 'lock' then
        Addon.SetUnlocked(false)
    else
        d('[' .. Addon.NAME .. '] Usage: ' .. Addon.SLASH .. ' [lock|unlock]')
    end
end

EVENT_MANAGER:RegisterForEvent(Addon.NAME, EVENT_ADD_ON_LOADED, Addon.OnAddOnLoaded)
