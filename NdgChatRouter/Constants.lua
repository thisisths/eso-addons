-- First file loaded: creates the addon namespace all other files attach to.
NdgChatRouter = NdgChatRouter or {}
local Addon = NdgChatRouter

Addon.NAME       = 'NdgChatRouter'
Addon.SLASH      = '/ndgchat'
Addon.VERSION    = '0.0.1'   -- keep in sync with ## Version in the manifest
Addon.DB_VERSION = 1         -- bumping this WIPES saved variables

-- Message groups the user can route to a tab. 'key' is what gets stored in
-- the saved variables, 'events' are the chat router event keys that belong to it.
Addon.GROUPS = {
    { key = 'killfeed',   label = 'PvP kill feed',             events = { EVENT_PVP_KILL_FEED_DEATH } },
    { key = 'friends',    label = 'Friend online/offline',     events = { EVENT_FRIEND_PLAYER_STATUS_CHANGED } },
    { key = 'keepattack', label = 'Guild keep attack updates', events = { EVENT_GUILD_KEEP_ATTACK_UPDATE } },
    { key = 'group',      label = 'Group join/leave',          events = { EVENT_GROUP_MEMBER_JOINED, EVENT_GROUP_MEMBER_LEFT, EVENT_GROUP_TYPE_CHANGED } },
}

-- Reverse lookup: event key -> group key
Addon.EVENT_TO_GROUP = {}
for _, group in ipairs(Addon.GROUPS) do
    for _, eventKey in ipairs(group.events) do
        Addon.EVENT_TO_GROUP[eventKey] = group.key
    end
end
