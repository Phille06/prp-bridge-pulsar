CreateThread(function()
    bridge.fw.contextMenu({
        id = "group-entry",
        title = locale("GROUPS"),
        options = {
            {
                title = locale("NOT_IN_ANY_GROUP"),
                icon = "people-group",
                iconColor = "#4b89db",
                readOnly = true,
            },
            {
                title = locale("NEW_GROUP"),
                icon = "plus",
                onSelect = function()
                    TriggerServerEvent("prp-bridge:server:createGroup")
                end,
            },
        }
    })
end)

RegisterNetEvent("prp-bridge:client:requestGroupData", function()
    TriggerServerEvent("prp-bridge:server:requestGroupData")
end)

RegisterNetEvent("prp-bridge:client:openEntryGroupMenu", function()
    bridge.fw.showContext("group-entry")
end)

RegisterNetEvent("prp-bridge:client:openGroupMenu", function(data)
    local activityText = data.activity?.activityName and locale("CURRENT_ACTIVITY", data.activity.activityName) or locale("NO_ACTIVE_ACTIVITY")
    local options = {
        {
            title = locale("SHOW_GROUP_LEADER", data.leader.characterName),
            description = activityText,
            icon = "people-group",
        },
    }

    if data.isLeader then
        table.insert(options, {
            title = locale("MEMBERS"),
            description = locale("TOGGLE_INVITING"),
            arrow = true,
            icon = "users-line",
            serverEvent = "prp-bridge:server:toggleGroupsInviting",
        })
    end

    local serverId = tostring(GetPlayerServerId(PlayerId()))

    for _, v in pairs(data.members) do
        local src = tostring(v.src)
        if data.isLeader then
            table.insert(options, {
                title = v.characterName,
                icon = src == serverId and "crown" or "user",
                iconColor = v.online and "#228b22" or "#FFD700",
                readOnly = src == serverId,
                arrow = src ~= serverId,
                onSelect = function()
                    local alert = bridge.fw.confirmDialog(locale("CONFIRMATION"), locale("REMOVE_MEMBER_FROM_GROUP", v.characterName))
                    if alert ~= "confirm" then return end

                    TriggerServerEvent("prp-bridge:server:groupKick", src)
                end,
            })
        else
            table.insert(options, {
                title = v.characterName,
                icon = src == serverId and "crown" or "user",
                iconColor = v.online and "#228b22" or "#FFD700",
                readOnly = true,
            })
        end
    end

    table.insert(options, {
        title = data.isLeader and locale("DISBAND_GROUP") or locale("LEAVE_GROUP"),
        icon = "trash",
        onSelect = function()
            local alert = bridge.fw.confirmDialog(
                locale("CONFIRMATION"),
                data.isLeader and locale("DISBAND_CONFIRM") or locale("LEAVE_CONFIRM")
            )

            if alert ~= "confirm" then return end

            TriggerServerEvent("prp-bridge:server:groupLeave")
        end,
    })

    bridge.fw.contextMenu({
        id = "group-menu",
        title = locale("GROUPS"),
        options = options,
    })

    bridge.fw.showContext("group-menu")
end)

RegisterNetEvent("prp-bridge:client:toggleGroupInviting", function(invitingState)
    if not invitingState then
        bridge.fw.notify("success", locale("NO_LONGER_INV_PLAYERS"))
        bridge.target.removeGlobalPlayer({ "group-invite" })
        return
    end

    bridge.fw.notify("success", locale("INVITING_PLAYERS"))

    bridge.target.addGlobalPlayer({
        {
            name = "group-invite",
            label = locale("INVITE_TO_GROUP"),
            icon = "fa-solid fa-hands",
            distance = 2.0,
			onSelect = function(data)
				local src = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
				TriggerServerEvent("prp-bridge:server:inviteToGroup", src)
			end
        },
    })
end)

-- exports.ox_target:addGlobalPlayer({
--     {
--         name = "group-menu",
--         label = locale("GROUPS"),
--         icon = "fa-solid fa-people-group",
--         distance = 2.0,
--         onSelect = function()
--             TriggerServerEvent("prp-bridge:server:requestGroupData")
--         end,
--     }
-- })

RegisterNetEvent("prp-bridge:client:receiveGroupInvite", function(inviteData)
    local alert = bridge.fw.confirmDialog(locale("GROUP_INVITE"), locale("GROUP_INVITE_FROM", inviteData.inviterName))
    if alert == "confirm" then
        TriggerServerEvent("prp-bridge:server:acceptGroupInvite", inviteData.inviteUuid, inviteData.inviteSrc)
    else
        TriggerServerEvent("prp-bridge:server:declineGroupInvite", inviteData.inviteUuid, inviteData.inviteSrc)
    end
end)
