local Addon = NdgLibUsage

-- Reverse dependency computation ("who uses this library?"). No UI code in here.
local Graph = {}
Addon.Graph = Graph

local AddOnManager = GetAddOnManager()

-- Dependency names never change during a session (the addon list is fixed at
-- load time), so read them from the API only once per addon index.
local dependencyCache = {}

local function GetDependencyNames(index)
    local names = dependencyCache[index]
    if not names then
        names = {}
        for j = 1, AddOnManager:GetAddOnNumDependencies(index) do
            local dependencyName = AddOnManager:GetAddOnDependencyInfo(index, j)
            names[#names + 1] = dependencyName
        end
        dependencyCache[index] = names
    end
    return names
end

-- Removes |cRRGGBB ... |r color markup from addon titles.
local function StripColor(text)
    return (text:gsub('|c%x%x%x%x%x%x', ''):gsub('|r', ''))
end

-- Reads the addon list straight from the API (used by the slash command, when
-- the Add-Ons screen may never have been opened). Same shape as the entries
-- the UI passes in from ADD_ON_MANAGER.addonTypes.
function Graph.CollectFromApi()
    local entries = {}
    for i = 1, AddOnManager:GetNumAddOns() do
        local fileName, title, _, _, enabled, _, _, isLibrary = AddOnManager:GetAddOnInfo(i)
        entries[#entries + 1] = {
            index = i,
            addOnFileName = fileName,
            strippedAddOnName = StripColor(title),
            addOnEnabled = enabled,
            isLibrary = isLibrary,
        }
    end
    return entries
end

local function DisplayName(entry)
    local name = entry.strippedAddOnName
    if not name or name == '' then name = entry.addOnFileName end
    return name
end

local function SortUsers(a, b)
    if a.status ~= b.status then return a.status < b.status end
    return a.sortName < b.sortName
end

-- entries: list of tables with index, addOnFileName, strippedAddOnName,
-- addOnEnabled, isLibrary (exactly the fields of the base game's row data).
--
-- Returns usage[index] = { total, active, users = { {name, status}, ... } }
-- for every library, and for every normal addon that something depends on.
--
-- "Follow the chain": a user only counts as active if it is enabled AND it is
-- either a normal addon or a library that is itself needed by something
-- enabled (transitively). A library only kept alive by another unneeded
-- library therefore shows as unused too.
function Graph.Build(entries)
    -- File names are matched case-insensitively; one name can map to several
    -- installed copies (e.g. an old nested copy of a library).
    local byFileName = {}
    for _, entry in ipairs(entries) do
        local key = string.lower(entry.addOnFileName)
        local list = byFileName[key]
        if not list then
            list = {}
            byFileName[key] = list
        end
        list[#list + 1] = entry
    end

    -- Which addons are needed: walk from every enabled normal addon through
    -- the dependencies of enabled addons. Disabled addons stop the walk, so a
    -- disabled library does not keep its own dependencies alive.
    local needed = {}
    local queue = {}
    for _, entry in ipairs(entries) do
        if entry.addOnEnabled and not entry.isLibrary then
            needed[entry.index] = true
            queue[#queue + 1] = entry
        end
    end
    local head = 1
    while head <= #queue do
        local entry = queue[head]
        head = head + 1
        for _, dependencyName in ipairs(GetDependencyNames(entry.index)) do
            for _, dependency in ipairs(byFileName[string.lower(dependencyName)] or {}) do
                if dependency.addOnEnabled and not needed[dependency.index] then
                    needed[dependency.index] = true
                    queue[#queue + 1] = dependency
                end
            end
        end
    end

    -- Reverse edges: usersOf[libraryIndex] = { userEntry, ... }, each user once.
    local usersOf = {}
    for _, user in ipairs(entries) do
        local seen = {}
        for _, dependencyName in ipairs(GetDependencyNames(user.index)) do
            for _, dependency in ipairs(byFileName[string.lower(dependencyName)] or {}) do
                if dependency.index ~= user.index and not seen[dependency.index] then
                    seen[dependency.index] = true
                    local list = usersOf[dependency.index]
                    if not list then
                        list = {}
                        usersOf[dependency.index] = list
                    end
                    list[#list + 1] = user
                end
            end
        end
    end

    local usage = {}
    for _, entry in ipairs(entries) do
        local userEntries = usersOf[entry.index]
        if entry.isLibrary or userEntries then
            local result = { total = 0, active = 0, users = {} }
            for _, user in ipairs(userEntries or {}) do
                local status
                if not user.addOnEnabled then
                    status = Addon.STATUS_DISABLED
                elseif needed[user.index] then
                    status = Addon.STATUS_ACTIVE
                    result.active = result.active + 1
                else
                    status = Addon.STATUS_UNNEEDED
                end
                local name = DisplayName(user)
                result.users[#result.users + 1] = { name = name, sortName = string.lower(name), status = status }
            end
            result.total = #result.users
            table.sort(result.users, SortUsers)
            usage[entry.index] = result
        end
    end
    return usage
end
