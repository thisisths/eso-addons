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

    for i, target in ipairs(Addon.TARGETS) do
        local texture = wm:CreateControl(nil, tlw, CT_TEXTURE)
        texture:SetTexture(Addon.ARROW_TEXTURE)
        texture:SetHidden(true)

        local label = wm:CreateControl(nil, tlw, CT_LABEL)
        label:SetFont('ZoFontGameShadow')
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetAnchor(TOP, texture, BOTTOM, 0, -4)
        label:SetHidden(true)

        -- when arrows overlap, the leader (crown) arrow must draw on top of
        -- the mark arrows; each label sits above its own texture because it
        -- is created later at the same draw level
        local drawLevel = target.key == 'leader' and 100 or i
        texture:SetDrawLevel(drawLevel)
        label:SetDrawLevel(drawLevel)

        arrows[target.key] = { texture = texture, label = label }
        shown[target.key] = false
    end
end

-- distance in meters; rotation math needs the raw player->target world deltas
function Arrow.Show(targetKey, deltaX, deltaZ, distance, cameraHeading)
    local general = Addon.db.general
    local settings = Addon.db.targets[targetKey].arrow
    local arrow = arrows[targetKey]

    -- per-target override replaces the global size/distance values
    local sizeClose, sizeFar, minDistance, maxDistance, radius
    if settings.override then
        sizeClose, sizeFar = settings.sizeClose, settings.sizeFar
        minDistance, maxDistance = settings.minDistance, settings.maxDistance
        radius = settings.radius
    else
        sizeClose, sizeFar = general.arrowSizeClose, general.arrowSizeFar
        minDistance, maxDistance = general.arrowMinDistance, general.arrowMaxDistance
        radius = general.arrowRadius
    end

    -- angle the arrow must point at, relative to the camera view
    local rotation = TWO_PI - NormalizeAngle(cameraHeading - math.atan2(deltaX, deltaZ))

    -- size grows with distance between min and max
    local range = math.max(1, maxDistance - minDistance)
    local t = (distance - minDistance) / range
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local size = (sizeClose + (sizeFar - sizeClose) * t) * 2

    -- orbit position around the reticle
    local orbit = radius + size / 2
    local offsetX = math.sin(math.pi + rotation) * orbit
    local offsetY = math.cos(math.pi + rotation) * orbit

    local texture = arrow.texture
    texture:SetDimensions(size, size)
    texture:SetTextureRotation(rotation)
    texture:ClearAnchors()
    texture:SetAnchor(CENTER, tlw, CENTER, offsetX, offsetY)
    local color = settings.color
    texture:SetColor(color.r, color.g, color.b, 1)

    local label = arrow.label
    if general.showDistanceLabel then
        label:SetText(string.format('%.0fm', distance))
        label:SetColor(color.r, color.g, color.b, 1)
        label:SetHidden(false)
    else
        label:SetHidden(true)
    end

    if not shown[targetKey] then
        texture:SetHidden(false)
        shown[targetKey] = true
    end
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
