local Addon = NdgCrown

-- 3D light beams rendered at target world positions.
-- Technique (same as CombatAlerts): CT_TEXTURE controls, each with its own 3D
-- render space; origin set from WorldPositionToGuiRender3DPosition every
-- frame, yaw-billboarded toward the camera.
--
-- The parent window must NOT have a 3D render space itself: the game moves
-- 3D render-space origins whenever its floating world origin shifts (often,
-- while travelling through Cyrodiil). A 3D parent would get shifted and offset
-- our absolute child coordinates a second time - beams ended up far away.
Addon.Beam = {}
local Beam = Addon.Beam

local wm = GetWindowManager()
local tlw
local controls = {}   -- targetKey -> texture control
local shown = {}      -- targetKey -> bool

-- Shared by Beam and Ring: a plain 2D window that hides with the HUD.
function Addon.GetWorldWindow()
    if not tlw then
        tlw = wm:CreateTopLevelWindow('NdgCrownWorld')
        tlw:SetAnchorFill(GuiRoot)
        tlw:SetDrawTier(DT_LOW)
        tlw:SetDrawLayer(DL_BACKGROUND)
        tlw:SetMouseEnabled(false)

        -- hide with the HUD (menus, map, ...)
        local fragment = ZO_HUDFadeSceneFragment:New(tlw, 0, 0)
        HUD_SCENE:AddFragment(fragment)
        HUD_UI_SCENE:AddFragment(fragment)
    end
    return tlw
end

function Beam.Initialize()
    local window = Addon.GetWorldWindow()
    for _, target in ipairs(Addon.TARGETS) do
        local control = wm:CreateControl(nil, window, CT_TEXTURE)
        control:SetTexture(Addon.BEAM_TEXTURE)
        control:Create3DRenderSpace()
        control:SetHidden(true)
        controls[target.key] = control
        shown[target.key] = false
    end
    Beam.ApplySettings()
end

function Beam.ApplySettings()
    local general = Addon.db.general
    for _, control in pairs(controls) do
        control:Set3DLocalDimensions(general.beamWidth, general.beamHeight)
        control:Set3DRenderSpaceUsesDepthBuffer(not general.beamThroughTerrain)
    end
end

-- worldX/Y/Z in cm (GetUnitWorldPosition units), ageAlpha 0..1
function Beam.Show(targetKey, worldX, worldY, worldZ, cameraHeading, ageAlpha)
    local control = controls[targetKey]
    local settings = Addon.db.targets[targetKey].beam
    local general = Addon.db.general
    -- the render-space origin is the control's center: lift it by half the
    -- beam height (m -> cm) so the beam stands on the ground
    local x, y, z = WorldPositionToGuiRender3DPosition(worldX, worldY + general.beamHeight * 50, worldZ)
    control:Set3DRenderSpaceOrigin(x, y, z)
    control:Set3DRenderSpaceOrientation(0, cameraHeading, 0)
    local color = settings.color
    control:SetColor(color.r, color.g, color.b, (general.beamAlpha / 100) * ageAlpha)
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

-- for the beam probe
function Beam.GetControl(targetKey)
    return controls[targetKey]
end
