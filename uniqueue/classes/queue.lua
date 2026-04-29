local mt = {
    __index = function(self, key)

    end
}

---@alias UniQueueType "civ" | "crime"

---@class UniQueue
---@field getName fun(): string
---@field getNumOfExecTasks fun(): number
---@field isExecAtFullCapacity fun(): boolean
---@field getUsedPolicePower fun(): number
---@field add fun(party: UniQueueParty): { success: boolean, error: string? }
---@field remove fun(party: UniQueueParty)
---@field setPartyPriority fun(party: UniQueueParty, priority: number)
---@field getPartyPriority fun(partyUuid: string): number | nil
---@field getPartyPosition fun(partyUuid: string): number | nil
---@field setExecFunction fun(func: fun(queueName: string, partyUuid: string, partyMembers: string[], taskId: string)) -- party members as array of identifiers
---@field setTaskIsExecuting fun(taskId: string, isExecuting: boolean, partyUuid: string?)
---@field stopExec fun(partyUuid: string)
---@field setCooldown fun(cooldown: number)
---@field clearCooldown fun()
---@field setBlocked fun(blocked: boolean)
---@field isBlocked fun(): boolean
---@field setCheckFunction fun(func: fun(queueName: string, partyUuid: string): boolean)
---@field isPartyIn fun(partyUuid: string): boolean
---@field process fun()

---@param seconds number
---@return string
local function timeStr(seconds)
    if seconds < 60 then
        local unit = seconds == 1 and "second" or "seconds"
        return string.format("%d %s", seconds, unit)
    elseif seconds < 3600 then
        local minutes = math.floor(seconds / 60)
        local unit = minutes == 1 and "minute" or "minutes"
        return string.format("%d %s", minutes, unit)
    elseif seconds < 86400 then
        local hours = math.floor(seconds / 3600)
        local unit = hours == 1 and "hour" or "hours"
        return string.format("%d %s", hours, unit)
    else
        local days = math.floor(seconds / 86400)
        local unit = days == 1 and "day" or "days"
        return string.format("%d %s", days, unit)
    end
end

---@return string, any
local function generateUUID()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return template:gsub("[xy]", function(c)
        local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
        return string.format("%x", v)
    end)
end

local checkFuncNumOfPartiesBeforeExec <const> = 5 -- How many parties to check concurrently before trying to execute task

---@param name string
---@param type UniQueueType
---@param requiredPolicePower number
---@param maxConcurrentTasks number
---@param cooldown number in seconds
function CreateUniqueue(name, type, requiredPolicePower, maxConcurrentTasks, cooldown)
    local public = {}
    local private = {
        idPool = 0,
        locked = false,
        name = name,
        partyList = {},
        partyMap = {},
        requiredPolicePower = requiredPolicePower,
        maxConcurrentTasks = maxConcurrentTasks,
        cooldown = cooldown or 5,
        lastCooldown = -99999999,
        execFunc = nil,
        checkFunc = nil,
        executingTasks = {},
        partiesToExecTasks = {},
        blockQueue = false,
        type = type
    }

    setmetatable(public, mt)

    private.lock = function()
        if private.locked then
            local timeout = 0
            while private.locked and timeout < 5 do
                timeout = timeout + 1
                Wait(50)
            end
        end

        private.locked = true
    end

    private.unlock = function()
        private.locked = false
    end

    ---@return number
    private.getNextEnterId = function()
        if private.idPool < 2097120 then
            private.idPool = private.idPool + 1
        else
            private.idPool = 0
        end
        return private.idPool
    end

    private.internalProcess = function()
        if private.execFunc == nil then
            lib.print.debug(("Error: Exec function is not set for UniQueue: ^2%s^7"):format(private.name))
            return
        end

        if private.checkFunc ~= nil then
            local toCheckCount = math.min((checkFuncNumOfPartiesBeforeExec + 1), #private.partyList)
            if toCheckCount <= 1 then
                goto continue
            end

            for i = 2, toCheckCount do
                local partyUuid = private.partyList[i]
                local party = GetParty(partyUuid)
                if party ~= nil then
                    CreateThread(function()
                        local status, err = pcall(private.checkFunc, private.name, partyUuid)
                        if not status then
                            lib.print.debug(("Error: Check function in UniQueue: ^2%s^7 failed for party: ^3%s^7 with error: ^1%s^7"):format(
                                private.name,
                                partyUuid,
                                err
                            ))
                        end
                    end)
                end
            end

            ::continue::
        end

        if os.time() - private.lastCooldown < private.cooldown then
            QueuePrint(private.name, "^5Cooldown remaining:^7 " .. timeStr(private.cooldown - (os.time() - private.lastCooldown)))
            return
        end

        local partyUuid = private.partyList[1] -- Get first party in queue
        if partyUuid == nil then return end

        local party = GetParty(partyUuid)
        if party == nil then return end

        if GetFreePolicePower() < private.requiredPolicePower then return end
        if private.blockQueue then
            QueuePrint(private.name, "^5Queue is currently blocked from processing^7")
            return
        end
        if IsTotalyBlocked then return end

        if private.checkFunc ~= nil then
            local checkedOkay = false
            local status, err = pcall(function()
                checkedOkay = private.checkFunc(private.name, partyUuid)
            end)

            if not status then
                lib.print.debug(("Error: Check function in Queue: ^2%s^7 failed for party: ^3%s^7 with error: ^1%s^7"):format(
                    private.name,
                    partyUuid,
                    tostring(err)
                ))
                return
            end

            if not checkedOkay then
                QueuePrint(private.name, "Party: " .. tostring(partyUuid) .. " - check function returned false, it won't proceed.")
                return
            end
        end

        local taskId = tostring(private.name) .. "-" .. tostring(generateUUID())

        public.setTaskIsExecuting(taskId, true, partyUuid)

        local status, err = pcall(function()
            CreateThread(function()
                private.execFunc(private.name, party.getUUID(), party.getMembersAsArray(), taskId)
            end)
        end)
        if not status then
            lib.print.debug(("Error: Exec function in Queue: ^2%s^7 failed for party: ^3%s^7 with error: ^1%s^7"):format(
                private.name,
                partyUuid,
                tostring(err)
            ))
        end

        public.remove(party)
        party.destroy()
    end

    -- public methods

    ---@return string
    public.getName = function()
        return private.name
    end

    ---@return number
    public.getNumOfExecTasks = function()
        local count = 0
        for _, _ in pairs(private.executingTasks) do
            count = count + 1
        end
        return count
    end

    ---@return boolean
    public.isExecAtFullCapacity = function()
        return public.getNumOfExecTasks() >= private.maxConcurrentTasks
    end

    ---@return number
    public.getUsedPolicePower = function()
        return public.getNumOfExecTasks() * private.requiredPolicePower
    end

    ---@param party UniQueueParty
    ---@return { success: boolean, error: string? }
    public.add = function(party)
        local partyUuid = party.getUUID()

        if private.partyMap[partyUuid] then
            return { success = false, error = locale("PARTY_ALREADY_IN_QUEUE") }
        end

        if party.getType() ~= private.type then
            return { success = false, error = locale("PARTY_TYPE_MISMATCH") }
        end

        private.lock()

        private.partyMap[partyUuid] = true

        local index = #private.partyList + 1
        private.partyList[index] = partyUuid
        party.setEnterId(private.getNextEnterId())
        party.setPosition(index)

        QueuePrint(private.name, ("Added party: %s to queue: %s"):format(tostring(partyUuid), tostring(private.name)))

        private.unlock()

        return { success = true }
    end

    ---@param party UniQueueParty
    public.remove = function(party)
        local partyUuid = party.getUUID()

        if not private.partyMap[partyUuid] then
            return
        end

        private.lock()

        for i = 1, #private.partyList do
            if private.partyList[i] == partyUuid then
                table.remove(private.partyList, i)
                private.partyMap[partyUuid] = nil
                private.partiesToExecTasks[partyUuid] = nil
                break
            end
        end

        private.unlock()
    end

    ---@param party UniQueueParty
    ---@param priority number
    public.setPartyPriority = function(party, priority)
        local partyUuid = party.getUUID()

        if not private.partyMap[partyUuid] then
            return
        end

        party.setPriority(priority)
    end

    ---@param partyUuid string
    ---@return number | nil
    public.getPartyPriority = function(partyUuid)
        if not private.partyMap[partyUuid] then
            return nil
        end

        local party = GetParty(partyUuid)
        return party?.getPriority()
    end

    ---@param partyUuid string
    ---@return number | nil
    public.getPartyPosition = function(partyUuid)
        if not private.partyMap[partyUuid] then
            return nil
        end

        local party = GetParty(partyUuid)
        return party?.getPosition()
    end

    ---@param func fun(queueName: string, partyUuid: string, partyMembers: string[], taskId: string)
    public.setExecFunction = function(func)
        private.execFunc = func
    end

    ---@param taskId string
    ---@param isExecuting boolean
    ---@param partyUuid string?
    public.setTaskIsExecuting = function(taskId, isExecuting, partyUuid)
        if isExecuting then
            private.executingTasks[taskId] = true
            if partyUuid then private.partiesToExecTasks[partyUuid] = taskId end
        else
            if public.isExecAtFullCapacity() then
                private.lastCooldown = os.time()
            end

            private.executingTasks[taskId] = nil

            for pUuid, tId in pairs(private.partiesToExecTasks) do
                if tId == taskId then
                    private.partiesToExecTasks[pUuid] = nil
                    break
                end
            end
        end
    end

    ---@param partyUuid string
    public.stopExec = function(partyUuid)
        local taskId = private.partiesToExecTasks[partyUuid]
        if taskId then
            public.setTaskIsExecuting(taskId, false, partyUuid)
        end
    end

    ---@param cooldown number in seconds
    public.setCooldown = function(cooldown)
        private.cooldown = cooldown
    end

    public.clearCooldown = function()
        private.lastCooldown = -99999999
    end

    ---@param blocked boolean
    public.setBlocked = function(blocked)
        private.blockQueue = blocked
    end

    ---@return boolean
    public.isBlocked = function()
        return private.blockQueue
    end

    ---@param func fun(queueName: string, partyUuid: string): boolean
    public.setCheckFunction = function(func)
        private.checkFunc = func
    end

    ---@param partyUuid string
    ---@return boolean
    public.isPartyIn = function(partyUuid)
        return private.partyMap[partyUuid] ~= nil
    end

    public.process = function()
        private.lock()

        if #private.partyList > 0 then
            for i=#private.partyList, 1, -1 do
                local partyUuid = private.partyList[i]
                local party = GetParty(partyUuid)
                if party then
                    party.addOverTimePrio()
                else
                    table.remove(private.partyList, i)
                    private.partyMap[partyUuid] = nil
                    private.partiesToExecTasks[partyUuid] = nil
                end
            end

            table.sort(private.partyList, function(aUuid, bUuid)
                local a = GetParty(aUuid)
                local b = GetParty(bUuid)

                if not a or not b then return false end -- This should never happen.

                if a.getPriority() == b.getPriority() then
                    return a.getEnterId() < b.getEnterId()
                end

                return a.getPriority() > b.getPriority()
            end)

            QueuePrint(private.name, "Queue: ^5" .. tostring(private.name) .. "^7 parties:")
            for i=1, #private.partyList do
                local partyUuid = private.partyList[i]
                local party = GetParty(partyUuid)
                if party then
                    party.setPosition(i)
                    QueuePrint(private.name, tostring(party.getUUID()) .. " priority: " .. tostring(party.getPriority()))
                end
            end
        else
            QueuePrint(private.name, "Queue: " .. tostring(private.name) .. " is empty")
        end

        if not public.isExecAtFullCapacity() then
            private.internalProcess()
        else
            QueuePrint(private.name, "^5Max concurrent tasks reached")
        end

        QueuePrint(private.name, "^6Current Tasks:^7 " .. json.encode(private.executingTasks, { indent = true }))
        QueuePrint(private.name, "^6Free police strength: " .. tostring(GetFreePolicePower()) .. "^7")

        private.unlock()
    end

    Queues[name] = public
    QueuesByType[type] = QueuesByType[type] or {}
    QueuesByType[type][name] = true

    return public
end