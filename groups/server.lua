---@class Group
---@field getUuid fun(): string
---@field getPartyUuid fun(): string
---@field setLeader fun(src: number | string): boolean
---@field getLeader fun(): { identifier: string, src: number | string, characterName: string } | nil
---@field addMember fun(src: number | string): boolean
---@field removeMember fun(src: number | string): boolean
---@field getMembers fun(): table<string, { identifier: string, src: number | string, characterName: string, online: boolean, isLeader: boolean }>
---@field getMembersCount fun(): number
---@field getMembersPlayerIds fun(): number | string[]
---@field setActivity fun(activity: { activityId: string, activityName: string })
---@field getActivity fun(): { activityId: string, activityName: string } | nil
---@field clearActivity fun()
---@field triggerEvent fun(eventName: string, ...: any) Triggers a client event for all group members
---@field disband fun() Disbands the group and clears all data
---@field isAnyoneOnline fun(): boolean Checks if any group member is currently online
---@field isSrcAMember fun(src: number | string): boolean Checks if the given source is a member of the group
---@field isSrcALeader fun(src: number | string): boolean Checks if the given source is the leader of the group
---@field isInviting fun(): boolean Checks if the group is currently open for inviting new members
---@field toggleInviting fun() Toggles the inviting state of the group
---@field addPendingInvite fun(inviteUuid: string, targetSrc: number | string) Adds a pending invite for a target source
---@field removePendingInvite fun(inviteUuid: string) Removes a pending invite by its UUID
---@field isPendingInviteValid fun(inviteUuid: string, targetSrc: number | string): boolean Checks if a pending invite is valid for the given target source
---@field createUniqueueParty fun(partyType: UniQueueType) Creates a UniQueue party for the group
---@field enterUniqueue fun(queueName: string): { success: boolean, error?: string } Enters the group's UniQueue party into the specified queue
---@field clearPartyUuid fun() Clears the stored party UUID when the party is destroyed
---@field setLocked fun(lockedState: boolean) Sets the locked state of the group
---@field isLocked fun(): boolean Checks if the group is currently locked

local function generateUUID()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return template:gsub("[xy]", function(c)
        local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
        return string.format("%x", v)
    end)
end

local mt = {
    __index = function(self, key)

    end
}

local cachedPlayerIdentifiers = {} ---@type table<string, string>
local groups = {} ---@type table<string, Group>
local memberToGroupMap = {} ---@type table<string, string>

Groups = {}

local function initGroupObject(data)
    local public = {}
    local isPulsarGroup = data.isPulsarGroup or false
    local pulsarGroupData = data.pulsarGroupData or nil

    local private = {
        uuid            = tostring(data.uuid or ""),
        members         = {},
        leader          = nil,
        activity        = nil,
        isInviting      = false,
        invites         = {},
        partyUuid       = nil,
        isLocked        = false,
        isPulsarGroup   = isPulsarGroup,
        pulsarGroupData = pulsarGroupData,
    }

    setmetatable(public, mt)

    ---@return string
    public.getUuid = function()
        return private.uuid
    end

    ---@return string
    public.getPartyUuid = function()
        if private.isPulsarGroup and private.pulsarGroupData then
            return exports['pulsar-labor']:GetGroupPartyUuid(private.pulsarGroupData.Creator.ID)
        end
        return private.partyUuid
    end

    ---@param src number | string
    ---@return boolean
    public.setLeader = function(src)
        ---@diagnostic disable-next-line: param-type-mismatch
        if not DoesPlayerExist(src) then
            return false
        end

        local identifier = bridge.fw.getIdentifier(src)
        if not identifier then
            return false
        end

        local characterName = bridge.fw.getCharacterName(identifier)
        if not characterName then
            return false
        end

        private.leader = {
            identifier    = identifier,
            src           = src,
            characterName = characterName,
        }

        return true
    end

    ---@return { identifier: string, src: number | string, characterName: string } | nil
    public.getLeader = function()
        if private.isPulsarGroup and private.pulsarGroupData then
            return {
                identifier    = private.pulsarGroupData.Creator.SID,
                src           = private.pulsarGroupData.Creator.ID,
                characterName = private.pulsarGroupData.Creator.First .. " " .. private.pulsarGroupData.Creator.Last,
            }
        else
            return private.leader
        end
    end

    ---@param src number | string
    ---@return boolean
    public.isSrcALeader = function(src)
        if private.isPulsarGroup and private.pulsarGroupData then
            return tostring(private.pulsarGroupData.Creator.ID) == tostring(src)
        else
            if not private.leader then
                return false
            end
            return tostring(private.leader.src) == tostring(src)
        end
    end

    ---@param src number | string
    ---@return boolean
    public.addMember = function(src)
        if private.isPulsarGroup then
            -- Pulsar groups handled by pulsar-labor API
            return false
        end

        ---@diagnostic disable-next-line: param-type-mismatch
        if not DoesPlayerExist(src) then
            return false
        end

        local identifier = bridge.fw.getIdentifier(src)
        if not identifier then
            return false
        end

        local characterName = bridge.fw.getCharacterName(identifier)
        if not characterName then
            return false
        end

        private.members[tostring(identifier)] = {
            identifier    = identifier,
            src           = src,
            characterName = characterName,
            online        = true,
        }

        memberToGroupMap[tostring(identifier)] = private.uuid
        cachedPlayerIdentifiers[tostring(src)] = tostring(identifier)

        if private.partyUuid then
            local party = GetParty(private.partyUuid)
            if party then
                party.addMember(identifier)
            end
        end

        TriggerEvent("prp-bridge:server:groupMemberAdded", src, private.uuid)

        return true
    end

    ---@param src number | string
    ---@return boolean
    public.removeMember = function(src)
        if private.isPulsarGroup then
            -- Pulsar groups handled by pulsar-labor API
            return false
        end

        ---@diagnostic disable-next-line: param-type-mismatch
        if not DoesPlayerExist(src) then
            return false
        end

        local identifier = bridge.fw.getIdentifier(src)
        if not identifier then
            return false
        end

        private.members[tostring(identifier)] = nil
        memberToGroupMap[tostring(identifier)] = nil

        TriggerEvent("prp-bridge:server:groupMemberRemoved", src, private.uuid)

        if private.partyUuid then
            local party = GetParty(private.partyUuid)
            if party then
                party.removeMember(identifier)
            end
        end

        return true
    end

    ---@return table<string, { identifier: string, src: number | string, characterName: string, isLeader: boolean, online: boolean }>
    public.getMembers = function()
        local members = {}

        if private.isPulsarGroup and private.pulsarGroupData then
            -- Creator as leader
            members[tostring(private.pulsarGroupData.Creator.SID)] = {
                identifier    = private.pulsarGroupData.Creator.SID,
                src           = private.pulsarGroupData.Creator.ID,
                characterName = private.pulsarGroupData.Creator.First .. " " .. private.pulsarGroupData.Creator.Last,
                isLeader      = true,
                online        = DoesPlayerExist(private.pulsarGroupData.Creator.ID),
            }

            -- Members
            for _, member in ipairs(private.pulsarGroupData.Members) do
                members[tostring(member.SID)] = {
                    identifier    = member.SID,
                    src           = member.ID,
                    characterName = member.First .. " " .. member.Last,
                    isLeader      = false,
                    online        = DoesPlayerExist(member.ID),
                }
            end
        else
            for identifier, memberData in pairs(private.members) do
                members[identifier] = {
                    identifier    = memberData.identifier,
                    src           = memberData.src,
                    characterName = memberData.characterName,
                    isLeader      = (private.leader and private.leader.identifier == identifier) or false,
                    online        = DoesPlayerExist(memberData.src),
                }
            end
        end
        return members
    end

    ---@return string[]
    public.getMembersIdentifiers = function()
        local identifiers = {}
        for identifier, _ in pairs(private.members) do
            identifiers[#identifiers + 1] = identifier
        end
        return identifiers
    end

    ---@return number | string[]
    public.getMembersPlayerIds = function()
        local playerIds = {}

        if private.isPulsarGroup and private.pulsarGroupData then
            playerIds[#playerIds+1] = private.pulsarGroupData.Creator.ID
            for _, member in ipairs(private.pulsarGroupData.Members) do
                playerIds[#playerIds+1] = member.ID
            end
        else
            for _, player in pairs(private.members) do
                playerIds[#playerIds+1] = player.src
            end
        end

        return playerIds
    end

    ---@param src number | string
    ---@return boolean
    public.isSrcAMember = function(src)
        if private.isPulsarGroup and private.pulsarGroupData then
            if tostring(private.pulsarGroupData.Creator.ID) == tostring(src) then
                return true
            end
            for _, member in ipairs(private.pulsarGroupData.Members) do
                if tostring(member.ID) == tostring(src) then
                    return true
                end
            end
            return false
        else
            for _, memberData in pairs(private.members) do
                if tostring(memberData.src) == tostring(src) then
                    return true
                end
            end
            return false
        end
    end

    ---@return number
    public.getMembersCount = function()
        if private.isPulsarGroup and private.pulsarGroupData then
            return 1 + #private.pulsarGroupData.Members
        else
            local count = 0
            for _, _ in pairs(private.members) do
                count = count + 1
            end
            return count
        end
    end

    ---@param activity { activityId: string, activityName: string }
    public.setActivity = function(activity)
        if private.isPulsarGroup and private.pulsarGroupData then
            exports['pulsar-labor']:SetGroupActivity(private.pulsarGroupData.Creator.ID, activity)
        else
            private.activity = activity
        end
    end

    public.getActivity = function()
        if private.isPulsarGroup and private.pulsarGroupData then
            return exports['pulsar-labor']:GetGroupActivity(private.pulsarGroupData.Creator.ID)
        else
            return private.activity
        end
    end

    public.clearActivity = function()
        if private.isPulsarGroup and private.pulsarGroupData then
            exports['pulsar-labor']:ClearGroupActivity(private.pulsarGroupData.Creator.ID)
        else
            private.activity = nil
        end
    end

    ---@param eventName string
    ---@param ... any
    public.triggerEvent = function(eventName, ...)
        local members = public.getMembers()
        if next(members) then
            local payload = msgpack.pack_args(...)
            local len = payload:len()
            for _, memberData in pairs(members) do
                ---@diagnostic disable-next-line: param-type-mismatch
                if DoesPlayerExist(memberData.src) then
                    ---@diagnostic disable-next-line: param-type-mismatch
                    TriggerClientEventInternal(eventName, tonumber(memberData.src), payload, len)
                end
            end
        end
    end

    ---@return boolean
    public.isAnyoneOnline = function()
        if private.isPulsarGroup and private.pulsarGroupData then
            if DoesPlayerExist(private.pulsarGroupData.Creator.ID) then
                return true
            end
            for _, member in ipairs(private.pulsarGroupData.Members) do
                if DoesPlayerExist(member.ID) then
                    return true
                end
            end
            return false
        else
            local members = public.getMembers()
            for _, memberData in pairs(members) do
                if DoesPlayerExist(memberData.src) then
                    return true
                end
            end
            return false
        end
    end

    public.disband = function()
        if private.isPulsarGroup then
            -- Pulsar groups disbanded via pulsar-labor API
            return
        end

        if private.partyUuid then
            local party = GetParty(private.partyUuid)
            if party and party.destroy then
                party.destroy()
            end
        end

        for _, memberData in pairs(private.members) do
            memberToGroupMap[tostring(memberData.identifier)] = nil
        end

        TriggerEvent("prp-bridge:server:groupDisbanded", private.uuid)

        groups[private.uuid] = nil

        private.members = {}
        private.leader = nil
        private.activity = nil

        private = nil
        public = nil
    end

    ---@return boolean
    public.isInviting = function()
        if private.isPulsarGroup and private.pulsarGroupData then
            return exports['pulsar-labor']:IsGroupInviting(private.pulsarGroupData.Creator.ID)
        end
        return private.isInviting
    end

    public.toggleInviting = function()
        if private.isPulsarGroup and private.pulsarGroupData then
            exports['pulsar-labor']:ToggleGroupInviting(private.pulsarGroupData.Creator.ID)
        else
            private.isInviting = not private.isInviting
        end
    end

    ---@param inviteUuid string
    ---@param targetSrc number | string
    public.addPendingInvite = function(inviteUuid, targetSrc)
        if private.isPulsarGroup then
            return
        end
        private.invites[tostring(inviteUuid)] = tostring(targetSrc)
    end

    ---@param inviteUuid string
    public.removePendingInvite = function(inviteUuid)
        if private.isPulsarGroup then
            return
        end
        private.invites[tostring(inviteUuid)] = nil
    end

    ---@param inviteUuid string
    ---@param targetSrc number | string
    public.isPendingInviteValid = function(inviteUuid, targetSrc)
        if private.isPulsarGroup then
            return false
        end
        local storedTarget = private.invites[tostring(inviteUuid)]
        if not storedTarget then
            return false
        end

        return tostring(storedTarget) == tostring(targetSrc)
    end

    ---@param partyType UniQueueType
    public.createUniqueueParty = function(partyType)
        if private.isPulsarGroup and private.pulsarGroupData then
            exports['pulsar-labor']:CreateGroupUniqueueParty(private.pulsarGroupData.Creator.ID, partyType)
            return
        end

        if private.partyUuid then
            local party = GetParty(private.partyUuid)
            if party then
                local members = party.getMembers()
                for identifier, _ in pairs(members) do
                    if not private.members[identifier] then
                        party.removeMember(identifier)
                    end
                end

                local groupMembers = public.getMembers()

                members = party.getMembers()

                for identifier, memberData in pairs(groupMembers) do
                    if not members[memberData.identifier] then
                        party.addMember(memberData.identifier)
                    end
                end
            end
        end

        local party = CreateUniqueueParty(partyType)

        private.partyUuid = party.getUUID()

        local groupMembers = public.getMembers()
        for identifier, memberData in pairs(groupMembers) do
            party.addMember(memberData.identifier)
        end
    end

    ---@param queueName string
    ---@return { success: boolean, error: string? }
    public.enterUniqueue = function(queueName)
        local partyUuid = public.getPartyUuid()

        if not partyUuid then
            return { success = false, error = locale("GROUP_HAS_NO_PARTY_IN_UNIQUEUE") }
        end

        local queue = GetQueue(queueName)
        if not queue then
            return { success = false, error = locale("QUEUE_NOT_FOUND_2") }
        end

        local party = GetParty(partyUuid)
        if not party then
            return { success = false, error = locale("GROUP_HAS_NO_PARTY_IN_UNIQUEUE") }
        end

        return queue.add(party)
    end

    public.clearPartyUuid = function()
        if private.isPulsarGroup and private.pulsarGroupData then
            exports['pulsar-labor']:ClearGroupPartyUuid(private.pulsarGroupData.Creator.ID)
        else
            private.partyUuid = nil
        end
    end

    ---@param lockedState boolean
    public.setLocked = function(lockedState)
        if type(lockedState) ~= "boolean" then
            return
        end

        if private.isPulsarGroup and private.pulsarGroupData then
            exports['pulsar-labor']:SetGroupLocked(private.pulsarGroupData.Creator.ID, lockedState)
            local members = public.getMembers()
            for _, memberData in pairs(members) do
                if DoesPlayerExist(memberData.src) then
                    bridge.fw.notify(memberData.src, "inform", lockedState and locale("GROUP_LOCKED") or locale("GROUP_UNLOCKED"))
                end
            end
        else
            if private.isLocked == lockedState then
                return
            end
            private.isLocked = lockedState

            for _, memberData in pairs(private.members) do
                if DoesPlayerExist(memberData.src) then
                    bridge.fw.notify(memberData.src, "inform", private.isLocked and locale("GROUP_LOCKED") or locale("GROUP_UNLOCKED"))
                end
            end
        end
    end

    ---@return boolean
    public.isLocked = function()
        if private.isPulsarGroup and private.pulsarGroupData then
            return exports['pulsar-labor']:IsGroupLocked(private.pulsarGroupData.Creator.ID)
        end
        return private.isLocked
    end

    groups[private.uuid] = public

    return public
end

---@param src string | number
---@return Group?
Groups.GetFromMember = function(src)
    ---@diagnostic disable-next-line: param-type-mismatch
    if not DoesPlayerExist(src) then
        return nil
    end

    local pulsarGroups = exports['pulsar-labor']:GetGroups()
    for _, pulsarGroup in ipairs(pulsarGroups) do
        if tostring(pulsarGroup.Creator.ID) == tostring(src) then
            return initGroupObject({
                uuid = tostring(pulsarGroup.Creator.ID),
                isPulsarGroup = true,
                pulsarGroupData = pulsarGroup,
            })
        end
        for _, member in ipairs(pulsarGroup.Members) do
            if tostring(member.ID) == tostring(src) then
                return initGroupObject({
                    uuid = tostring(pulsarGroup.Creator.ID),
                    isPulsarGroup = true,
                    pulsarGroupData = pulsarGroup,
                })
            end
        end
    end
    return nil
end

---@param identifier string
---@return Group?
Groups.GetFromMemberByIdentifier = function(identifier)
    local pulsarGroups = exports['pulsar-labor']:GetGroups()
    for _, pulsarGroup in ipairs(pulsarGroups) do
        if tostring(pulsarGroup.Creator.SID) == tostring(identifier) then
            return initGroupObject({
                uuid = tostring(pulsarGroup.Creator.ID),
                isPulsarGroup = true,
                pulsarGroupData = pulsarGroup,
            })
        end
        for _, member in ipairs(pulsarGroup.Members) do
            if tostring(member.SID) == tostring(identifier) then
                return initGroupObject({
                    uuid = tostring(pulsarGroup.Creator.ID),
                    isPulsarGroup = true,
                    pulsarGroupData = pulsarGroup,
                })
            end
        end
    end
    return nil
end

---@param leaderSrc string | number
---@return { success: boolean, error?: string, group?: Group }
Groups.Create = function(leaderSrc)
    local currentGroup = Groups.GetFromMember(leaderSrc)
    if currentGroup then
        return {
            success = false,
            error = locale("ALREADY_IN_GROUP")
        }
    end

    local success = exports['pulsar-labor']:CreateWorkgroup(leaderSrc)
    if success then
        Citizen.Wait(100)
        local pulsarGroups = exports['pulsar-labor']:GetGroups()
        for _, pulsarGroup in ipairs(pulsarGroups) do
            if tostring(pulsarGroup.Creator.ID) == tostring(leaderSrc) then
                local group = initGroupObject({
                    uuid = tostring(pulsarGroup.Creator.ID),
                    isPulsarGroup = true,
                    pulsarGroupData = pulsarGroup,
                })
                return {
                    success = true,
                    group = group
                }
            end
        end
    end
    return {
        success = false,
        error = locale("UNKNOWN_ERROR_ON_GROUP_CREATION")
    }
end

---@param partyUuid string
---@return Group?
Groups.GetGroupByPartyUuid = function(partyUuid)
    for _, group in pairs(groups) do
        if group.getPartyUuid() == partyUuid then
            return group
        end
    end

    local pulsarGroups = exports['pulsar-labor']:GetGroups()
    for _, pulsarGroup in ipairs(pulsarGroups) do
        if pulsarGroup.PartyUuid == partyUuid then
            return initGroupObject({
                uuid = tostring(pulsarGroup.Creator.ID),
                isPulsarGroup = true,
                pulsarGroupData = pulsarGroup,
            })
        end
    end

    return nil
end

---@param leaderSrc string | number
---@return { success: boolean, error?: string, group?: Group }
exports("CreateGroup", function(leaderSrc)
    return Groups.Create(leaderSrc)
end)

---@param src string | number
---@return Group?
exports("GetGroupFromMember", function(src)
    return Groups.GetFromMember(src)
end)

---@param identifier string
---@return Group?
exports("GetGroupFromMemberByIdentifier", function(identifier)
    return Groups.GetFromMemberByIdentifier(identifier)
end)

---@param uuid string
---@return Group?
exports("GetGroupByUuid", function(uuid)
    local pulsarGroups = exports['pulsar-labor']:GetGroups()
    for _, pulsarGroup in ipairs(pulsarGroups) do
        if tostring(pulsarGroup.Creator.ID) == tostring(uuid) then
            return initGroupObject({
                uuid = tostring(pulsarGroup.Creator.ID),
                isPulsarGroup = true,
                pulsarGroupData = pulsarGroup,
            })
        end
    end
    return nil
end)

---@param partyUuid string
---@return Group?
exports('GetGroupByPartyUuid', function(partyUuid)
    return Groups.GetGroupByPartyUuid(partyUuid)
end)

---@param src string | number
---@return string | nil
exports("GetGroupIdFromMember", function(src)
    local group = Groups.GetFromMember(src)
    if not group then
        return nil
    end

    return group.getUuid()
end)

---@param identifier string | number
---@return string | nil
exports("GetGroupIdFromMemberByIdentifier", function(identifier)
    local group = Groups.GetFromMemberByIdentifier(identifier)
    if not group then
        return nil
    end

    return group.getUuid()
end)


---@param uuid string
---@return number | string[]
exports("GetGroupPlayerIds", function(uuid)
    local group = exports['prp-bridge']:GetGroupByUuid(uuid)
    if not group then
        return nil
    end

    return group.getMembersPlayerIds()
end)

local function unloadPlayer(src)
    local cachedIdentifier = cachedPlayerIdentifiers[tostring(src)]
    if not cachedIdentifier then return end

    local group = Groups.GetFromMemberByIdentifier(cachedIdentifier)
    cachedPlayerIdentifiers[tostring(src)] = nil
    if not group then return end

    -- removeMember returns false for pulsar groups, that's OK
    group.removeMember(src)
end

AddEventHandler("playerDropped", function(reason)
    local src = source
    unloadPlayer(src)
end)

AddEventHandler("prp-bridge:server:playerUnload", unloadPlayer)
AddEventHandler("prp-bridge:uniqueue:partyDestroyed", function(partyUuid)
    local group = Groups.GetGroupByPartyUuid(partyUuid)
    if not group then
        return
    end

    group.clearPartyUuid()
end)

RegisterNetEvent("prp-bridge:server:requestGroupData", function()
    local src = source
    local group = Groups.GetFromMember(src)
    if not group then
        TriggerClientEvent("prp-bridge:client:openEntryGroupMenu", src)
        return
    end

    local members = group.getMembers()
    local leader = group.getLeader()
    local isLeader = group.isSrcALeader(src)

    TriggerClientEvent("prp-bridge:client:openGroupMenu", src, {
        uuid       = group.getUuid(),
        members    = members,
        isLeader   = isLeader,
        leader     = leader,
        activity   = group.getActivity(),
    })
end)

RegisterNetEvent("prp-bridge:server:createGroup", function()
    local src = source
    bridge.fw.notify(src, "info", "Create groups through the Phone Labor app")
end)

RegisterNetEvent("prp-bridge:server:toggleGroupsInviting", function()
    local src = source
    bridge.fw.notify(src, "info", "Use the Phone Labor app to manage group invites")
end)

RegisterNetEvent("prp-bridge:server:groupKick", function(targetSrc)
    local src = source

    local group = Groups.GetFromMember(src)
    if not group then
        bridge.fw.notify(src, "error", locale("NOT_IN_ANY_GROUP"))
        return
    end

    if tostring(src) == tostring(targetSrc) then
        bridge.fw.notify(src, "error", locale("CANNOT_KICK_YOURSELF"))
        return
    end

    if not group.isSrcALeader(src) then
        bridge.fw.notify(src, "error", locale("ONLY_LEADER_CAN_KICK"))
        return
    end

    if not group.isSrcAMember(targetSrc) then
        bridge.fw.notify(src, "error", locale("PLAYER_NOT_IN_YOUR_GROUP"))
        return
    end

    local pulsarGroups = exports['pulsar-labor']:GetGroups()
    for _, pulsarGroup in ipairs(pulsarGroups) do
        if tostring(pulsarGroup.Creator.ID) == tostring(src) then
            exports['pulsar-labor']:LeaveWorkgroup(pulsarGroup, targetSrc)
            bridge.fw.notify(src, "success", locale("PLAYER_KICKED_SUCCESSFULLY"))
            return
        end
    end
    bridge.fw.notify(src, "error", locale("NOT_IN_ANY_GROUP"))
end)

RegisterNetEvent("prp-bridge:server:groupLeave", function()
    local src = source

    local group = Groups.GetFromMember(src)
    if not group then
        bridge.fw.notify(src, "error", locale("NOT_IN_ANY_GROUP"))
        return
    end

    local pulsarGroups = exports['pulsar-labor']:GetGroups()
    local pulsarGroup = nil
    for _, pg in ipairs(pulsarGroups) do
        if tostring(pg.Creator.ID) == tostring(src) then
            pulsarGroup = pg
            break
        elseif not pulsarGroup then
            for _, member in ipairs(pg.Members) do
                if tostring(member.ID) == tostring(src) then
                    pulsarGroup = pg
                    break
                end
            end
        end
    end

    if pulsarGroup then
        if tostring(pulsarGroup.Creator.ID) == tostring(src) then
            exports['pulsar-labor']:DisbandWorkgroup(src, false)
            bridge.fw.notify(src, "success", locale("GROUP_DISBANDED_SUCCESSFULLY"))
        else
            exports['pulsar-labor']:LeaveWorkgroup(pulsarGroup, src)
            bridge.fw.notify(src, "success", locale("LEFT_GROUP_SUCCESSFULLY"))
        end
    else
        bridge.fw.notify(src, "error", locale("NOT_IN_ANY_GROUP"))
    end
end)

RegisterNetEvent("prp-bridge:server:inviteToGroup", function(targetSrc)
    local src = source
    local group = Groups.GetFromMember(src)
    if not group then
        bridge.fw.notify(src, "error", locale("NOT_IN_ANY_GROUP"))
        return
    end

    if not group.isSrcALeader(src) then
        bridge.fw.notify(src, "error", locale("ONLY_LEADER_CAN_INVITE"))
        return
    end

    local pulsarGroups = exports['pulsar-labor']:GetGroups()
    local pulsarGroup = nil
    for _, pg in ipairs(pulsarGroups) do
        if tostring(pg.Creator.ID) == tostring(src) then
            pulsarGroup = pg
            break
        end
    end

    if not pulsarGroup then
        bridge.fw.notify(src, "error", locale("NOT_IN_ANY_GROUP"))
        return
    end

    local success = exports['pulsar-labor']:RequestWorkgroup(pulsarGroup, targetSrc)
    if not success then
        bridge.fw.notify(src, "error", "Unable to send invite")
    end
end)

RegisterNetEvent("prp-bridge:server:acceptGroupInvite", function(inviteUuid, leaderSrc)
    local src = source

    local success = exports['pulsar-labor']:JoinWorkgroup(leaderSrc, src)
    if success then
        bridge.fw.notify(src, "success", locale("JOINED_GROUP_SUCCESSFULLY"))
    else
        bridge.fw.notify(src, "error", locale("FAILED_TO_JOIN_GROUP"))
    end
end)

RegisterNetEvent("prp-bridge:server:declineGroupInvite", function(inviteUuid, leaderSrc)
    local src = source

    local group = Groups.GetFromMember(leaderSrc)
    if not group then
        return
    end

    if not group.isPendingInviteValid(inviteUuid, src) then
        return
    end

    group.removePendingInvite(inviteUuid)

    local leader = group.getLeader()
    if not DoesPlayerExist(leader.src) then
        return
    end

    bridge.fw.notify(leader.src, "error", locale("DECLINED_GROUP_INVITE"))
end)

-- if BridgeConfig.Group.CommandEnabled then -- Enable for Debuging ONLY
--     bridge.fw.registerCommand(
--         BridgeConfig.Group.CommandName,
--         "",
--         nil,
--         nil,
--     function(src, args)
--         TriggerClientEvent("prp-bridge:client:requestGroupData", src)
--     end)
-- end
