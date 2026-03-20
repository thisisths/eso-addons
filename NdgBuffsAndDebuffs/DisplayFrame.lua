local Addon = _G['NdgBuffsAndDebuffs']

local DisplayFrame = {}
Addon.DisplayFrame = DisplayFrame

---------------------------------------------------------------------------
-- Create a display frame for a given group
---------------------------------------------------------------------------
function DisplayFrame:Create(groupId)
    local db  = Addon.db.groups[groupId]
    local pos = db.position
    local name = 'NdgBuffs_Frame' .. groupId

    local frame = WINDOW_MANAGER:CreateTopLevelWindow(name)
    frame:SetKeyboardEnabled(false)
    frame:SetMouseEnabled(false)
    frame:SetMovable(false)
    frame:SetClampedToScreen(true)
    frame:SetDimensions(db.size, db.size)
    frame:ClearAnchors()
    frame:SetAnchor(pos.point, GuiRoot, pos.point, pos.x, pos.y)

    frame.groupId      = groupId
    frame.auras        = {}      -- controlId -> auraControl
    frame.aurasSorted  = {}      -- ordered array for layout
    frame.inactivePool = {}      -- recycled controls
    frame.dragOverlay  = nil     -- created lazily on unlock
    frame.burstMode    = false   -- suppress layout during batch adds

    -- Attach methods
    frame.AddAura      = DisplayFrame.AddAura
    frame.AddReminder  = DisplayFrame.AddReminder
    frame.RemoveAura   = DisplayFrame.RemoveAura
    frame.UpdateLayout = DisplayFrame.UpdateLayout
    frame.EnableDrag   = DisplayFrame.EnableDrag
    frame.DisableDrag  = DisplayFrame.DisableDrag
    frame.ReleaseAll   = DisplayFrame.ReleaseAll

    -- Position save handler (fires when dragging ends)
    frame:SetHandler('OnMoveStop', function(f)
        local point, x, y = Addon:GetEdgeRelativePosition(f)
        Addon.db.groups[groupId].position.point = point
        Addon.db.groups[groupId].position.x = x
        Addon.db.groups[groupId].position.y = y
    end)

    return frame
end

---------------------------------------------------------------------------
-- Add a timed aura to this frame
---------------------------------------------------------------------------
function DisplayFrame:AddAura(auraName, unitTag, beginTime, endTime, iconTexture, abilityId, stackCount)
    local ctrl = Addon.AuraControl:Acquire(self)
    ctrl:Initialize(auraName, unitTag, beginTime, endTime, iconTexture, abilityId, stackCount, false)

    self.auras[ctrl.controlId] = ctrl
    table.insert(self.aurasSorted, ctrl)

    if not self.burstMode then
        self:UpdateLayout()
    end

    return ctrl
end

---------------------------------------------------------------------------
-- Add a reminder (permanent, no timer) aura
---------------------------------------------------------------------------
function DisplayFrame:AddReminder(reminderKey, displayName, iconTexture)
    local ctrl = Addon.AuraControl:Acquire(self)
    ctrl:Initialize(displayName, nil, 0, 0, iconTexture, nil, 0, true)
    ctrl.reminderKey = reminderKey

    self.auras[ctrl.controlId] = ctrl
    table.insert(self.aurasSorted, ctrl)

    if not self.burstMode then
        self:UpdateLayout()
    end

    return ctrl
end

---------------------------------------------------------------------------
-- Release all auras from this frame
---------------------------------------------------------------------------
function DisplayFrame:ReleaseAll()
    -- Copy keys to avoid modifying table during iteration
    local ids = {}
    for controlId in pairs(self.auras) do
        table.insert(ids, controlId)
    end
    for _, controlId in ipairs(ids) do
        local aura = self.auras[controlId]
        if aura then aura:Release() end
    end
end

---------------------------------------------------------------------------
-- Update layout – sort and position all active auras
---------------------------------------------------------------------------
function DisplayFrame:UpdateLayout()
    local db      = Addon.db.groups[self.groupId]
    local growth  = db.growth
    local size    = db.size
    local padding = 4

    -- Sort: reminders first, then by remaining time (ascending)
    local now = GetFrameTimeSeconds()
    table.sort(self.aurasSorted, function(a, b)
        -- Reminders always sort first
        if a.isReminder and not b.isReminder then return true end
        if not a.isReminder and b.isReminder then return false end
        -- Both reminders: alphabetical
        if a.isReminder and b.isReminder then
            return (a.auraName or '') < (b.auraName or '')
        end
        -- Both timed: ascending remaining time
        return (a.finish - now) < (b.finish - now)
    end)

    -- Compute effective entry size based on display mode
    local entryW, entryH
    if db.displayMode == Addon.DISPLAY_ICON then
        entryW = size
        entryH = size
    elseif db.displayMode == Addon.DISPLAY_TEXT then
        entryW = 200
        entryH = size
    else -- DISPLAY_BOTH
        entryW = size + 4 + 200
        entryH = size
    end

    -- When text is on the left in Both mode, anchor from the right side
    -- so the icon stays at the frame position and text expands leftward
    local anchorRight = (db.displayMode == Addon.DISPLAY_BOTH and db.textSide == Addon.TEXT_LEFT)

    for i, aura in ipairs(self.aurasSorted) do
        aura:ClearAnchors()
        local offset = (i - 1) * (((growth == Addon.GROW_LEFT or growth == Addon.GROW_RIGHT) and entryW or entryH) + padding)

        if growth == Addon.GROW_UP then
            if anchorRight then
                aura:SetAnchor(BOTTOMRIGHT, self, BOTTOMRIGHT, 0, -offset)
            else
                aura:SetAnchor(BOTTOMLEFT, self, BOTTOMLEFT, 0, -offset)
            end
        elseif growth == Addon.GROW_DOWN then
            if anchorRight then
                aura:SetAnchor(TOPRIGHT, self, TOPRIGHT, 0, offset)
            else
                aura:SetAnchor(TOPLEFT, self, TOPLEFT, 0, offset)
            end
        elseif growth == Addon.GROW_LEFT then
            aura:SetAnchor(TOPRIGHT, self, TOPRIGHT, -offset, 0)
        elseif growth == Addon.GROW_RIGHT then
            if anchorRight then
                aura:SetAnchor(TOPRIGHT, self, TOPRIGHT, offset, 0)
            else
                aura:SetAnchor(TOPLEFT, self, TOPLEFT, offset, 0)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Enable dragging (unlock mode)
---------------------------------------------------------------------------
function DisplayFrame:EnableDrag()
    self:SetMouseEnabled(true)
    self:SetMovable(true)

    -- Create drag overlay lazily
    if not self.dragOverlay then
        local overlayName = self:GetName() .. '_Overlay'
        local overlay = WINDOW_MANAGER:CreateControl(overlayName, self, CT_BACKDROP)
        overlay:SetAnchorFill(self)
        overlay:SetCenterColor(0.2, 0.2, 0.2, 0.6)
        overlay:SetEdgeColor(0.8, 0.6, 0.2, 0.8)
        overlay:SetEdgeTexture('', 1, 1, 1)

        local label = WINDOW_MANAGER:CreateControl(overlayName .. '_Label', overlay, CT_LABEL)
        label:SetFont('ZoFontGame')
        label:SetText(Addon.GROUP_NAMES[self.groupId])
        label:SetColor(1, 1, 1, 1)
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetAnchor(CENTER, overlay, CENTER, 0, 0)

        self.dragOverlay = overlay

        -- Make overlay large enough to be draggable
        self:SetDimensions(math.max(self:GetWidth(), 150), math.max(self:GetHeight(), 40))
    end

    self.dragOverlay:SetHidden(false)
    self:SetHidden(false)
end

---------------------------------------------------------------------------
-- Disable dragging (lock mode)
---------------------------------------------------------------------------
function DisplayFrame:DisableDrag()
    self:SetMouseEnabled(false)
    self:SetMovable(false)

    if self.dragOverlay then
        self.dragOverlay:SetHidden(true)
    end

    -- Restore proper dimensions
    local db = Addon.db.groups[self.groupId]
    self:SetDimensions(db.size, db.size)

    -- Respect enabled setting
    if not db.enabled then
        self:SetHidden(true)
    end
end
