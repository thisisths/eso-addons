local Addon = _G['NdgBuffsAndDebuffs']
local LAM = LibAddonMenu2

local Settings = {}
Addon.Settings = Settings

---------------------------------------------------------------------------
-- Display mode and growth lookup tables
---------------------------------------------------------------------------
local displayModeChoices = { 'Icon', 'Text', 'Both' }
local displayModeToValue = { ['Icon'] = 1, ['Text'] = 2, ['Both'] = 3 }
local displayValueToName = { [1] = 'Icon', [2] = 'Text', [3] = 'Both' }

local growthChoicesAll = { 'Bottom to Top', 'Top to Bottom', 'Left to Right', 'Right to Left' }
local growthChoicesVertical = { 'Bottom to Top', 'Top to Bottom' }

local textSideChoices = { 'Right', 'Left' }
local textSideNameToValue = { ['Right'] = Addon.TEXT_RIGHT, ['Left'] = Addon.TEXT_LEFT }
local textSideValueToName = { [Addon.TEXT_RIGHT] = 'Right', [Addon.TEXT_LEFT] = 'Left' }

local growthNameToValue = {
    ['Bottom to Top']  = Addon.GROW_UP,
    ['Top to Bottom']  = Addon.GROW_DOWN,
    ['Left to Right']  = Addon.GROW_RIGHT,
    ['Right to Left']  = Addon.GROW_LEFT,
}
local growthValueToName = {
    [Addon.GROW_UP]    = 'Bottom to Top',
    [Addon.GROW_DOWN]  = 'Top to Bottom',
    [Addon.GROW_RIGHT] = 'Left to Right',
    [Addon.GROW_LEFT]  = 'Right to Left',
}

---------------------------------------------------------------------------
-- Initialize the LAM2 settings panel
---------------------------------------------------------------------------
function Settings:Initialize()
    local panelData = {
        type                = 'panel',
        name                = 'NdgBuffsAndDebuffs',
        displayName         = 'Ndg Buffs & Debuffs',
        author              = 'Ndg',
        version             = Addon.VERSION,
        slashCommand        = '/ndgbuffs settings',
        registerForRefresh  = true,
        registerForDefaults = true,
    }

    LAM:RegisterAddonPanel('NdgBuffsAndDebuffs_Settings', panelData)

    local optionsData = {}

    -- =====================================================================
    -- General Settings
    -- =====================================================================
    table.insert(optionsData, {
        type = 'header',
        name = 'General Settings',
    })

    table.insert(optionsData, {
        type    = 'button',
        name    = function()
            if Addon.db.locked then
                return 'Unlock Frames'
            else
                return 'Lock Frames'
            end
        end,
        tooltip = 'Toggle lock/unlock to reposition display groups by dragging.',
        func    = function()
            if Addon.db.locked then
                Addon:UnlockFrames()
            else
                Addon:LockFrames()
            end
        end,
        width   = 'half',
    })

    table.insert(optionsData, {
        type    = 'slider',
        name    = 'Short Buff Threshold (seconds)',
        tooltip = 'Buffs with duration below this value are shown in the Short Duration group. Buffs at or above go to the Long Duration group.',
        min     = 5,
        max     = 120,
        step    = 5,
        getFunc = function() return Addon.db.shortBuffThreshold end,
        setFunc = function(val) Addon.db.shortBuffThreshold = val end,
        default = Addon.defaults.shortBuffThreshold,
    })

    -- =====================================================================
    -- Per-Group Settings (each in a submenu)
    -- =====================================================================
    for groupId = 1, Addon.NUM_GROUPS do
        local gdef = Addon.defaults.groups[groupId]
        local controls = {}

        -- Enabled checkbox
        table.insert(controls, {
            type    = 'checkbox',
            name    = 'Enabled',
            tooltip = 'Enable or disable this display group.',
            getFunc = function() return Addon.db.groups[groupId].enabled end,
            setFunc = function(val)
                Addon.db.groups[groupId].enabled = val
                local frame = Addon.displayFrames[groupId]
                if frame then frame:SetHidden(not val) end
            end,
            default = gdef.enabled,
        })

        -- Display mode dropdown
        table.insert(controls, {
            type    = 'dropdown',
            name    = 'Display Mode',
            tooltip = 'Choose how auras are displayed: icon only, text only, or both.',
            choices = displayModeChoices,
            getFunc = function()
                return displayValueToName[Addon.db.groups[groupId].displayMode]
            end,
            setFunc = function(val)
                Addon.db.groups[groupId].displayMode = displayModeToValue[val]
                Addon:ReconfigureGroup(groupId)
            end,
            default = displayValueToName[gdef.displayMode],
        })

        -- Size slider
        table.insert(controls, {
            type    = 'slider',
            name    = 'Size',
            tooltip = 'Size of aura icons and entries in pixels.',
            min     = 20,
            max     = 80,
            step    = 2,
            getFunc = function() return Addon.db.groups[groupId].size end,
            setFunc = function(val)
                Addon.db.groups[groupId].size = val
                Addon:ReconfigureGroup(groupId)
            end,
            default = gdef.size,
        })

        -- Ordering dropdown
        table.insert(controls, {
            type    = 'dropdown',
            name    = 'Ordering',
            tooltip = 'Direction in which auras stack: Bottom to Top, Top to Bottom, Left to Right, or Right to Left.',
            choices = growthChoicesAll,
            getFunc = function()
                return growthValueToName[Addon.db.groups[groupId].growth]
            end,
            setFunc = function(val)
                Addon.db.groups[groupId].growth = growthNameToValue[val]
                Addon:ReconfigureGroup(groupId)
            end,
            default = growthValueToName[gdef.growth],
        })

        -- Text position dropdown (only active in Both mode)
        table.insert(controls, {
            type     = 'dropdown',
            name     = 'Text Position',
            tooltip  = 'Position of the text relative to the icon. Only applies when Display Mode is set to Both.',
            choices  = textSideChoices,
            getFunc  = function()
                return textSideValueToName[Addon.db.groups[groupId].textSide or Addon.TEXT_RIGHT]
            end,
            setFunc  = function(val)
                Addon.db.groups[groupId].textSide = textSideNameToValue[val]
                Addon:ReconfigureGroup(groupId)
            end,
            disabled = function()
                return Addon.db.groups[groupId].displayMode ~= Addon.DISPLAY_BOTH
            end,
            default  = textSideValueToName[gdef.textSide],
        })

        -- Group-specific filter controls
        if groupId == Addon.GROUP_REMINDER then
            -- Reminder group: individual disable flags
            table.insert(controls, {
                type    = 'checkbox',
                name    = 'Disable Ultimate Reminder',
                tooltip = 'Hide the "Ultimate Ready" reminder.',
                getFunc = function() return Addon.db.groups[groupId].disableUltimate end,
                setFunc = function(val) Addon.db.groups[groupId].disableUltimate = val end,
                default = gdef.disableUltimate,
            })
            table.insert(controls, {
                type    = 'checkbox',
                name    = 'Disable Food/Drink Reminder',
                tooltip = 'Hide the "No Food Buff" reminder.',
                getFunc = function() return Addon.db.groups[groupId].disableFood end,
                setFunc = function(val) Addon.db.groups[groupId].disableFood = val end,
                default = gdef.disableFood,
            })
            table.insert(controls, {
                type    = 'checkbox',
                name    = 'Disable Potion Reminder',
                tooltip = 'Hide the "Potion Ready" reminder.',
                getFunc = function() return Addon.db.groups[groupId].disablePotion end,
                setFunc = function(val) Addon.db.groups[groupId].disablePotion = val end,
                default = gdef.disablePotion,
            })
        else
            -- Buff/debuff groups: blacklist editbox
            table.insert(controls, {
                type       = 'editbox',
                name       = 'Hidden Buffs/Debuffs',
                tooltip    = 'Enter buff or debuff names to hide, one per line. Names are case-insensitive.',
                isMultiline = true,
                isExtraWide = true,
                getFunc    = function() return Addon.db.groups[groupId].blacklist or '' end,
                setFunc    = function(val)
                    Addon.db.groups[groupId].blacklist = val
                    Addon.RebuildBlacklist(groupId)
                end,
                default    = gdef.blacklist,
            })
        end

        table.insert(optionsData, {
            type     = 'submenu',
            name     = Addon.GROUP_NAMES[groupId],
            controls = controls,
        })
    end

    LAM:RegisterOptionControls('NdgBuffsAndDebuffs_Settings', optionsData)
end
