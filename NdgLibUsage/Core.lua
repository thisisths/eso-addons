local Addon = NdgLibUsage

local logger = LibDebugLogger and LibDebugLogger(Addon.NAME)

function Addon.Log(formatString, ...)
    if logger then logger:Info(formatString, ...) end
end

local function Print(text)
    d('[' .. Addon.NAME .. '] ' .. text)
end

---------------------------------------------------------------------------
-- Slash command
--   /ndglibusage          list libraries without an active user
--   /ndglibusage <name>   show who uses the addon/library matching <name>
---------------------------------------------------------------------------
local function ListUnused(entries, usage)
    local unusedEverywhere, onlyInactive = {}, {}
    for _, entry in ipairs(entries) do
        local entryUsage = usage[entry.index]
        if entry.isLibrary and entryUsage and entryUsage.active == 0 then
            local enabledSuffix = entry.addOnEnabled and '' or ' (disabled)'
            local name = entry.strippedAddOnName .. enabledSuffix
            if entryUsage.total == 0 then
                unusedEverywhere[#unusedEverywhere + 1] = name
            else
                onlyInactive[#onlyInactive + 1] = string.format('%s (%d)', name, entryUsage.total)
            end
        end
    end
    table.sort(unusedEverywhere)
    table.sort(onlyInactive)

    if #unusedEverywhere == 0 and #onlyInactive == 0 then
        Print('Every library is used by at least one active addon.')
        return
    end
    if #unusedEverywhere > 0 then
        Print(string.format('Not used by any installed addon (%d): %s',
            #unusedEverywhere, table.concat(unusedEverywhere, ', ')))
    end
    if #onlyInactive > 0 then
        Print(string.format('Only used by disabled or unneeded addons (%d): %s',
            #onlyInactive, table.concat(onlyInactive, ', ')))
    end
end

local function ShowOne(entries, usage, query)
    local found = 0
    for _, entry in ipairs(entries) do
        local fileName = string.lower(entry.addOnFileName)
        local title = string.lower(entry.strippedAddOnName)
        if fileName == query or title == query
            or fileName:find(query, 1, true) or title:find(query, 1, true) then
            found = found + 1
            local entryUsage = usage[entry.index]
            if entryUsage then
                Print(string.format('%s: %s', entry.strippedAddOnName, Addon.UI.GetShortText(entryUsage)))
                for _, line in ipairs(Addon.UI.GetGroupLines(entryUsage)) do
                    d('  ' .. line)
                end
            else
                Print(entry.strippedAddOnName .. ': no installed addon depends on this.')
            end
        end
    end
    if found == 0 then
        Print('No addon matches "' .. query .. '".')
    end
end

function Addon.SlashCommand(text)
    local query = string.lower(tostring(text)):match('^%s*(.-)%s*$')
    local entries = Addon.Graph.CollectFromApi()
    local usage = Addon.Graph.Build(entries)
    if query == '' then
        ListUnused(entries, usage)
    else
        ShowOne(entries, usage, query)
    end
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------
function Addon.OnAddOnLoaded(eventCode, addonName)
    if addonName ~= Addon.NAME then return end
    EVENT_MANAGER:UnregisterForEvent(Addon.NAME, EVENT_ADD_ON_LOADED)

    local hooked = Addon.UI.Initialize()
    Addon.Log('v%s loaded, Add-Ons screen hooked: %s', Addon.VERSION, tostring(hooked))

    SLASH_COMMANDS[Addon.SLASH] = Addon.SlashCommand
end

EVENT_MANAGER:RegisterForEvent(Addon.NAME, EVENT_ADD_ON_LOADED, Addon.OnAddOnLoaded)
