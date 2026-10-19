local Addon = NdgUrge

Addon.Settings = {}

-- LibAddonMenu-2.0 controls for the submenu NdgCrown adds to its own
-- settings panel (NdgUrge has no panel of its own).
function Addon.Settings.GetOptions()
    local db = function() return Addon.db end
    local defaults = Addon.defaults
    local disabled = function() return not Addon.db.enabled end

    return {
        {
            type = 'description',
            text = 'Shows a big "' .. Addon.TEXT .. '" warning while you are farther away from the '
                .. 'group leader than the distance below (3D distance, like the range ring). Nothing '
                .. 'is shown while you lead the group yourself, while you are dead, or while the '
                .. 'leader\'s position is unknown. NdgCrown\'s "Only in PvP areas" applies here too.'
                .. '\n\nIf you use RdK Group Tool, disable its "Follow the Crown" warnings to avoid '
                .. 'duplicates.',
        },
        {
            type = 'checkbox',
            name = 'Enabled',
            getFunc = function() return db().enabled end,
            setFunc = function(value)
                db().enabled = value
                NdgCrown.RefreshActivation()
            end,
            default = defaults.enabled,
        },
        {
            type = 'checkbox',
            name = 'Only in PvP areas',
            tooltip = 'Only warn in Cyrodiil, Imperial City and Battlegrounds.',
            disabled = disabled,
            getFunc = function() return db().pvpOnly end,
            setFunc = function(value)
                db().pvpOnly = value
                NdgCrown.RefreshActivation()
            end,
            default = defaults.pvpOnly,
        },
        {
            type = 'slider',
            name = 'Warn beyond (m)',
            min = 5, max = 100, step = 1,
            disabled = disabled,
            getFunc = function() return db().maxDistance end,
            setFunc = function(value) db().maxDistance = value end,
            default = defaults.maxDistance,
        },
        {
            type = 'slider',
            name = 'Ignore beyond (m)',
            tooltip = 'No warning when you are even farther away than this, e.g. after '
                .. 'respawning at a keep or when the leader ported. 0 = never ignore.',
            min = 0, max = 500, step = 10,
            disabled = disabled,
            getFunc = function() return db().ignoreBeyond end,
            setFunc = function(value) db().ignoreBeyond = value end,
            default = defaults.ignoreBeyond,
        },
        {
            type = 'checkbox',
            name = 'Show distance in text',
            tooltip = 'E.g. "' .. Addon.TEXT .. ' (34m)".',
            disabled = disabled,
            getFunc = function() return db().showDistance end,
            setFunc = function(value)
                db().showDistance = value
                Addon.Warning.ApplyStyle()
            end,
            default = defaults.showDistance,
        },
        {
            type = 'slider',
            name = 'Text size',
            min = 24, max = 120, step = 2,
            disabled = disabled,
            getFunc = function() return db().fontSize end,
            setFunc = function(value)
                db().fontSize = value
                Addon.Warning.ApplyStyle()
            end,
            default = defaults.fontSize,
        },
        {
            type = 'colorpicker',
            name = 'Text color',
            disabled = disabled,
            getFunc = function()
                local c = db().color
                return c.r, c.g, c.b
            end,
            setFunc = function(r, g, b)
                local c = db().color
                c.r, c.g, c.b = r, g, b
                Addon.Warning.ApplyStyle()
            end,
            default = defaults.color,
        },
        {
            type = 'checkbox',
            name = 'Unlock position',
            tooltip = 'Shows the warning so you can move it: close the menu, press "." for the '
                .. 'mouse cursor and drag the text. Uncheck to lock it again (or use '
                .. Addon.SLASH .. ' lock).',
            getFunc = function() return Addon.Warning.IsUnlocked() end,
            setFunc = function(value) Addon.SetUnlocked(value) end,
            default = false,
        },
    }
end
