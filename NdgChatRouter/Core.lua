local Addon = NdgChatRouter

local logger = LibDebugLogger and LibDebugLogger(Addon.NAME)

---------------------------------------------------------------------------
-- Chat tab helpers
---------------------------------------------------------------------------
-- Calls fn(container, tabIndex, tabName) for every tab of every keyboard chat window.
function Addon.ForEachTab(fn)
    local chatSystem = KEYBOARD_CHAT_SYSTEM
    if not chatSystem or not chatSystem.containers then return end
    for _, container in ipairs(chatSystem.containers) do
        for tabIndex = 1, #container.windows do
            local tabName = GetChatContainerTabInfo(container.id, tabIndex)
            fn(container, tabIndex, tabName)
        end
    end
end

function Addon.IsRouted(tabName, groupKey)
    local tab = Addon.db.tabs[tabName]
    return tab ~= nil and tab[groupKey] == true
end

function Addon.SetRouted(tabName, groupKey, enabled)
    local tabs = Addon.db.tabs
    tabs[tabName] = tabs[tabName] or {}
    tabs[tabName][groupKey] = enabled or nil
    if next(tabs[tabName]) == nil then tabs[tabName] = nil end
end

---------------------------------------------------------------------------
-- Routing
---------------------------------------------------------------------------
-- ESO's chat router picks the category (e.g. System) from the event, formats the
-- message (with pChat's formatter if pChat is active) and then fires the
-- "FormattedChatMessage" callback - but that callback does not say which event
-- it came from. So we remember the event key while the router is working on it.
local currentEventKey = nil

local function OnFormattedChatMessage(message, category, targetChannel, fromDisplayName, rawMessageText, narrationMessage, overrideColorDef)
    local groupKey = currentEventKey and Addon.EVENT_TO_GROUP[currentEventKey]
    if not groupKey or not message or not category then return end

    Addon.ForEachTab(function(container, tabIndex, tabName)
        -- Skip tabs that already get this message through their own filters
        -- (e.g. the main tab with System enabled), so nothing shows up twice.
        if Addon.IsRouted(tabName, groupKey) and not IsChatContainerTabCategoryEnabled(container.id, tabIndex, category) then
            if logger then logger:Debug('route %s (category %s) -> tab "%s"', tostring(currentEventKey), tostring(category), tostring(tabName)) end
            container:AddEventMessageToWindow(container.windows[tabIndex], message, category, narrationMessage, overrideColorDef)
        end
    end)
end

local function InstallRouterHook()
    local original = CHAT_ROUTER.FormatAndAddChatMessage
    CHAT_ROUTER.FormatAndAddChatMessage = function(self, eventKey, ...)
        local previous = currentEventKey
        currentEventKey = eventKey
        original(self, eventKey, ...)
        currentEventKey = previous
    end
    CHAT_ROUTER:RegisterCallback('FormattedChatMessage', OnFormattedChatMessage)
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------
function Addon.OnAddOnLoaded(eventCode, addonName)
    if addonName ~= Addon.NAME then return end
    EVENT_MANAGER:UnregisterForEvent(Addon.NAME, EVENT_ADD_ON_LOADED)

    Addon.db = ZO_SavedVars:NewAccountWide('NdgChatRouterDB', Addon.DB_VERSION, nil, Addon.defaults)

    InstallRouterHook()

    -- The settings panel lists the chat tabs, which only exist once the chat UI is set up.
    EVENT_MANAGER:RegisterForEvent(Addon.NAME, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(Addon.NAME, EVENT_PLAYER_ACTIVATED)
        Addon.Settings:Initialize()
    end)

    SLASH_COMMANDS[Addon.SLASH] = Addon.SlashCommand
end

---------------------------------------------------------------------------
-- Slash command: prints which message groups go to which tab
---------------------------------------------------------------------------
function Addon.SlashCommand(text)
    d('[' .. Addon.NAME .. '] v' .. Addon.VERSION .. ' - routed system messages:')
    local any = false
    Addon.ForEachTab(function(container, tabIndex, tabName)
        local labels = {}
        for _, group in ipairs(Addon.GROUPS) do
            if Addon.IsRouted(tabName, group.key) then table.insert(labels, group.label) end
        end
        if #labels > 0 then
            any = true
            d('  ' .. tabName .. ': ' .. table.concat(labels, ', '))
        end
    end)
    if not any then d('  (none - configure in Settings > Addons > NdgChatRouter)') end
end

EVENT_MANAGER:RegisterForEvent(Addon.NAME, EVENT_ADD_ON_LOADED, Addon.OnAddOnLoaded)
