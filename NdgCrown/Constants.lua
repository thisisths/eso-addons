-- First file loaded: creates the addon namespace all other files attach to.
NdgCrown = NdgCrown or {}
local Addon = NdgCrown

Addon.NAME       = 'NdgCrown'
Addon.SLASH      = '/ndgcrown'
Addon.VERSION    = '0.4.0'   -- keep in sync with ## Version in the manifest
Addon.DB_VERSION = 1         -- bumping this WIPES saved variables

Addon.BEAM_TEXTURE  = 'NdgCrown/Art/beam.dds'
Addon.ARROW_TEXTURE = 'NdgCrown/Art/arrow.dds'

-- The tracked targets: the group leader plus the 8 base-game target markers.
-- key is used for saved variables and controls; markerType is the game constant
-- (nil for the leader). color is the default beam/arrow tint, roughly matching
-- the base-game marker icon color.
Addon.TARGETS = {
    { key = 'leader', name = 'Group Leader',
      icon = 'EsoUI/Art/Compass/groupLeader.dds',
      color = { r = 0,    g = 0.5,  b = 1    } },
    { key = 'mark1', markerType = TARGET_MARKER_TYPE_ONE,   name = 'Blue Square',
      icon = 'EsoUI/Art/TargetMarkers/Target_Blue_Square_64.dds',
      color = { r = 0.2,  g = 0.55, b = 1    } },
    { key = 'mark2', markerType = TARGET_MARKER_TYPE_TWO,   name = 'Gold Star',
      icon = 'EsoUI/Art/TargetMarkers/Target_Gold_Star_64.dds',
      color = { r = 1,    g = 0.84, b = 0.2  } },
    { key = 'mark3', markerType = TARGET_MARKER_TYPE_THREE, name = 'Green Circle',
      icon = 'EsoUI/Art/TargetMarkers/Target_Green_Circle_64.dds',
      color = { r = 0.3,  g = 0.9,  b = 0.3  } },
    { key = 'mark4', markerType = TARGET_MARKER_TYPE_FOUR,  name = 'Orange Triangle',
      icon = 'EsoUI/Art/TargetMarkers/Target_Orange_Triangle_64.dds',
      color = { r = 1,    g = 0.55, b = 0.15 } },
    { key = 'mark5', markerType = TARGET_MARKER_TYPE_FIVE,  name = 'Pink Moons',
      icon = 'EsoUI/Art/TargetMarkers/Target_Pink_Moons_64.dds',
      color = { r = 1,    g = 0.45, b = 0.75 } },
    { key = 'mark6', markerType = TARGET_MARKER_TYPE_SIX,   name = 'Purple Oblivion',
      icon = 'EsoUI/Art/TargetMarkers/Target_Purple_Oblivion_64.dds',
      color = { r = 0.7,  g = 0.35, b = 1    } },
    { key = 'mark7', markerType = TARGET_MARKER_TYPE_SEVEN, name = 'Red Weapons',
      icon = 'EsoUI/Art/TargetMarkers/Target_Red_Weapons_64.dds',
      color = { r = 1,    g = 0.25, b = 0.25 } },
    { key = 'mark8', markerType = TARGET_MARKER_TYPE_EIGHT, name = 'White Skull',
      icon = 'EsoUI/Art/TargetMarkers/Target_White_Skull_64.dds',
      color = { r = 1,    g = 1,    b = 1    } },
}

-- markerType -> target definition, for the tracker
Addon.TARGET_BY_MARKER = {}
for _, target in ipairs(Addon.TARGETS) do
    if target.markerType then
        Addon.TARGET_BY_MARKER[target.markerType] = target
    end
end
