local Addon = NdgCrown

-- 2D HUD arrows orbiting the reticle, pointing toward their target.
-- Rotation/positioning math follows RdKGroupTool's Follow-The-Crown arrow.
-- Distance is shown by size (bigger = farther) and an optional meter label.
Addon.Arrow = {}
local Arrow = Addon.Arrow

local wm = GetWindowManager()
local TWO_PI = 2 * math.pi

local tlw
local arrows = {}   -- targetKey -> { texture, label }
local shown = {}    -- targetKey -> bool

local function NormalizeAngle(angle)
    while angle > math.pi do angle = angle - TWO_PI end
    while angle < -math.pi do angle = angle + TWO_PI end
    return angle
end

function Arrow.Initialize()
    tlw = wm:CreateTopLevelWindow('NdgCrownArrows')
    tlw:SetDimensions(0, 0)
    tlw:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    tlw:SetDrawLayer(DL_BACKGROUND)

    local fragment = ZO_HUDFadeSceneFragment:New(tlw, 0, 0)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)

    for _, target in ipairs(Addon.TARGETS) do
        local texture = wm:CreateControl(nil, tlw, CT_TEXTURE)
        texture:SetTexture(Addon.ARROW_TEXTURE)
        texture:SetHidden(true)

        local label = wm:CreateControl(nil, tlw, CT_LABEL)
        label:SetFont('ZoFontGameShadow')
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetAnchor(TOP, texture, BOTTOM, 0, -4)
        label:SetHidden(true)

        arrows[target.key] = { texture = texture, label = label }
        shown[target.key] = false
    end
end

-- Shared placement: rotation is the direction relative to the camera view
-- (0 = straight ahead), size in px, labelText nil hides the label.
local function PlaceArrow(targetKey, rotation, size, labelText, ageAlpha)
    local general = Addon.db.general
    local settings = Addon.db.targets[targetKey].arrow
    local arrow = arrows[targetKey]

    -- orbit position around the reticle
    local orbit = general.arrowRadius + size / 2
    local offsetX = math.sin(math.pi + rotation) * orbit
    local offsetY = math.cos(math.pi + rotation) * orbit

    local texture = arrow.texture
    texture:SetDimensions(size, size)
    texture:SetTextureRotation(rotation)
    texture:ClearAnchors()
    texture:SetAnchor(CENTER, tlw, CENTER, offsetX, offsetY)
    local color = settings.color
    texture:SetColor(color.r, color.g, color.b, ageAlpha)

    local label = arrow.label
    if labelText then
        label:SetText(labelText)
        label:SetColor(color.r, color.g, color.b, ageAlpha)
        label:SetHidden(false)
    else
        label:SetHidden(true)
    end

    if not shown[targetKey] then
        texture:SetHidden(false)
        shown[targetKey] = true
    end
end

-- distance in meters; rotation math needs the raw player->target world deltas
function Arrow.Show(targetKey, deltaX, deltaZ, distance, cameraHeading, ageAlpha)
    local general = Addon.db.general

    -- angle the arrow must point at, relative to the camera view
    local rotation = TWO_PI - NormalizeAngle(cameraHeading - math.atan2(deltaX, deltaZ))

    -- size grows with distance between min and max
    local range = math.max(1, general.arrowMaxDistance - general.arrowMinDistance)
    local t = (distance - general.arrowMinDistance) / range
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local size = (general.arrowSizeClose + (general.arrowSizeFar - general.arrowSizeClose) * t) * 2

    local labelText = general.showDistanceLabel and string.format('%.0fm', distance) or nil
    PlaceArrow(targetKey, rotation, size, labelText, ageAlpha)
end

-- Direction-only display from a compass bearing: the camera heading recorded
-- the last time the mark's compass pin crossed the compass center. Distance
-- is unknown, so the size is fixed and the label shows the bearing's age.
function Arrow.ShowBearing(targetKey, bearingHeading, cameraHeading, ageSeconds, ageAlpha)
    local general = Addon.db.general
    local rotation = TWO_PI - NormalizeAngle(cameraHeading - bearingHeading)
    local size = general.arrowSizeClose + general.arrowSizeFar
    local labelText = general.showDistanceLabel and string.format('%.0fs', ageSeconds) or nil
    PlaceArrow(targetKey, rotation, size, labelText, ageAlpha)
end

function Arrow.Hide(targetKey)
    if shown[targetKey] then
        arrows[targetKey].texture:SetHidden(true)
        arrows[targetKey].label:SetHidden(true)
        shown[targetKey] = false
    end
end

function Arrow.HideAll()
    for targetKey in pairs(arrows) do
        Arrow.Hide(targetKey)
    end
end
