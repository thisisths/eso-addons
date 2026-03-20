local Addon = _G['NdgBuffsAndDebuffs']

Addon.displayFrames    = {}
Addon.activeTimedAuras = {}
Addon.auraLookup       = { player = {}, reticleover = {} }

---------------------------------------------------------------------------
-- Blacklist: pre-processed lookup tables keyed by lowercase name
---------------------------------------------------------------------------
Addon.blacklistCache = {}  -- [groupId] = { ["name"] = true, ... }

-- Rebuild the lookup table for a group from the raw blacklist string
function Addon.RebuildBlacklist(groupId)
    local cache = {}
    local blacklist = Addon.db.groups[groupId] and Addon.db.groups[groupId].blacklist
    if blacklist and blacklist ~= '' then
        for line in string.gmatch(blacklist, '[^\r\n]+') do
            local entry = string.lower(line:match('^%s*(.-)%s*$'))  -- trim + lowercase
            if entry ~= '' then
                cache[entry] = true
            end
        end
    end
    Addon.blacklistCache[groupId] = cache
end

-- Fast lookup against the cached table
function Addon.IsBlacklisted(groupId, auraName)
    if not auraName or auraName == '' then return false end
    local cache = Addon.blacklistCache[groupId]
    if not cache then return false end
    return cache[string.lower(auraName)] == true
end

---------------------------------------------------------------------------
-- Food/drink buff detection helper (used by ReminderTracker)
-- Food buffs are very long-duration buffs (30+ min) that are not debuffs
---------------------------------------------------------------------------
local FOOD_MIN_DURATION = 1200  -- 20 minutes; all food/drink buffs are 30+ min

function Addon.IsFoodBuff(buffType, timeStarted, timeEnding)
    -- Must not be a debuff
    if buffType == BUFF_EFFECT_TYPE_DEBUFF then return false end
    -- Must have a long duration
    local duration = timeEnding - timeStarted
    if duration < FOOD_MIN_DURATION then return false end
    return true
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------
function Addon.OnInitialize(eventCode, addonName)
    if addonName ~= Addon.NAME then return end
    EVENT_MANAGER:UnregisterForEvent(Addon.NAME, EVENT_ADD_ON_LOADED)

    -- Saved variables (account-wide)
    Addon.db = ZO_SavedVars:NewAccountWide('NdgBuffsAndDebuffsDB', Addon.DB_VERSION, nil, Addon.defaults)

    -- Build blacklist caches from saved vars
    for groupId = 2, Addon.NUM_GROUPS do
        Addon.RebuildBlacklist(groupId)
    end

    -- Create display frames for each group
    for groupId = 1, Addon.NUM_GROUPS do
        local frame = Addon.DisplayFrame:Create(groupId)
        Addon.displayFrames[groupId] = frame

        -- Add to HUD scenes so frames show during gameplay
        local fragment = ZO_HUDFadeSceneFragment:New(frame, 0, 0)
        HUD_SCENE:AddFragment(fragment)
        HUD_UI_SCENE:AddFragment(fragment)
        SIEGE_BAR_SCENE:AddFragment(fragment)

        -- Apply enabled state
        if not Addon.db.groups[groupId].enabled then
            frame:SetHidden(true)
        end
    end

    -- Initialize subsystems
    Addon.BuffTracker:Initialize()
    Addon.ReminderTracker:Initialize()
    Addon.Settings:Initialize()

    -- Shared timer for updating aura countdowns
    EVENT_MANAGER:RegisterForUpdate(Addon.NAME .. '_TimerUpdate', Addon.UPDATE_RATE, Addon.UpdateAllTimers)

    -- Slash command
    SLASH_COMMANDS[Addon.SLASH] = Addon.SlashCommand
end

---------------------------------------------------------------------------
-- Shared timer – updates all active timed aura labels
---------------------------------------------------------------------------
function Addon.UpdateAllTimers()
    local now = GetFrameTimeSeconds()
    for controlId, aura in pairs(Addon.activeTimedAuras) do
        local remaining = aura.finish - now
        if remaining <= 0 then
            aura:Release()
        else
            aura:UpdateTimerLabel(remaining)
        end
    end
end

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------
function Addon.SlashCommand(text)
    local cmd = string.lower(tostring(text)):match('^%s*(.-)%s*$')
    if cmd == 'lock' then
        Addon:LockFrames()
    elseif cmd == 'unlock' then
        Addon:UnlockFrames()
    else
        d('[NdgBuffsAndDebuffs] Usage: /ndgbuffs lock|unlock')
    end
end

---------------------------------------------------------------------------
-- Lock / Unlock
---------------------------------------------------------------------------
function Addon:UnlockFrames()
    self.db.locked = false
    for groupId = 1, self.NUM_GROUPS do
        local frame = self.displayFrames[groupId]
        frame:EnableDrag()
    end
    d('[NdgBuffsAndDebuffs] Frames unlocked – drag to reposition.')
end

function Addon:LockFrames()
    self.db.locked = true
    for groupId = 1, self.NUM_GROUPS do
        local frame = self.displayFrames[groupId]
        frame:DisableDrag()
    end
    d('[NdgBuffsAndDebuffs] Frames locked.')
end

---------------------------------------------------------------------------
-- Reconfigure a group (called when settings change)
---------------------------------------------------------------------------
function Addon:ReconfigureGroup(groupId)
    local frame = self.displayFrames[groupId]
    if not frame then return end

    local db = self.db.groups[groupId]

    -- Reconfigure all active aura controls in this frame
    for _, aura in pairs(frame.auras) do
        aura:Configure(db)
    end

    frame:UpdateLayout()
end

---------------------------------------------------------------------------
-- Helper: compute edge-relative position for a frame
---------------------------------------------------------------------------
function Addon:GetEdgeRelativePosition(frame)
    local screenW, screenH = GuiRoot:GetDimensions()
    local cx, cy = frame:GetCenter()

    local point
    local x, y

    -- Determine nearest horizontal and vertical edges
    local nearLeft  = cx < screenW / 2
    local nearTop   = cy < screenH / 2

    if nearLeft and nearTop then
        point = TOPLEFT
        x = frame:GetLeft()
        y = frame:GetTop()
    elseif not nearLeft and nearTop then
        point = TOPRIGHT
        x = frame:GetRight() - screenW
        y = frame:GetTop()
    elseif nearLeft and not nearTop then
        point = BOTTOMLEFT
        x = frame:GetLeft()
        y = frame:GetBottom() - screenH
    else
        point = BOTTOMRIGHT
        x = frame:GetRight() - screenW
        y = frame:GetBottom() - screenH
    end

    return point, x, y
end

---------------------------------------------------------------------------
-- Register for addon loaded event
---------------------------------------------------------------------------
EVENT_MANAGER:RegisterForEvent(Addon.NAME, EVENT_ADD_ON_LOADED, Addon.OnInitialize)
