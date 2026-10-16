local Addon = NdgLibUsage
local STR = Addon.STR

-- Integration into the base-game Add-Ons screen (ADD_ON_MANAGER, a
-- ZO_SortFilterList; source: esoui/pregameandingame/zo_addonmanager/).
--  * BuildMasterList post-hook: computes usage for all entries and appends a
--    "Used by" block to the row description, shown when the row is expanded.
--  * Row setup wrapper: appends "Used by x/y" to the State column and gives
--    that label a tooltip (hover) and expand-on-click.
local UI = {}
Addon.UI = UI

local SECTION_HEADER_DATA = 2   -- data type id of the section header rows (not addon rows)

local STATUS_ORDER = { Addon.STATUS_ACTIVE, Addon.STATUS_UNNEEDED, Addon.STATUS_DISABLED }
local STATUS_LABEL = {
    [Addon.STATUS_ACTIVE]   = STR.STATUS_ACTIVE,
    [Addon.STATUS_UNNEEDED] = STR.STATUS_UNNEEDED,
    [Addon.STATUS_DISABLED] = STR.STATUS_DISABLED,
}
local STATUS_COLOR = {
    [Addon.STATUS_ACTIVE]   = Addon.COLOR_ACTIVE,
    [Addon.STATUS_UNNEEDED] = Addon.COLOR_UNNEEDED,
    [Addon.STATUS_DISABLED] = Addon.COLOR_DISABLED,
}

---------------------------------------------------------------------------
-- Text building
---------------------------------------------------------------------------

-- Short text for the State column: "Used by 2/3", or "Unused".
function UI.GetShortText(usage)
    if usage.total == 0 then
        return Addon.COLOR_UNUSED:Colorize(STR.UNUSED)
    end
    local text = string.format(STR.USED_BY, usage.active, usage.total)
    if usage.active == 0 then
        return Addon.COLOR_UNUSED:Colorize(text)
    end
    return text
end

-- One line per status group, e.g. "active: A, B, C" with colored names.
-- Grouped (not one line per user) because big libraries have 50+ users.
function UI.GetGroupLines(usage)
    local lines = {}
    for _, status in ipairs(STATUS_ORDER) do
        local names = {}
        for _, user in ipairs(usage.users) do
            if user.status == status then
                names[#names + 1] = user.name
            end
        end
        if #names > 0 then
            local color = STATUS_COLOR[status]
            lines[#lines + 1] = string.format('%s (%d): %s',
                color:Colorize(STATUS_LABEL[status]), #names, color:Colorize(table.concat(names, ', ')))
        end
    end
    return lines
end

local function GetHeader(usage)
    return string.format(STR.USED_BY_HEADER, usage.active, usage.total)
end

-- Multi-line block appended to the row description (visible when expanded).
local function GetDescriptionBlock(usage)
    local header = Addon.COLOR_HEADER:Colorize(GetHeader(usage))
    if usage.total == 0 then
        return header .. '\n' .. Addon.COLOR_UNUSED:Colorize(STR.NO_USERS)
    end
    return header .. '\n' .. table.concat(UI.GetGroupLines(usage), '\n')
end

---------------------------------------------------------------------------
-- Data: post-hook on BuildMasterList (runs on every refresh, i.e. on show,
-- after every enable/disable click and on character switch)
---------------------------------------------------------------------------
local function OnBuildMasterList(manager)
    local addonTypes = manager.addonTypes
    if not addonTypes then return end

    local entries = {}
    for _, isLibrary in ipairs({ false, true }) do
        for _, entry in ipairs(addonTypes[isLibrary] or {}) do
            entries[#entries + 1] = entry
        end
    end

    local usage = Addon.Graph.Build(entries)
    -- BuildMasterList creates fresh entry tables every time, so appending to
    -- the description cannot accumulate.
    for _, entry in ipairs(entries) do
        local entryUsage = usage[entry.index]
        entry.ndgUsage = entryUsage
        if entryUsage then
            local block = GetDescriptionBlock(entryUsage)
            if entry.addOnDescription and entry.addOnDescription ~= '' then
                entry.addOnDescription = entry.addOnDescription .. '\n\n' .. block
            else
                entry.addOnDescription = block
            end
            entry.expandable = true
        end
    end
end

---------------------------------------------------------------------------
-- Row decoration
---------------------------------------------------------------------------
local function ShowTooltip(stateControl)
    local row = stateControl:GetParent()
    local usage = row.data and row.data.ndgUsage
    if not usage then return end

    InitializeTooltip(InformationTooltip, stateControl, BOTTOM, 0, -5, TOP)
    local baseText = stateControl.ndgBaseText
    if baseText and baseText ~= '' then
        InformationTooltip:AddLine(baseText, '', ZO_NORMAL_TEXT:UnpackRGB())
    end
    InformationTooltip:AddLine(GetHeader(usage), 'ZoFontGameBold', Addon.COLOR_HEADER:UnpackRGB())
    if usage.total == 0 then
        InformationTooltip:AddLine(STR.NO_USERS, '', Addon.COLOR_UNUSED:UnpackRGB())
    else
        for _, line in ipairs(UI.GetGroupLines(usage)) do
            InformationTooltip:AddLine(line, '', ZO_NORMAL_TEXT:UnpackRGB())
        end
    end
    InformationTooltip:AddLine(STR.FOOTNOTE, 'ZoFontGameSmall', Addon.COLOR_DISABLED:UnpackRGB())
    InformationTooltip:AddLine(STR.CLICK_HINT, 'ZoFontGameSmall', Addon.COLOR_DISABLED:UnpackRGB())
end

local function OnStateMouseEnter(stateControl)
    ShowTooltip(stateControl)
end

local function OnStateMouseExit()
    ClearTooltip(InformationTooltip)
end

-- Clicking the label toggles the row's expanded view (same as the arrow).
local function OnStateMouseUp(stateControl, button, upInside)
    if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    local expandButton = stateControl:GetParent():GetNamedChild('ExpandButton')
    if expandButton and not expandButton:IsHidden() then
        ZO_AddOnManager_OnExpandButtonClicked(expandButton)
    end
end

-- Row controls are recycled between rows, so every call must either fully
-- apply or fully undo our changes.
local function DecorateRow(control, data)
    local state = control and control:GetNamedChild('State')
    if not state then return end

    if not state.ndgOriginal then
        state.ndgOriginal = {
            enter = state:GetHandler('OnMouseEnter'),
            exit = state:GetHandler('OnMouseExit'),
            up = state:GetHandler('OnMouseUp'),
            mouseEnabled = state:IsMouseEnabled(),
        }
    end

    local usage = data and data.ndgUsage
    if not usage then
        if state.ndgDecorated then
            local original = state.ndgOriginal
            state:SetHandler('OnMouseEnter', original.enter)
            state:SetHandler('OnMouseExit', original.exit)
            state:SetHandler('OnMouseUp', original.up)
            state:SetMouseEnabled(original.mouseEnabled)
            state.ndgDecorated = false
        end
        state.ndgBaseText = nil
        state.ndgShownText = nil
        return
    end

    -- The base setup has just written its own State text ("", "Out of date",
    -- dependency error). If the label still shows our text, setup ran twice
    -- through stacked wrappers: reuse the stored base text instead.
    local baseText = state:GetText() or ''
    if state.ndgShownText and baseText == state.ndgShownText then
        baseText = state.ndgBaseText or ''
    end

    local shortText = UI.GetShortText(usage)
    local shownText = baseText == '' and shortText or (baseText .. ', ' .. shortText)
    state:SetText(shownText)
    state.ndgBaseText = baseText
    state.ndgShownText = state:GetText()

    if not state.ndgDecorated then
        state:SetMouseEnabled(true)
        state:SetHandler('OnMouseEnter', OnStateMouseEnter)
        state:SetHandler('OnMouseExit', OnStateMouseExit)
        state:SetHandler('OnMouseUp', OnStateMouseUp)
        state.ndgDecorated = true
    end
end

---------------------------------------------------------------------------
-- Hook installation
---------------------------------------------------------------------------

-- Wrappers we created (weak keys so replaced functions can be collected).
local ourWrappers = setmetatable({}, { __mode = 'k' })

-- Wraps a row setup callback: original first (base game / AddonSelector),
-- then our decoration. Never wraps our own wrapper again.
local function WrapSetup(setupCallback)
    if type(setupCallback) ~= 'function' or ourWrappers[setupCallback] then
        return setupCallback
    end
    local wrapper = function(control, data, ...)
        setupCallback(control, data, ...)
        DecorateRow(control, data)
    end
    ourWrappers[wrapper] = true
    return wrapper
end

-- Makes sure every addon-row data type (1 = collapsed, 3+ = expanded rows of
-- different heights) uses our wrapper. Idempotent; re-run on every OnShow in
-- case another addon replaced a callback after we loaded.
local function EnsureRowSetupWrapped()
    local dataTypes = ADD_ON_MANAGER.list and ADD_ON_MANAGER.list.dataTypes
    if not dataTypes then return end
    for typeId, dataType in pairs(dataTypes) do
        if typeId ~= SECTION_HEADER_DATA then
            dataType.setupCallback = WrapSetup(dataType.setupCallback)
        end
    end
end

function UI.Initialize()
    if not ADD_ON_MANAGER or not ZO_AddOnManager then
        Addon.Log('ADD_ON_MANAGER not found, Add-Ons screen integration disabled')
        return false
    end

    -- Expanded rows get new data types later via GetRowSetupFunction();
    -- AddonSelector also overrides it (it loads first, OptionalDependsOn),
    -- so this wraps the result of its override.
    local originalGetRowSetupFunction = ZO_AddOnManager.GetRowSetupFunction
    ZO_AddOnManager.GetRowSetupFunction = function(self, ...)
        return WrapSetup(originalGetRowSetupFunction(self, ...))
    end

    ZO_PostHook(ADD_ON_MANAGER, 'BuildMasterList', OnBuildMasterList)
    ZO_PreHook(ADD_ON_MANAGER, 'OnShow', EnsureRowSetupWrapped)  -- returns nil: original still runs
    EnsureRowSetupWrapped()
    return true
end
