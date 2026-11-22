local Addon = NdgAdvancedFiltersExtension

local logger = LibDebugLogger and LibDebugLogger(Addon.NAME)

function Addon.Log(formatString, ...)
    if logger then logger:Info(formatString, ...) end
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------
local function OnAddOnLoaded(eventCode, addonName)
    if addonName ~= Addon.NAME then return end
    EVENT_MANAGER:UnregisterForEvent(Addon.NAME, EVENT_ADD_ON_LOADED)

    local hasAdvancedFilters = Addon.RegisterAdvancedFiltersPlugin()
    Addon.InitializeVendorBuyFilter()
    Addon.Log('Loaded v%s, AdvancedFilters dropdown entry: %s', Addon.VERSION, tostring(hasAdvancedFilters))
end

EVENT_MANAGER:RegisterForEvent(Addon.NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
