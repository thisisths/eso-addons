local Addon = NdgUrge

-- The on-screen warning text. Its top-level window is anchored by its center,
-- so the text stays centered while the distance in it changes, and it is
-- only visible with the HUD. Unlocked, it shows a preview text over a
-- backdrop and can be dragged; the new position is saved when the drag ends.
Addon.Warning = {}
local Warning = Addon.Warning

local wm = GetWindowManager()

local SAMPLE_METERS = 999   -- widest expected text; sizes the window (= drag area)
local PADDING = 10          -- px around the text

local tlw, label, backdrop
local shown = false
local unlocked = false
local lastMeters            -- distance currently in the label; nil = text must be set

local function FormatText(meters)
    if Addon.db.showDistance then
        return string.format('%s (%dm)', Addon.TEXT, meters)
    end
    return Addon.TEXT
end

local function SetMeters(meters)
    if meters ~= lastMeters then
        lastMeters = meters
        label:SetText(FormatText(meters))
    end
end

local function ApplyPosition()
    local position = Addon.db.position
    tlw:ClearAnchors()
    tlw:SetAnchor(CENTER, GuiRoot, CENTER, position.x, position.y)
end

local function SavePosition()
    local centerX, centerY = tlw:GetCenter()
    local screenWidth, screenHeight = GuiRoot:GetDimensions()
    local position = Addon.db.position
    position.x = zo_round(centerX - screenWidth / 2)
    position.y = zo_round(centerY - screenHeight / 2)
    -- dragging may leave the window anchored differently; go back to center
    ApplyPosition()
end

function Warning.Initialize()
    tlw = wm:CreateTopLevelWindow('NdgUrgeWarning')
    tlw:SetClampedToScreen(true)
    tlw:SetMouseEnabled(false)
    tlw:SetMovable(false)
    tlw:SetHandler('OnMoveStop', SavePosition)

    backdrop = wm:CreateControl(nil, tlw, CT_BACKDROP)
    backdrop:SetAnchorFill(tlw)
    backdrop:SetCenterColor(0.2, 0.2, 0.2, 0.6)
    backdrop:SetEdgeColor(0.8, 0.6, 0.2, 0.8)
    backdrop:SetEdgeTexture('', 1, 1, 1)
    backdrop:SetDrawLevel(0)
    backdrop:SetHidden(true)

    label = wm:CreateControl(nil, tlw, CT_LABEL)
    label:SetAnchor(CENTER, tlw, CENTER, 0, 0)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetDrawLevel(1)
    label:SetHidden(true)

    local fragment = ZO_HUDFadeSceneFragment:New(tlw, 0, 0)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)

    ApplyPosition()
    Warning.ApplyStyle()
end

-- Font, color and window size. Called on startup and when a style setting changes.
function Warning.ApplyStyle()
    local db = Addon.db
    label:SetFont(string.format('$(BOLD_FONT)|%d|soft-shadow-thick', db.fontSize))
    label:SetColor(db.color.r, db.color.g, db.color.b, 1)

    -- size the window for the widest expected text, so the drag area
    -- doesn't change with the distance
    label:SetText(FormatText(SAMPLE_METERS))
    local width, height = label:GetTextDimensions()
    tlw:SetDimensions(width + 2 * PADDING, height + 2 * PADDING)

    lastMeters = nil
    if unlocked then
        SetMeters(db.maxDistance + 5)
    end
end

-- distance in meters
function Warning.Show(distance)
    if unlocked then return end
    SetMeters(zo_round(distance))
    if not shown then
        label:SetHidden(false)
        shown = true
    end
end

function Warning.Hide()
    if unlocked then return end
    if shown then
        label:SetHidden(true)
        shown = false
    end
end

function Warning.IsShown()
    return shown
end

function Warning.IsUnlocked()
    return unlocked
end

-- Unlocked: always visible (preview text) and draggable. Locking hides it;
-- the next update shows it again if you are actually too far away.
function Warning.SetUnlocked(value)
    unlocked = value
    tlw:SetMouseEnabled(value)
    tlw:SetMovable(value)
    backdrop:SetHidden(not value)
    lastMeters = nil
    if value then
        SetMeters(Addon.db.maxDistance + 5)
        label:SetHidden(false)
        shown = true
    else
        label:SetHidden(true)
        shown = false
    end
end
