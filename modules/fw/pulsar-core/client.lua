local fw = {}

---@return number
function fw.getStress()
    local s = exports['pulsar-status']:GetSingle('stress')
    return s and s.value or 0
end

---@return number
function fw.getHunger()
    local s = exports['pulsar-status']:GetSingle('hunger')
    return s and s.value or 100
end

---@return number
function fw.getThirst()
    local s = exports['pulsar-status']:GetSingle('thirst')
    return s and s.value or 100
end

---@param statusType string
---@param value number
function fw.setStatus(statusType, value)
    exports['pulsar-status']:Set(statusType, value)
end

function fw.applyBuff(buff, data)
    -- Integrations with other resources, this is needed for ie prp-drugs, but thats done in prp-drugs
end

function fw.clearBuffs()
    -- Integrations with other resources, this is needed for ie prp-drugs, but thats done in prp-drugs
end

---@param type 'inform' | 'error' | 'success' | 'warning'
---@param message string
---@param title? string
---@param duration? number
function fw.notify(type, message, title, duration)
    if type == 'error' then
        exports['pulsar-hud']:Notification("error", message, duration or 3000)
    elseif type == 'success' then
        exports['pulsar-hud']:Notification("success", message, duration or 3000)
    elseif type == 'warning' then
        exports['pulsar-hud']:Notification("warning", message, duration or 3000)
    else
        exports['pulsar-hud']:Notification("info", message, duration or 3000)

    end
end

---@param text string
---@param options { position?: ShowTextUIPos, icon?: string | table<string>, iconColor?: string, iconAnimation?: ShowTextUIAnims, alignIcon?: "top" | "center" }
function fw.showTextUI(text, options)
    exports['pulsar-hud']:ActionShow('prp-bridge', text)
end

function fw.hideTextUI()
    exports['pulsar-hud']:ActionHide('prp-bridge')
end

---@return boolean
---@return string | nil
function fw.isTextUIOpen()
    -- pulsar's Action component has no open-state query; return false as safe default
    return false, nil
end

---@param payload FWProgressBar
---@return boolean?
function fw.progressBar(payload)
    -- I have made a ox_lib bridge if you want to use that
    local options = {
        duration = payload.duration or 5000,
        label = payload.label,
        useWhileDead = false,
        allowRagdoll = payload.allowRagdoll or false,
        allowSwimming = payload.allowSwimming or false,
        allowCuffed = payload.allowCuffed or false,
        allowFalling = payload.allowFalling or false,
        canCancel = payload.canCancel or false,
        disable = {
            move = true,
            combat = true,
            sprint = true
        }
    }

    if payload.controlDisables then
        if payload.controlDisables.disableMovement == false then
            options.disable.move = false
        end

        if payload.controlDisables.disableCombat == false then
            options.disable.combat = false
        end

        if payload.controlDisables.disableSprint == false then
            options.disable.sprint = false
        end
    end

    if payload.animation and payload.animation.animDict and payload.animation.animClip then
        options.anim = {
            dict = payload.animation.animDict,
            clip = payload.animation.animClip,
        }

        if payload.animation.animFlag then
            options.anim.flag = payload.animation.animFlag
        end
    elseif payload.animation and payload.animation.scenario then
        options.anim = {
            scenario = payload.animation.scenario
        }
    end

    return lib.progressBar(options)
end

---@param header string
---@param content string
---@param labels? {cancel?: string, confirm?: string}
---@param timeout? number
---@return 'cancel'|'confirm'|nil
function fw.confirmDialog(header, content, labels, timeout)
    -- pulsar uses its own confirm UI; delegate to ox_lib alert as fallback
    -- I have made a ox_lib bridge if you want to use that
    return lib.alertDialog({
        header  = header,
        content = content,
        centered = true,
        cancel  = true,
        labels  = labels or { cancel = locale('Cancel'), confirm = locale('Confirm') },
    }, timeout)
end

---@param heading string
---@param rows string[] | InputDialogRowProps[]
---@param options InputDialogOptionsProps[]?
---@return string[] | number[] | boolean[] | nil
function fw.inputDialog(heading, rows, options)
    -- I have made a ox_lib bridge if you want to use that
    return lib.inputDialog(heading, rows, options)
end

---@param payload FWContextMenuProps | FWContextMenuProps[]
function fw.contextMenu(payload)
    -- I have made a ox_lib bridge if you want to use that
    lib.registerContext(payload)
end

---@param contextId string
function fw.showContext(contextId)
    -- I have made a ox_lib bridge if you want to use that
    lib.showContext(contextId)
end

---@return boolean
function fw.isOnDuty()
    return LocalPlayer.state.onDuty or false
end

---@param job string
---@param grade number?
---@param duty boolean?
---@return table | boolean
function fw.hasJob(job, grade, duty)
    if not LocalPlayer.state.loggedIn then return false end
    return exports['pulsar-jobs']:HasJob(job, nil, nil, grade, duty)
end

---@return string?
function fw.getIdentifier()
    local char = LocalPlayer.state.Character
    if not char then return nil end
    local sid = tostring(char:GetData('SID'))
    return sid
end

---@return string?
function fw.getCharacterName()
    local char = LocalPlayer.state.Character
    if not char then return nil end
    return string.format('%s %s', char:GetData('First'), char:GetData('Last'))
end

return fw