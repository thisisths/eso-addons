local Addon = _G['NdgBuffsAndDebuffs']

local AuraControl = {}
Addon.AuraControl = AuraControl

local controlCount = 0

---------------------------------------------------------------------------
-- Create a new aura control (or reuse from pool)
---------------------------------------------------------------------------
function AuraControl:Acquire(parentFrame)
    -- Try to reuse from pool
    local ctrl = table.remove(parentFrame.inactivePool)
    if ctrl then
        ctrl.parentFrame = parentFrame
        ctrl:Configure(Addon.db.groups[parentFrame.groupId])
        return ctrl
    end

    -- Create new control
    controlCount = controlCount + 1
    local name = 'NdgBuffs_Aura' .. controlCount
    local db = Addon.db.groups[parentFrame.groupId]
    local size = db.size

    local ctrl = WINDOW_MANAGER:CreateControl(name, parentFrame, CT_CONTROL)
    ctrl.controlId   = controlCount
    ctrl.parentFrame = parentFrame

    -- Icon texture
    ctrl.icon = WINDOW_MANAGER:CreateControl(name .. '_Icon', ctrl, CT_TEXTURE)
    ctrl.icon:SetDimensions(size, size)
    ctrl.icon:SetAnchor(LEFT, ctrl, LEFT, 0, 0)

    -- Timer label (overlaid on icon or placed after name)
    ctrl.timer = WINDOW_MANAGER:CreateControl(name .. '_Timer', ctrl, CT_LABEL)
    ctrl.timer:SetFont('ZoFontGameSmall')
    ctrl.timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    ctrl.timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    ctrl.timer:SetColor(1, 1, 1, 1)

    -- Name label
    ctrl.nameLabel = WINDOW_MANAGER:CreateControl(name .. '_Name', ctrl, CT_LABEL)
    ctrl.nameLabel:SetFont('ZoFontGame')
    ctrl.nameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    ctrl.nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    ctrl.nameLabel:SetColor(1, 1, 1, 1)

    -- Attach methods
    ctrl.Initialize       = AuraControl.Initialize
    ctrl.Configure        = AuraControl.Configure
    ctrl.Update           = AuraControl.Update
    ctrl.UpdateTimerLabel = AuraControl.UpdateTimerLabel
    ctrl.Release          = AuraControl.Release

    ctrl:Configure(db)
    return ctrl
end

---------------------------------------------------------------------------
-- Configure layout based on display mode and size
---------------------------------------------------------------------------
function AuraControl:Configure(db)
    local size = db.size
    local mode = db.displayMode

    self.icon:ClearAnchors()
    self.timer:ClearAnchors()
    self.nameLabel:ClearAnchors()

    self.icon:SetDimensions(size, size)

    if mode == Addon.DISPLAY_ICON then
        -- Icon only: square control, timer centered on icon, no name
        self:SetDimensions(size, size)
        self.icon:SetAnchor(LEFT, self, LEFT, 0, 0)
        self.icon:SetHidden(false)
        self.timer:SetAnchor(CENTER, self.icon, CENTER, 0, 0)
        self.timer:SetHidden(false)
        self.nameLabel:SetHidden(true)

    elseif mode == Addon.DISPLAY_TEXT then
        -- Text only: name + timer, no icon
        self:SetDimensions(200, size)
        self.icon:SetHidden(true)
        self.nameLabel:SetAnchor(LEFT, self, LEFT, 0, 0)
        self.nameLabel:SetHidden(false)
        self.timer:SetAnchor(RIGHT, self, RIGHT, 0, 0)
        self.timer:SetHidden(false)

    else -- DISPLAY_BOTH
        -- Icon + name + timer, text side configurable
        local textSide = db.textSide or Addon.TEXT_RIGHT
        self:SetDimensions(size + 4 + 200, size)
        self.icon:SetHidden(false)
        self.nameLabel:SetHidden(false)
        self.timer:SetHidden(false)

        if textSide == Addon.TEXT_LEFT then
            -- Text on left, icon on right
            self.nameLabel:SetAnchor(LEFT, self, LEFT, 0, 0)
            self.timer:SetAnchor(RIGHT, self.icon, LEFT, -4, 0)
            self.icon:SetAnchor(RIGHT, self, RIGHT, 0, 0)
        else
            -- Text on right, icon on left (default)
            self.icon:SetAnchor(LEFT, self, LEFT, 0, 0)
            self.nameLabel:SetAnchor(LEFT, self.icon, RIGHT, 4, 0)
            self.timer:SetAnchor(RIGHT, self, RIGHT, 0, 0)
        end
    end
end

---------------------------------------------------------------------------
-- Initialize with aura data and show
---------------------------------------------------------------------------
function AuraControl:Initialize(auraName, unitTag, beginTime, endTime, iconTexture, abilityId, stackCount, isReminder)
    self.auraName    = auraName
    self.unitTag     = unitTag
    self.start       = beginTime
    self.finish      = endTime
    self.abilityId   = abilityId
    self.stackCount  = stackCount or 0
    self.isReminder  = isReminder or false

    self.icon:SetTexture(iconTexture)

    local displayName = auraName
    if self.stackCount > 1 then
        displayName = auraName .. ' (' .. self.stackCount .. ')'
    end
    self.nameLabel:SetText(displayName)

    if self.isReminder then
        self.timer:SetText('')
    else
        -- Register for shared timer updates
        Addon.activeTimedAuras[self.controlId] = self
        self:UpdateTimerLabel(endTime - GetFrameTimeSeconds())
    end

    -- Register in global lookup
    if unitTag and abilityId then
        Addon.auraLookup[unitTag] = Addon.auraLookup[unitTag] or {}
        Addon.auraLookup[unitTag][abilityId] = self
    end

    self:SetHidden(false)
end

---------------------------------------------------------------------------
-- Update existing aura (timers, stacks)
---------------------------------------------------------------------------
function AuraControl:Update(beginTime, endTime, stackCount)
    self.start  = beginTime
    self.finish = endTime

    if stackCount and stackCount ~= self.stackCount then
        self.stackCount = stackCount
        local displayName = self.auraName
        if stackCount > 1 then
            displayName = self.auraName .. ' (' .. stackCount .. ')'
        end
        self.nameLabel:SetText(displayName)
    end
end

---------------------------------------------------------------------------
-- Update the timer label text
---------------------------------------------------------------------------
function AuraControl:UpdateTimerLabel(remaining)
    if remaining >= 3600 then
        local h = math.floor(remaining / 3600)
        local m = math.floor((remaining % 3600) / 60)
        self.timer:SetText(string.format('%dh %dm', h, m))
    elseif remaining >= 60 then
        local m = math.floor(remaining / 60)
        local s = math.floor(remaining % 60)
        self.timer:SetText(string.format('%dm %ds', m, s))
    elseif remaining >= 10 then
        self.timer:SetText(string.format('%ds', math.floor(remaining)))
    else
        self.timer:SetText(string.format('%.1fs', remaining))
    end
end

---------------------------------------------------------------------------
-- Release aura back to pool
---------------------------------------------------------------------------
function AuraControl:Release()
    self:SetHidden(true)

    -- Remove from shared timer
    Addon.activeTimedAuras[self.controlId] = nil

    -- Remove from global lookup
    if self.unitTag and self.abilityId then
        if Addon.auraLookup[self.unitTag] then
            Addon.auraLookup[self.unitTag][self.abilityId] = nil
        end
    end

    -- Remove from parent frame's active list
    local frame = self.parentFrame
    if frame then
        frame.auras[self.controlId] = nil

        -- Remove from sorted list
        for i, ctrl in ipairs(frame.aurasSorted) do
            if ctrl.controlId == self.controlId then
                table.remove(frame.aurasSorted, i)
                break
            end
        end

        -- Return to pool
        table.insert(frame.inactivePool, self)

        -- Re-layout remaining auras
        frame:UpdateLayout()
    end

    self.unitTag   = nil
    self.abilityId = nil
    self.auraName  = nil
    self.isReminder = false
end
