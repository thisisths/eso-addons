local Addon = _G['NdgBuffsAndDebuffs']

Addon.NAME        = 'NdgBuffsAndDebuffs'
Addon.SLASH       = '/ndgbuffs'
Addon.VERSION     = '1.0.0'
Addon.DB_VERSION  = 1

-- Display group IDs
Addon.GROUP_REMINDER      = 1
Addon.GROUP_LONG_BUFF     = 2
Addon.GROUP_SHORT_BUFF    = 3
Addon.GROUP_DEBUFF        = 4
Addon.GROUP_TARGET_BUFF   = 5
Addon.GROUP_TARGET_DEBUFF = 6
Addon.NUM_GROUPS          = 6

Addon.GROUP_NAMES = {
    [1] = 'Reminders',
    [2] = 'Long Duration Buffs',
    [3] = 'Short Duration Buffs',
    [4] = 'Debuffs',
    [5] = 'Target Buffs',
    [6] = 'Target Debuffs',
}

-- Display modes
Addon.DISPLAY_ICON = 1
Addon.DISPLAY_TEXT = 2
Addon.DISPLAY_BOTH = 3

Addon.DISPLAY_MODE_NAMES = {
    [1] = 'Icon',
    [2] = 'Text',
    [3] = 'Both',
}

-- Growth / ordering directions
Addon.GROW_UP    = 1
Addon.GROW_DOWN  = 2
Addon.GROW_LEFT  = 3
Addon.GROW_RIGHT = 4

Addon.GROWTH_NAMES = {
    [1] = 'Bottom to Top',
    [2] = 'Top to Bottom',
    [3] = 'Left to Right',
    [4] = 'Right to Left',
}

-- Text position (relative to icon, for Both mode)
Addon.TEXT_RIGHT = 1
Addon.TEXT_LEFT  = 2

-- Timer update rate (ms)
Addon.UPDATE_RATE = 100
