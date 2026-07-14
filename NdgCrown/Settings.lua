local Addon = NdgCrown

Addon.Settings = {}

local function IconLabel(target)
    return string.format('|t28:28:%s|t %s', target.icon, target.name)
end

-- The arrow geometry sliders exist twice: once as global settings and once
-- per target (used while its override checkbox is on). One spec feeds both.
local ARROW_SLIDERS = {
    { key = 'sizeClose',   generalKey = 'arrowSizeClose',   name = 'Arrow size when close',
      min = 10, max = 100, step = 1 },
    { key = 'sizeFar',     generalKey = 'arrowSizeFar',     name = 'Arrow size when far',
      min = 10, max = 100, step = 1 },
    { key = 'minDistance', generalKey = 'arrowMinDistance', name = 'Distance for close size (m)',
      min = 0, max = 50, step = 1 },
    { key = 'maxDistance', generalKey = 'arrowMaxDistance', name = 'Distance for far size (m)',
      min = 20, max = 500, step = 5 },
    { key = 'radius',      generalKey = 'arrowRadius',      name = 'Arrow distance from reticle (px)',
      min = 20, max = 250, step = 5 },
    { key = 'hideBelow',   generalKey = 'arrowHideBelow',   name = 'Hide arrow below distance (m)',
      min = 0, max = 50, step = 1, tooltip = '0 = never hide.' },
}

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
                .. 'target marks.\n\nBeam and arrow only appear while the target\'s position is '
                .. 'actually known: group members deliver live positions anywhere in the zone; '
                .. 'outside the group the game only exposes positions of NPCs close to your '
                .. 'crosshair (never of players). When the position stops updating, the arrow '
                .. 'disappears immediately and the beam keeps marking the last known spot for '
                .. '10 more seconds.\n\nIf you enable the leader beam/arrow here, disable the '
                .. '"Follow the Crown" beam and arrow in RdK Group Tool to avoid duplicates.',
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
    }

    -- global arrow geometry; targets with the override checkbox use their own
    for _, def in ipairs(ARROW_SLIDERS) do
        table.insert(options, {
            type = 'slider',
            name = def.name,
            tooltip = def.tooltip,
            min = def.min, max = def.max, step = def.step,
            getFunc = function() return general()[def.generalKey] end,
            setFunc = function(value) general()[def.generalKey] = value end,
            default = Addon.defaults.general[def.generalKey],
        })
    end

    table.insert(options, {
        type = 'checkbox',
        name = 'Show distance label',
        getFunc = function() return general().showDistanceLabel end,
        setFunc = function(value) general().showDistanceLabel = value end,
        default = Addon.defaults.general.showDistanceLabel,
    })

    for _, target in ipairs(Addon.TARGETS) do
        local key = target.key
        local targetDb = function() return Addon.db.targets[key] end
        local targetDefaults = Addon.defaults.targets[key]
        local controls = {
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
            {
                type = 'checkbox',
                name = 'Override arrow size & distances',
                tooltip = 'Give this arrow its own size/distance values instead '
                    .. 'of the global Arrow settings above.',
                getFunc = function() return targetDb().arrow.override end,
                setFunc = function(value) targetDb().arrow.override = value end,
                default = targetDefaults.arrow.override,
            },
        }
        for _, def in ipairs(ARROW_SLIDERS) do
            table.insert(controls, {
                type = 'slider',
                name = def.name,
                tooltip = def.tooltip,
                min = def.min, max = def.max, step = def.step,
                disabled = function() return not targetDb().arrow.override end,
                getFunc = function() return targetDb().arrow[def.key] end,
                setFunc = function(value) targetDb().arrow[def.key] = value end,
                default = targetDefaults.arrow[def.key],
            })
        end
        table.insert(options, {
            type = 'submenu',
            name = IconLabel(target),
            controls = controls,
        })
    end

    LAM:RegisterOptionControls(Addon.NAME .. 'Options', options)
end
