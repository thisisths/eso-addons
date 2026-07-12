local Addon = NdgCrown

Addon.Settings = {}

local function IconLabel(target)
    return string.format('|t28:28:%s|t %s', target.icon, target.name)
end

function Addon.Settings:Initialize()
    local LAM = LibAddonMenu2
    local general = function() return Addon.db.general end

    local panelData = {
        type = 'panel',
        name = Addon.NAME,
        author = 'Ndg',
        version = Addon.VERSION,
        registerForRefresh = true,
        registerForDefaults = true,
    }
    LAM:RegisterAddonPanel(Addon.NAME .. 'Options', panelData)

    local options = {
        {
            type = 'description',
            text = 'Shows a beam and/or direction arrow for the group leader and for base-game '
                .. 'target marks.\n\nMark tracking: group members get live positions (beam + '
                .. 'arrow). For everyone else the game hides exact positions, so the arrow '
                .. 'follows the mark\'s compass pin instead: whenever the pin crosses the middle '
                .. 'of your compass, the direction is re-captured (the label then shows how old '
                .. 'the direction is, in seconds). Aim your crosshair at the marked unit once so '
                .. 'the addon learns which compass pin belongs to which mark.\n\nIf you enable '
                .. 'the leader beam/arrow here, disable the "Follow the Crown" beam and arrow in '
                .. 'RdK Group Tool to avoid duplicates.',
        },
        {
            type = 'checkbox',
            name = 'Only in PvP areas',
            tooltip = 'Only track and draw in Cyrodiil, Imperial City and Battlegrounds.',
            getFunc = function() return general().pvpOnly end,
            setFunc = function(value)
                general().pvpOnly = value
                Addon.RefreshActivation()
            end,
            default = Addon.defaults.general.pvpOnly,
        },
        {
            type = 'header',
            name = 'Beam',
        },
        {
            type = 'slider',
            name = 'Beam width (m)',
            min = 1, max = 60, step = 1,
            getFunc = function() return general().beamWidth * 10 end,
            setFunc = function(value)
                general().beamWidth = value / 10
                Addon.Beam.ApplyDimensions()
            end,
            tooltip = 'In tenths of a meter: 10 = 1m wide.',
            default = Addon.defaults.general.beamWidth * 10,
        },
        {
            type = 'slider',
            name = 'Beam height (m)',
            min = 10, max = 250, step = 5,
            getFunc = function() return general().beamHeight end,
            setFunc = function(value)
                general().beamHeight = value
                Addon.Beam.ApplyDimensions()
            end,
            default = Addon.defaults.general.beamHeight,
        },
        {
            type = 'slider',
            name = 'Beam opacity (%)',
            min = 5, max = 100, step = 5,
            getFunc = function() return general().beamAlpha end,
            setFunc = function(value) general().beamAlpha = value end,
            default = Addon.defaults.general.beamAlpha,
        },
        {
            type = 'header',
            name = 'Arrow',
        },
        {
            type = 'slider',
            name = 'Arrow size when close',
            min = 10, max = 100, step = 1,
            getFunc = function() return general().arrowSizeClose end,
            setFunc = function(value) general().arrowSizeClose = value end,
            default = Addon.defaults.general.arrowSizeClose,
        },
        {
            type = 'slider',
            name = 'Arrow size when far',
            min = 10, max = 100, step = 1,
            getFunc = function() return general().arrowSizeFar end,
            setFunc = function(value) general().arrowSizeFar = value end,
            default = Addon.defaults.general.arrowSizeFar,
        },
        {
            type = 'slider',
            name = 'Distance for close size (m)',
            min = 0, max = 50, step = 1,
            getFunc = function() return general().arrowMinDistance end,
            setFunc = function(value) general().arrowMinDistance = value end,
            default = Addon.defaults.general.arrowMinDistance,
        },
        {
            type = 'slider',
            name = 'Distance for far size (m)',
            min = 20, max = 500, step = 5,
            getFunc = function() return general().arrowMaxDistance end,
            setFunc = function(value) general().arrowMaxDistance = value end,
            default = Addon.defaults.general.arrowMaxDistance,
        },
        {
            type = 'slider',
            name = 'Arrow distance from reticle (px)',
            min = 20, max = 250, step = 5,
            getFunc = function() return general().arrowRadius end,
            setFunc = function(value) general().arrowRadius = value end,
            default = Addon.defaults.general.arrowRadius,
        },
        {
            type = 'slider',
            name = 'Hide arrow below distance (m)',
            tooltip = '0 = never hide.',
            min = 0, max = 50, step = 1,
            getFunc = function() return general().arrowHideBelow end,
            setFunc = function(value) general().arrowHideBelow = value end,
            default = Addon.defaults.general.arrowHideBelow,
        },
        {
            type = 'checkbox',
            name = 'Show distance label',
            getFunc = function() return general().showDistanceLabel end,
            setFunc = function(value) general().showDistanceLabel = value end,
            default = Addon.defaults.general.showDistanceLabel,
        },
        {
            type = 'header',
            name = 'Marks',
        },
        {
            type = 'slider',
            name = 'Mark position timeout (s)',
            tooltip = 'How long the last seen position of a marked non-group unit stays valid. '
                .. 'The beam/arrow fades out toward the end.',
            min = 5, max = 300, step = 5,
            getFunc = function() return general().markTimeout end,
            setFunc = function(value) general().markTimeout = value end,
            default = Addon.defaults.general.markTimeout,
        },
    }

    for _, target in ipairs(Addon.TARGETS) do
        local key = target.key
        local targetDb = function() return Addon.db.targets[key] end
        local targetDefaults = Addon.defaults.targets[key]
        table.insert(options, {
            type = 'submenu',
            name = IconLabel(target),
            controls = {
                {
                    type = 'checkbox',
                    name = 'Beam',
                    getFunc = function() return targetDb().beam.enabled end,
                    setFunc = function(value)
                        targetDb().beam.enabled = value
                        Addon.RefreshActivation()
                    end,
                    default = targetDefaults.beam.enabled,
                },
                {
                    type = 'colorpicker',
                    name = 'Beam color',
                    getFunc = function()
                        local c = targetDb().beam.color
                        return c.r, c.g, c.b
                    end,
                    setFunc = function(r, g, b)
                        local c = targetDb().beam.color
                        c.r, c.g, c.b = r, g, b
                    end,
                    default = targetDefaults.beam.color,
                },
                {
                    type = 'checkbox',
                    name = 'Arrow',
                    getFunc = function() return targetDb().arrow.enabled end,
                    setFunc = function(value)
                        targetDb().arrow.enabled = value
                        Addon.RefreshActivation()
                    end,
                    default = targetDefaults.arrow.enabled,
                },
                {
                    type = 'colorpicker',
                    name = 'Arrow color',
                    getFunc = function()
                        local c = targetDb().arrow.color
                        return c.r, c.g, c.b
                    end,
                    setFunc = function(r, g, b)
                        local c = targetDb().arrow.color
                        c.r, c.g, c.b = r, g, b
                    end,
                    default = targetDefaults.arrow.color,
                },
            },
        })
    end

    LAM:RegisterOptionControls(Addon.NAME .. 'Options', options)
end
