local minigames = {} -- This is not tested

---@param resolve function
---@return table
local function makeEvents(resolve)
    return {
        onSuccess = function(data) resolve(true) end,
        onPerfect = function(data) resolve(true) end,
        onFail    = function(data) resolve(false) end,
    }
end

---@param gameName string
---@param gameOptions table?
---@param otherOptions OtherOptions?
---@return boolean
function minigames.play(gameName, gameOptions, otherOptions)
    local opts = gameOptions or {}
    local p = promise.new()
    local events = makeEvents(function(result) p:resolve(result) end)
    local name = gameName:lower()

    if name == "skillbar" then
        exports['pulsar-games']:MinigamePlaySkillbar(
            opts.timer      or 5000,
            opts.difficulty or 5,
            events,
            opts.action,
            opts.data
        )
    elseif name == "roundskillbar" then
        exports['pulsar-games']:MinigamePlayRoundSkillbar(
            opts.rate       or 1,
            opts.difficulty or 20,
            events,
            opts.action,
            opts.data
        )
    elseif name == "scanner" then
        exports['pulsar-games']:MinigamePlayScanner(
            opts.countdown  or 5,
            opts.timer      or 50,
            opts.limit      or 5000,
            opts.total      or 20,
            opts.difficulty or 5,
            opts.randomKey  ~= false,
            events,
            opts.action,
            opts.data
        )
    elseif name == "sequencer" then
        exports['pulsar-games']:MinigamePlaySequencer(
            opts.countdown  or 5,
            opts.flash      or 1000,
            opts.timer      or 10000,
            opts.difficulty or 4,
            opts.isMasked   or false,
            events,
            opts.action,
            opts.data
        )
    elseif name == "keypad" then
        exports['pulsar-games']:MinigamePlayKeypad(
            opts.code       or "1234",
            opts.countdown  or 5,
            opts.timer      or 30000,
            opts.isMasked   or false,
            events,
            opts.action,
            opts.data
        )
    elseif name == "scrambler" then
        exports['pulsar-games']:MinigamePlayScrambler(
            opts.countdown  or 5,
            opts.change     or 2000,
            opts.timer      or 30000,
            opts.strikes    or 3,
            opts.numbers    or 8,
            events,
            opts.action,
            opts.data
        )
    elseif name == "memory" then
        exports['pulsar-games']:MinigamePlayMemory(
            opts.countdown  or 5,
            opts.preview    or 3000,
            opts.timer      or 20000,
            opts.columns    or 4,
            opts.rows       or 4,
            opts.numActive  or 4,
            opts.strikes    or 3,
            events,
            opts.action,
            opts.data
        )
    elseif name == "aim" then
        exports['pulsar-games']:MinigamePlayAim(
            opts.countdown  or 5,
            opts.limit      or 15000,
            opts.timer      or 2000,
            opts.startSize  or 20,
            opts.maxSize    or 80,
            opts.growthRate or 5,
            opts.accuracy   or 70,
            opts.isMoving   or false,
            events,
            opts.action,
            opts.data
        )
    elseif name == "captcha" then
        exports['pulsar-games']:MinigamePlayCaptcha(
            opts.countdown   or 5,
            opts.timer       or 3000,
            opts.limit       or 20000,
            opts.difficulty  or 5,
            opts.difficulty2 or 3,
            events,
            opts.action,
            opts.data
        )
    elseif name == "keymaster" then
        exports['pulsar-games']:MinigamePlayKeymaster(
            opts.countdown  or 5,
            opts.timer      or { 2000, 3000 },
            opts.limit      or 20000,
            opts.difficulty or 2,
            opts.chances    or 3,
            opts.isShuffled or false,
            events,
            opts.action,
            opts.data
        )
    elseif name == "pattern" then
        exports['pulsar-games']:MinigamePlayPattern(
            opts.countdown   or 5,
            opts.limit       or 20000,
            opts.size        or 3,
            opts.difficulty  or 4,
            opts.difficulty2 or 2,
            opts.charset     or false,
            events,
            opts.action,
            opts.data
        )
    elseif name == "icons" then
        exports['pulsar-games']:MinigamePlayIcons(
            opts.countdown   or 5,
            opts.timer       or 5,
            opts.limit       or 20000,
            opts.delay       or 2000,
            opts.difficulty  or 8,
            opts.difficulty2 or 3,
            events,
            opts.action,
            opts.data
        )
    elseif name == "tracking" then
        exports['pulsar-games']:MinigamePlayTracking(
            opts.countdown  or 5,
            opts.delay      or 3000,
            opts.limit      or 20000,
            opts.difficulty or 3,
            events,
            opts.action,
            opts.data
        )
    elseif name == "drill" then
        exports['pulsar-games']:MinigamePlayDrill(events, opts.data)
    end

    return Citizen.Await(p)
end

function minigames.stop()
    exports['pulsar-games']:MinigameCancel()
end

---@return boolean
function minigames.isPlaying()
    return false
end

return minigames