local Addon = _G['NdgBuffsAndDebuffs']

local ReminderTracker = {}
Addon.ReminderTracker = ReminderTracker

ReminderTracker.reminderAuras = {}

---------------------------------------------------------------------------
-- Initialize polling
---------------------------------------------------------------------------
function ReminderTracker:Initialize()
    EVENT_MANAGER:RegisterForUpdate(
        Addon.NAME .. '_Reminders',
        500,
        function() self:Poll() end
    )
end

---------------------------------------------------------------------------
-- Main polling function
---------------------------------------------------------------------------
function ReminderTracker:Poll()
    if not Addon.db.groups[Addon.GROUP_REMINDER].enabled then return end

    local frame = Addon.displayFrames[Addon.GROUP_REMINDER]
    if not frame then return end

    self:CheckUltimate(frame)
    self:CheckPotion(frame)
    self:CheckFood(frame)
end

---------------------------------------------------------------------------
-- Check if ultimate is ready to use
---------------------------------------------------------------------------
function ReminderTracker:CheckUltimate(frame)
    if Addon.db.groups[Addon.GROUP_REMINDER].disableUltimate then
        if self.reminderAuras['ultimate'] then
            self.reminderAuras['ultimate']:Release()
            self.reminderAuras['ultimate'] = nil
        end
        return
    end

    local current, max = GetUnitPower('player', COMBAT_MECHANIC_FLAGS_ULTIMATE)

    -- Get the slotted ultimate's cost
    local ultSlotIndex = (ACTION_BAR_ULTIMATE_SLOT_INDEX or 7) + 1
    local abilityId = GetSlotBoundId(ultSlotIndex)
    local ultCost = 0
    if abilityId and abilityId > 0 then
        ultCost = GetAbilityCost(abilityId)
    end

    local isReady = (ultCost > 0 and current >= ultCost)

    if isReady and not self.reminderAuras['ultimate'] then
        local icon = GetSlotTexture(ultSlotIndex)
        self.reminderAuras['ultimate'] = frame:AddReminder('ultimate', 'Ultimate Ready', icon)
    elseif not isReady and self.reminderAuras['ultimate'] then
        self.reminderAuras['ultimate']:Release()
        self.reminderAuras['ultimate'] = nil
    end
end

---------------------------------------------------------------------------
-- Check if potion is off cooldown
---------------------------------------------------------------------------
function ReminderTracker:CheckPotion(frame)
    if Addon.db.groups[Addon.GROUP_REMINDER].disablePotion then
        if self.reminderAuras['potion'] then
            self.reminderAuras['potion']:Release()
            self.reminderAuras['potion'] = nil
        end
        return
    end

    -- GetCurrentQuickslot() returns the active quickslot wheel slot index
    local slotIndex = GetCurrentQuickslot()
    if not slotIndex then
        if self.reminderAuras['potion'] then
            self.reminderAuras['potion']:Release()
            self.reminderAuras['potion'] = nil
        end
        return
    end

    -- Quickslot functions require HOTBAR_CATEGORY_QUICKSLOT_WHEEL as second param
    local icon = GetSlotTexture(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    if not icon or icon == '' then
        if self.reminderAuras['potion'] then
            self.reminderAuras['potion']:Release()
            self.reminderAuras['potion'] = nil
        end
        return
    end

    local remain, duration, global = GetSlotCooldownInfo(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    local isReady = (remain == 0)

    if isReady and not self.reminderAuras['potion'] then
        self.reminderAuras['potion'] = frame:AddReminder('potion', 'Potion Ready', icon)
    elseif not isReady and self.reminderAuras['potion'] then
        self.reminderAuras['potion']:Release()
        self.reminderAuras['potion'] = nil
    end
end

---------------------------------------------------------------------------
-- Check if food/drink buff is active
---------------------------------------------------------------------------
function ReminderTracker:CheckFood(frame)
    if Addon.db.groups[Addon.GROUP_REMINDER].disableFood then
        if self.reminderAuras['food'] then
            self.reminderAuras['food']:Release()
            self.reminderAuras['food'] = nil
        end
        return
    end

    local hasFood = false
    local numBuffs = GetNumBuffs('player')

    for i = 1, numBuffs do
        local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename,
              buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff,
              castByPlayer = GetUnitBuffInfo('player', i)

        if Addon.IsFoodBuff(buffType, timeStarted, timeEnding) then
            hasFood = true
            break
        end
    end

    if not hasFood and not self.reminderAuras['food'] then
        self.reminderAuras['food'] = frame:AddReminder(
            'food',
            'No Food Buff',
            '/esoui/art/icons/ability_provisioner_001.dds'
        )
    elseif hasFood and self.reminderAuras['food'] then
        self.reminderAuras['food']:Release()
        self.reminderAuras['food'] = nil
    end
end
