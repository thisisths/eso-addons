local Addon = NdgCrown

-- Range rings lying flat on the ground around a target (or the player).
-- Same technique as the beams, but pitched -90 degrees so the texture lies
-- flat, and sized to the ring diameter. Lives in the same 2D world window.
Addon.Ring = {}
local Ring = Addon.Ring

local wm = GetWindowManager()
local GROUND_OFFSET_CM = 5   -- keep the ring from z-fighting with the ground

local controls = {}   -- ringKey -> texture control
local shown = {}      -- ringKey -> bool
local diameters = {}  -- ringKey -> last applied diameter (m)

-- Ring keys: 'self' plus every target key
Addon.RING_KEYS = { 'self' }
for _, target in ipairs(Addon.TARGETS) do
    table.insert(Addon.RING_KEYS, target.key)
end

function Ring.Initialize()
    local window = Addon.GetWorldWindow()
    for _, key in ipairs(Addon.RING_KEYS) do
        local control = wm:CreateControl(nil, window, CT_TEXTURE)
        control:SetTexture(Addon.RING_TEXTURE)
        control:Create3DRenderSpace()
        control:Set3DRenderSpaceOrientation(-math.pi / 2, 0, 0)
        control:SetHidden(true)
        controls[key] = control
        shown[key] = false
    end
    Ring.ApplySettings()
end

function Ring.ApplySettings()
    local general = Addon.db.general
    for _, control in pairs(controls) do
        control:Set3DRenderSpaceUsesDepthBuffer(not general.ringThroughTerrain)
    end
end

-- worldX/Y/Z in cm, radius in m, color a {r,g,b} table
function Ring.Show(ringKey, worldX, worldY, worldZ, radius, color)
    local control = controls[ringKey]
    local diameter = radius * 2
    if diameters[ringKey] ~= diameter then
        control:Set3DLocalDimensions(diameter, diameter)
        diameters[ringKey] = diameter
    end
    control:Set3DRenderSpaceOrigin(WorldPositionToGuiRender3DPosition(worldX, worldY + GROUND_OFFSET_CM, worldZ))
    control:SetColor(color.r, color.g, color.b, Addon.db.general.ringAlpha / 100)
    if not shown[ringKey] then
        control:SetHidden(false)
        shown[ringKey] = true
    end
end

function Ring.Hide(ringKey)
    if shown[ringKey] then
        controls[ringKey]:SetHidden(true)
        shown[ringKey] = false
    end
end

function Ring.HideAll()
    for ringKey in pairs(controls) do
        Ring.Hide(ringKey)
    end
end
