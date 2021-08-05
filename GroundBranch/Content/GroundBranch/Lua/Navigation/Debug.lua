local Debug = {
    playerList = {}
}

Debug.__index = Debug

function Debug.ShowRoute(playerTeamId, route, prefix, duration)
    if Debug.playerList[playerTeamId] == nil then
        print('Player list for team ' .. playerTeamId .. ' not available')
        Debug.playerList[playerTeamId] = gamemode.GetPlayerList(
            1,
            playerTeamId,
            false,
            0,
            true
        )
    end
    for _, playerInstance in ipairs(Debug.playerList[playerTeamId]) do
        for i, point in ipairs(route) do
            player.ShowWorldPrompt(
                playerInstance,
                point,
                prefix .. '_' .. i,
                duration
            )
        end
    end
end

return Debug