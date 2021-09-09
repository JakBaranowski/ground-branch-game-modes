local Debug = {
    playerList = {}
}

Debug.__index = Debug

---This will show the route as world prompts to all selected players.
---Should be used for debugging.
---@param playerTeamId integer ID of the player team to display the world prompts to.
---@param route table a list of steps on the route.
---@param prefix string a prefix to add for route world prompts.
---@param duration number the time for which the points should be displayed to players.
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