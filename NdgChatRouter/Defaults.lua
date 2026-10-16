local Addon = NdgChatRouter

-- Default saved variables. ZO_SavedVars fills in missing keys on load,
-- so adding new defaults later is safe; removing keys leaves stale data behind.
Addon.defaults = {
    -- tabs[tabName][groupKey] = true  (tabs are keyed by name, not index,
    -- so reordering tabs does not mix up the routing)
    tabs = {},
}
