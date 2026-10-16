local Addon = NdgChatRouter

Addon.Settings = {}

-- LibAddonMenu-2.0 settings panel: one submenu per chat tab, one checkbox per message group.
-- Built after EVENT_PLAYER_ACTIVATED (see Core.lua) because the chat tabs must exist.
function Addon.Settings:Initialize()
    local LAM = LibAddonMenu2

    local panelData = {
        type = 'panel',
        name = Addon.NAME,
        author = '@Nidhoeggr',
        version = Addon.VERSION,
        registerForRefresh = true,
    }
    LAM:RegisterAddonPanel(Addon.NAME .. 'Options', panelData)

    local options = {
        {
            type = 'description',
            text = 'Choose which system messages are also shown in each chat tab. '
                .. 'Tabs that already show System messages get them anyway.\n'
                .. 'New or renamed tabs appear here after a /reloadui. '
                .. 'The kill feed needs the game setting "PvP Kill Feed" notifications turned on.',
        },
    }

    local seen = {}
    Addon.ForEachTab(function(container, tabIndex, tabName)
        if seen[tabName] then return end   -- tabs are keyed by name, list each name once
        seen[tabName] = true

        local controls = {}
        for _, group in ipairs(Addon.GROUPS) do
            table.insert(controls, {
                type = 'checkbox',
                name = group.label,
                getFunc = function() return Addon.IsRouted(tabName, group.key) end,
                setFunc = function(value) Addon.SetRouted(tabName, group.key, value) end,
            })
        end
        table.insert(options, { type = 'submenu', name = tabName, controls = controls })
    end)

    LAM:RegisterOptionControls(Addon.NAME .. 'Options', options)
end
