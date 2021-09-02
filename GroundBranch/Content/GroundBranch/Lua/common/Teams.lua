local Teams = {
    Id = 0,
    Score = 0,
    Players = {},
    PlayersAlive = {},
    IncludeBots = false,
    DisplayScore = nil,
    RespawnType = 0,
    RespawnCost = 1000
}

function Teams:Create(
    teamId,
    includeBots,
    displayScore,
    respawnType,
    respawnCost
)
    local team = {}
    setmetatable(team, self)
    self.__index = self
    self.Id = teamId
    self.Score = 0
    self.IncludeBots = includeBots
    self.Players = gamemode.GetPlayerList(self.Id, self.IncludeBots)
    self.PlayersAlive = gamemode.GetPlayerListByLives(self.Id, 1, self.IncludeBots)
    self.DisplayScore = displayScore
    self.RespawnType = respawnType or 0
    self.RespawnCost = respawnCost or 1000
    print('Intialized Team ' .. tostring(team))
    return team
end

function Teams:SetDisplayScore(displayScore)
    self.DisplayScore = displayScore
end

function Teams:SetRespawnType(respawnType)
    self.RespawnType = respawnType
end

function Teams:SetRespawnCost(respawnCost)
    self.RespawnCost = respawnCost
end

function Teams:GetId()
    return self.Id
end

function Teams:Reset()
    self:UpdatePlayers()
    self:UpdateAlivePlayers()
    self:SetScore(0)
end

--#region Players

function Teams:UpdatePlayers()
    self.Players = gamemode.GetPlayerList(self.Id, self.IncludeBots)
end

function Teams:GetPlayers()
    return self.Players
end

function Teams:GetPlayersCount()
    return #self.Players
end

--#endregion

--#region Alive players

function Teams:UpdateAlivePlayers(minLives)
    self.PlayersAlive = gamemode.GetPlayerListByLives(
        self.Id,
        minLives,
        self.IncludeBots
    )
end

function Teams:GetAlivePlayers()
    return self.PlayersAlive
end

function Teams:GetAlivePlayersCount()
    return #self.PlayersAlive
end

function Teams:IsWipedOut()
    if self.RespawnType == 1 then
        return #self.PlayersAlive == 0 and self.Score < self.RespawnCost
    else
        return #self.PlayersAlive == 0
    end
end

--#endregion

--#region Score

function Teams:SetScore(score)
    self.Score = score
end

function Teams:GetScore()
    return self.Score
end

function Teams:IncreaseScore(scoreIncrease, reason)
    self.Score = self.Score + scoreIncrease
    if self.DisplayScore then
        local message = reason .. scoreIncrease .. ' [' .. self.Score .. ']'
        self:DisplayMessage(message, 2.0, 'Lower')
    end
    if self.RespawnType == 1 then
        self:SetAllowedToRespawn(self.Score >= self.RespawnCost)
    end
    return self.Score
end

function Teams:SetAllowedToRespawn(allowed)
    for _, playerInstance in ipairs(self.Players) do
        player.SetAllowedToRestart(playerInstance, allowed)
    end
end

function Teams:PlayerDied(playerInstance)
    if self.RespawnType == 2 then
        return
    end
    player.SetLives(
        playerInstance,
        player.GetLives(playerInstance) - 1
    )
    self:UpdateAlivePlayers(1)
end

function Teams:RespawnPlayer(playerInstance)
    if self.RespawnType ~= 1 or gamemode.GetRoundStage() ~= 'InProgress' then
        return
    end
	self:IncreaseScore(-self.RespawnCost, 'Respawn')
	player.SetLives(
		playerInstance,
		player.GetLives(playerInstance) + 1
	)
	self:UpdateAlivePlayers(1)
end

--#endregion

function Teams:DisplayMessage(message, duration, position)
    if self.Players and #self.PlayersAlive then
        for _, playerInstance in ipairs(self.Players) do
            player.ShowGameMessage(
                playerInstance,
                message,
                position,
                duration
            )
        end
    end
end

function Teams:DisplayPrompt(label, duration, location)
    if self.Players and #self.Players > 0 then
        for _, playerInstance in ipairs(self.Players) do
            player.ShowWorldPrompt(
                playerInstance,
                location,
                label,
                duration
            )
        end
    end
end

return Teams