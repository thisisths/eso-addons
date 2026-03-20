local Addon = _G['NdgBuffsAndDebuffs']

local BuffTracker = {}
Addon.BuffTracker = BuffTracker

---------------------------------------------------------------------------
-- Initialize event registrations
---------------------------------------------------------------------------
function BuffTracker:Initialize()
    -- Player buffs/debuffs
    EVENT_MANAGER:RegisterForEvent(
        Addon.NAME .. '_PlayerEffects',
        EVENT_EFFECT_CHANGED,
        function(...) self:OnEffectChanged(...) end
    )
    EVENT_MANAGER:AddFilterForEvent(
        Addon.NAME .. '_PlayerEffects',
        EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_UNIT_TAG, 'player'
    )

    -- Target buffs/debuffs
    EVENT_MANAGER:RegisterForEvent(
        Addon.NAME .. '_TargetEffects',
        EVENT_EFFECT_CHANGED,
        function(...) self:OnEffectChanged(...) end
    )
    EVENT_MANAGER:AddFilterForEvent(
        Addon.NAME .. '_TargetEffects',
        EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_UNIT_TAG, 'reticleover'
    )

    -- Target changed – full rescan
    EVENT_MANAGER:RegisterForEvent(
        Addon.NAME .. '_TargetChanged',
        EVENT_RETICLE_TARGET_CHANGED,
        function() self:OnTargetChanged() end
    )

    -- Initial scan of existing player buffs on login/reload
    EVENT_MANAGER:RegisterForEvent(
        Addon.NAME .. '_PlayerActivated',
        EVENT_PLAYER_ACTIVATED,
        function() self:OnPlayerActivated() end
    )
end

---------------------------------------------------------------------------
-- Classify a buff/debuff into the correct display group
---------------------------------------------------------------------------
function BuffTracker:ClassifyEffect(unitTag, buffType, duration)
    if unitTag == 'player' then
        if buffType == BUFF_EFFECT_TYPE_DEBUFF then
            return Addon.GROUP_DEBUFF
        else
            if duration > 0 and duration >= Addon.db.shortBuffThreshold then
                return Addon.GROUP_LONG_BUFF
            else
                return Addon.GROUP_SHORT_BUFF
            end
        end
    elseif unitTag == 'reticleover' then
        if buffType == BUFF_EFFECT_TYPE_DEBUFF then
            return Addon.GROUP_TARGET_DEBUFF
        else
            return Addon.GROUP_TARGET_BUFF
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Add a buff to the appropriate display frame
---------------------------------------------------------------------------
function BuffTracker:AddToFrame(unitTag, buffName, timeStarted, timeEnding, iconFilename, abilityId, stackCount, buffType)
    local duration = timeEnding - timeStarted
    local groupId = self:ClassifyEffect(unitTag, buffType, duration)
    if not groupId then return end
    if not Addon.db.groups[groupId].enabled then return end
    if Addon.IsBlacklisted(groupId, buffName) then return end

    -- Ensure lookup table exists
    Addon.auraLookup[unitTag] = Addon.auraLookup[unitTag] or {}

    -- Skip if already tracked
    if Addon.auraLookup[unitTag][abilityId] then
        Addon.auraLookup[unitTag][abilityId]:Update(timeStarted, timeEnding, stackCount)
        return
    end

    local frame = Addon.displayFrames[groupId]
    if frame then
        frame:AddAura(buffName, unitTag, timeStarted, timeEnding, iconFilename, abilityId, stackCount)
    end
end

---------------------------------------------------------------------------
-- Initial scan: pick up all existing player buffs (including food)
---------------------------------------------------------------------------
function BuffTracker:OnPlayerActivated()
    -- Only need this once per load
    EVENT_MANAGER:UnregisterForEvent(Addon.NAME .. '_PlayerActivated', EVENT_PLAYER_ACTIVATED)

    -- Enable burst mode on player frames
    for groupId = 1, 4 do
        local frame = Addon.displayFrames[groupId]
        if frame then frame.burstMode = true end
    end

    local numBuffs = GetNumBuffs('player')
    for i = 1, numBuffs do
        local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename,
              buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff,
              castByPlayer = GetUnitBuffInfo('player', i)

        if buffName and buffName ~= '' and timeEnding > GetFrameTimeSeconds() then
            self:AddToFrame('player', buffName, timeStarted, timeEnding, iconFilename, abilityId, stackCount, buffType)
        end
    end

    -- Disable burst mode and layout
    for groupId = 1, 4 do
        local frame = Addon.displayFrames[groupId]
        if frame then
            frame.burstMode = false
            frame:UpdateLayout()
        end
    end
end

---------------------------------------------------------------------------
-- Handle EVENT_EFFECT_CHANGED
---------------------------------------------------------------------------
function BuffTracker:OnEffectChanged(eventCode, changeType, effectSlot, effectName,
        unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType,
        abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)

    -- Effect faded – remove aura
    if changeType == EFFECT_RESULT_FADED then
        Addon.auraLookup[unitTag] = Addon.auraLookup[unitTag] or {}
        local existingAura = Addon.auraLookup[unitTag][abilityId]
        if existingAura then
            existingAura:Release()
        end
        return
    end

    -- Only handle gained or updated
    if changeType ~= EFFECT_RESULT_GAINED and changeType ~= EFFECT_RESULT_UPDATED then
        return
    end

    self:AddToFrame(unitTag, effectName, beginTime, endTime, iconName, abilityId, stackCount, buffType)
end

---------------------------------------------------------------------------
-- Handle target change – release all target auras and rescan
---------------------------------------------------------------------------
function BuffTracker:OnTargetChanged()
    -- Release existing target auras
    local targetBuffFrame  = Addon.displayFrames[Addon.GROUP_TARGET_BUFF]
    local targetDebuffFrame = Addon.displayFrames[Addon.GROUP_TARGET_DEBUFF]

    if targetBuffFrame then targetBuffFrame:ReleaseAll() end
    if targetDebuffFrame then targetDebuffFrame:ReleaseAll() end

    -- Clear target lookup
    Addon.auraLookup['reticleover'] = {}

    -- If we have a target, rescan its buffs
    if not DoesUnitExist('reticleover') then return end

    -- Enable burst mode to batch layout updates
    if targetBuffFrame then targetBuffFrame.burstMode = true end
    if targetDebuffFrame then targetDebuffFrame.burstMode = true end

    local numBuffs = GetNumBuffs('reticleover')
    for i = 1, numBuffs do
        local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename,
              buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff,
              castByPlayer = GetUnitBuffInfo('reticleover', i)

        if buffName and buffName ~= '' then
            self:AddToFrame('reticleover', buffName, timeStarted, timeEnding, iconFilename, abilityId, stackCount, buffType)
        end
    end

    -- Disable burst mode and do final layout
    if targetBuffFrame then
        targetBuffFrame.burstMode = false
        targetBuffFrame:UpdateLayout()
    end
    if targetDebuffFrame then
        targetDebuffFrame.burstMode = false
        targetDebuffFrame:UpdateLayout()
    end
end
