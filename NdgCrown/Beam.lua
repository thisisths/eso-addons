local Addon = NdgCrown

-- 3D light beams rendered at target world positions.
-- Technique (same as RdKGroupTool / CombatAlerts): a CT_TEXTURE control with a
-- 3D render space; origin set from WorldPositionToGuiRender3DPosition every
-- tick, yaw-billboarded toward the camera.
Addon.Beam = {}
local Beam = Addon.Beam

local wm = GetWindowManager()
local tlw
local controls = {}   -- targetKey -> texture control
local shown = {}      -- targetKey -> bool

function Beam.Initialize()
    tlw = wm:CreateTopLevelWindow('NdgCrownBeams')
    tlw:Create3DRenderSpace()
    tlw:SetDrawTier(DT_LOW)
    tlw:SetDrawLayer(DL_BACKGROUND)

    -- hide with the HUD (menus, map, ...)
    local fragment = ZO_HUDFadeSceneFragment:New(tlw, 0, 0)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)

    for _, target in ipairs(Addon.TARGETS) do
        local control = wm:CreateControl(nil, tlw, CT_TEXTURE)
        control:SetTexture(Addon.BEAM_TEXTURE)
        control:Create3DRenderSpace()
        control:Set3DRenderSpaceUsesDepthBuffer(true)
        control:SetHidden(true)
        controls[target.key] = control
        shown[target.key] = false
    end
    Beam.ApplyDimensions()
end

function Beam.ApplyDimensions()
    local general = Addon.db.general
    for _, control in pairs(controls) do
        control:Set3DLocalDimensions(general.beamWidth, general.beamHeight)
    end
end

-- worldX/Y/Z in cm (GetUnitWorldPosition units), ageAlpha 0..1
function Beam.Show(targetKey, worldX, worldY, worldZ, cameraHeading, ageAlpha)
    local control = controls[targetKey]
    local settings = Addon.db.targets[targetKey].beam
    local x, y, z = WorldPositionToGuiRender3DPosition(worldX, worldY, worldZ)
    control:Set3DRenderSpaceOrigin(x, y, z)
    control:Set3DRenderSpaceOrientation(0, cameraHeading, 0)
    local color = settings.color
    control:SetColor(color.r, color.g, color.b, (Addon.db.general.beamAlpha / 100) * ageAlpha)
    if not shown[targetKey] then
        control:SetHidden(false)
        shown[targetKey] = true
    end
end

function Beam.Hide(targetKey)
    if shown[targetKey] then
        controls[targetKey]:SetHidden(true)
        shown[targetKey] = false
    end
end

function Beam.HideAll()
    for targetKey in pairs(controls) do
        Beam.Hide(targetKey)
    end
end
