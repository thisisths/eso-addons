local Addon = NdgAdvancedFiltersExtension

-- What "not collected" means, per kind of item. The rules mirror the "add to collection" /
-- "use to learn" lines of the game's item tooltips (esoui/publicallingames/tooltip/itemtooltips.lua),
-- which UnknownInsight's categories also follow, plus set pieces (same check as SetCollectionMarker).
--
-- Set pieces and collectibles are account-wide. Recipes, motifs, lore books and scribing are
-- learned per character, so these use what the current character knows.

Addon.KIND = {
    SET_PIECE   = 'set piece',
    COLLECTIBLE = 'collectible',   -- style pages, runeboxes, collectible fragments, ...
    RECIPE      = 'recipe',        -- food, drink and furnishing recipes
    BOOK        = 'book',          -- motifs and Lore Library books
    GRIMOIRE    = 'grimoire',
    SCRIPT      = 'scribing script',
}
local KIND = Addon.KIND

-- Collectible granted by an item when used (style page, runebox, fragment, ...): nil if collected.
local function GetCollectibleKind(collectibleId)
    if IsCollectibleOwnedByDefId(collectibleId) then return nil end
    -- A fragment whose combined result you already own can't be used any more: the tooltip says "already own".
    if GetCollectibleCategoryType(collectibleId) == COLLECTIBLE_CATEGORY_TYPE_COMBINATION_FRAGMENT
            and not CanCombinationFragmentBeUnlocked(collectibleId) then
        return nil
    end
    return KIND.COLLECTIBLE
end
Addon.GetCollectibleKind = GetCollectibleKind

-- Returns one of Addon.KIND if you can still collect or learn the item, otherwise nil.
function Addon.GetNotCollectedKind(itemLink)
    if not itemLink or itemLink == '' then return nil end

    if IsItemLinkSetCollectionPiece(itemLink) then
        if IsItemSetCollectionPieceUnlocked(GetItemLinkItemId(itemLink)) then return nil end
        return KIND.SET_PIECE
    end

    local collectibleId = GetItemLinkContainerCollectibleId(itemLink)
    if collectibleId > 0 then return GetCollectibleKind(collectibleId) end

    local itemType = GetItemLinkItemType(itemLink)
    if itemType == ITEMTYPE_RECIPE then
        if IsItemLinkRecipeKnown(itemLink) then return nil end
        return KIND.RECIPE
    end
    -- Motifs count as books too; the tooltip shows both through its book layout.
    if itemType == ITEMTYPE_RACIAL_STYLE_MOTIF
            or (IsItemLinkBook(itemLink) and IsItemLinkBookPartOfCollection(itemLink)) then
        if IsItemLinkBookKnown(itemLink) then return nil end
        return KIND.BOOK
    end
    if itemType == ITEMTYPE_CRAFTED_ABILITY then
        if IsCraftedAbilityUnlocked(GetItemLinkItemUseReferenceId(itemLink)) then return nil end
        return KIND.GRIMOIRE
    end
    if itemType == ITEMTYPE_CRAFTED_ABILITY_SCRIPT then
        if IsCraftedAbilityScriptUnlocked(GetItemLinkItemUseReferenceId(itemLink)) then return nil end
        return KIND.SCRIPT
    end
    return nil
end

function Addon.IsNotCollected(itemLink)
    return Addon.GetNotCollectedKind(itemLink) ~= nil
end
