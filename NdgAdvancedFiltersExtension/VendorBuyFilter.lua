local Addon = NdgAdvancedFiltersExtension

-- "Not collected" toggle on the vendor's Buy tab (keyboard UI only).
--
-- AdvancedFilters has its Buy-tab support disabled, so this filters the list through LibFilters-3.0
-- directly: LibFilters replaces STORE_WINDOW:ShouldAddItemToList and asks every filter registered
-- for LF_VENDOR_BUY whether a store entry stays visible.
--
-- The toggle switches off whenever you leave a vendor, so the next vendor never opens with an
-- unexpectedly empty list.

local FILTER_TAG = Addon.NAME .. '_VendorBuy'

local libFilters
local isActive = false
local checkbox

-- One of Addon.KIND if the store entry is something you can still collect or learn, otherwise nil.
-- Vendors sell items (checked through their item link) and some sell collectibles directly
-- (mounts, pets, ...), which have no item link.
local function GetStoreEntryKind(entryIndex, entryType)
    if entryType == STORE_ENTRY_TYPE_COLLECTIBLE then
        local collectibleId = GetStoreCollectibleInfo(entryIndex)
        if collectibleId and collectibleId > 0 then return Addon.GetCollectibleKind(collectibleId) end
        return nil
    end
    return Addon.GetNotCollectedKind(GetStoreItemLink(entryIndex))
end

-- LibFilters calls this for every store entry. itemData is the store's row data: slotIndex is the
-- store entry index, entryType the STORE_ENTRY_TYPE_*. true = entry stays visible.
local function VendorBuyFilter(itemData)
    if not isActive then return true end
    if type(itemData) ~= 'table' or not itemData.slotIndex then return true end
    return GetStoreEntryKind(itemData.slotIndex, itemData.entryType) ~= nil
end

-- ZO_StoreWindow is the Buy tab's list. It is hidden on the Sell, Buyback and Repair tabs and in gamepad mode.
local function IsBuyTabShown()
    return ZO_StoreWindow and not ZO_StoreWindow:IsHidden()
end

local function RefreshBuyList()
    if IsBuyTabShown() then libFilters:RequestUpdate(LF_VENDOR_BUY) end
end

-- Test logging: when the toggle goes on, one line per store entry with the data the decision is based on.
local function LogStoreEntries()
    local total, notCollected = GetNumStoreItems(), 0
    for entryIndex = 1, total do
        local _, name = GetStoreEntryInfo(entryIndex)
        local entryType = select(14, GetStoreEntryInfo(entryIndex))
        local kind = GetStoreEntryKind(entryIndex, entryType)
        if kind then notCollected = notCollected + 1 end
        if isActive then
            local itemType, specializedType, collectibleId = '-', '-', 0
            if entryType == STORE_ENTRY_TYPE_COLLECTIBLE then
                collectibleId = GetStoreCollectibleInfo(entryIndex) or 0
            else
                local itemLink = GetStoreItemLink(entryIndex)
                itemType, specializedType = GetItemLinkItemType(itemLink)
                collectibleId = GetItemLinkContainerCollectibleId(itemLink)
            end
            Addon.Log('  #%d %s: entryType %s, itemType %s/%s, collectible %s -> %s',
                entryIndex, zo_strformat(SI_TOOLTIP_ITEM_NAME, name), tostring(entryType),
                tostring(itemType), tostring(specializedType), tostring(collectibleId), kind or 'collected/other')
        end
    end
    Addon.Log('Buy filter %s: %d of %d store entries not collected', isActive and 'ON' or 'OFF', notCollected, total)
end

local function OnToggle(_, checked)
    isActive = checked
    RefreshBuyList()
    LogStoreEntries()
end

local function CreateCheckbox()
    -- The category title ("ALL", "WEAPONS", ...) left of the filter tabs. Its left edge sits 10 px
    -- left of the window, its vertical center is the tab row's center.
    local categoryTitle = ZO_StoreWindowTabsActive
    if not categoryTitle then
        Addon.Log('ZO_StoreWindowTabsActive not found, no Buy-tab toggle')
        return
    end

    checkbox = WINDOW_MANAGER:CreateControlFromVirtual(Addon.NAME .. 'BuyToggle', ZO_StoreWindow, 'ZO_CheckButton')
    checkbox:SetAnchor(LEFT, categoryTitle, LEFT, 10, 0)
    ZO_CheckButton_SetLabelText(checkbox, Addon.STR.NOT_COLLECTED)   -- creates checkbox.label
    ZO_CheckButton_SetTooltipText(checkbox, Addon.STR.BUY_TOGGLE_TOOLTIP)
    ZO_CheckButton_SetToggleFunction(checkbox, OnToggle)
    -- The category title spans this area and takes mouse input (for its truncation tooltip),
    -- so draw the toggle above it.
    checkbox:SetDrawTier(DT_HIGH)
    checkbox.label:SetDrawTier(DT_HIGH)
end

local function OnOpenStore()
    if not checkbox then CreateCheckbox() end
end

local function OnCloseStore()
    isActive = false
    if checkbox then ZO_CheckButton_SetUnchecked(checkbox) end
end

-- Something got collected or learned (e.g. a piece you bought got bound, or you used a recipe from
-- your bag): refresh so it leaves the list. Collectibles need no event here, the store window
-- rebuilds its list itself when the collection changes.
local REFRESH_EVENTS = {
    EVENT_ITEM_SET_COLLECTION_UPDATED,
    EVENT_RECIPE_LEARNED,
    EVENT_MULTIPLE_RECIPES_LEARNED,
    EVENT_STYLE_LEARNED,
    EVENT_LORE_BOOK_LEARNED,
    EVENT_CRAFTED_ABILITY_LOCK_STATE_CHANGED,
    EVENT_CRAFTED_ABILITY_SCRIPT_LOCK_STATE_CHANGED,
}

local function OnCollectedOrLearned()
    if isActive then RefreshBuyList() end
end

function Addon.InitializeVendorBuyFilter()
    libFilters = LibFilters3
    libFilters:InitializeLibFilters()   -- safe to call more than once; AdvancedFilters calls it too
    libFilters:RegisterFilter(FILTER_TAG, LF_VENDOR_BUY, VendorBuyFilter)

    EVENT_MANAGER:RegisterForEvent(FILTER_TAG, EVENT_OPEN_STORE, OnOpenStore)
    EVENT_MANAGER:RegisterForEvent(FILTER_TAG, EVENT_CLOSE_STORE, OnCloseStore)
    -- pairs, not ipairs: a constant missing in a future API would be a nil hole in the list
    for _, event in pairs(REFRESH_EVENTS) do
        EVENT_MANAGER:RegisterForEvent(FILTER_TAG, event, OnCollectedOrLearned)
    end
end
