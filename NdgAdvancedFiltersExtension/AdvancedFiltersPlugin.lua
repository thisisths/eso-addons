local Addon = NdgAdvancedFiltersExtension

-- "Not collected" entry in AdvancedFilters' dropdown. Registered for AF's "All" group, which AF
-- adds to the dropdown of every category (All, Weapons, Armor, Consumables, Miscellaneous, ...),
-- because uncollected items can be gear, recipes, motifs, style pages, runeboxes, ...
-- AF shows its filter bars in the inventory, the banks and on the vendor's Sell tab, but not on
-- the vendor's Buy tab (AF has its Buy-tab support disabled). VendorBuyFilter.lua covers that tab.

local CALLBACK_NAME = 'NdgNotCollected'   -- key into enStrings, AF makes it unique per plugin

-- Panels where the entry makes no sense (same list as AF's built-in "Bound but tradeable" filter).
local EXCLUDED_PANELS = {
    LF_ENCHANTING_CREATION, LF_ENCHANTING_EXTRACTION,
    LF_SMITHING_REFINE, LF_SMITHING_CREATION,
    LF_ALCHEMY_CREATION, LF_CRAFTBAG, LF_PROVISIONING_BREW, LF_PROVISIONING_COOK, LF_QUICKSLOT,
}

-- Returns true if AdvancedFilters is loaded and the entry was registered.
function Addon.RegisterAdvancedFiltersPlugin()
    local AF = AdvancedFilters
    if not AF or not AF.util or type(AdvancedFilters_RegisterFilter) ~= 'function' then return false end

    local getItemLink = AF.util.GetItemLink
    -- At crafting stations AF passes (bagId, slotIndex) instead of a slot table; this turns it into a table.
    local checkSlot = AF.checkCraftingStationSlot or function(slot) return slot end

    -- AF calls this for every item while the entry is selected. true = item stays visible.
    local function NotCollectedCallback(slot, slotIndex)
        slot = checkSlot(slot, slotIndex)
        return Addon.IsNotCollected(getItemLink(slot))
    end

    AdvancedFilters_RegisterFilter({
        pluginName          = Addon.NAME,
        callbackTable       = { { name = CALLBACK_NAME, filterCallback = NotCollectedCallback } },
        filterType          = ITEMFILTERTYPE_ALL,
        subfilters          = { 'All' },
        excludeFilterPanels = EXCLUDED_PANELS,
        enStrings           = { [CALLBACK_NAME] = Addon.STR.NOT_COLLECTED },
    })
    return true
end
