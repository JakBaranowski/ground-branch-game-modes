local Teams = {
    Id = 0,
    Score = 0,
    Players = {
        All = {},
        Alive = {},
        Dead = {}
    },
    IncludeBots = false,
    RespawnCost = 1000,
    Display = {
        ScoreMessage = false,
        ScoreMilestone = true,
        ObjectiveMessage = true,
        ObjectivePrompt = true
    }
}

function Teams:Create(
    teamId,
    includeBots
)
    local team = {}
    setmetatable(team, self)
    self.__index = self
    self.Id = teamId
    self.Score = 0
    self.IncludeBots = includeBots
    self.Players.All = {}
    self.Players.Alive = {}
    self.Players.Dead = {}
    self.RespawnCost = 1000
    self.Display.ScoreMessage = false
    self.Display.ScoreMilestone = true
    self.Display.ObjectiveMessage = true
    self.Display.ObjectivePrompt = true
    print('Intialized Team ' .. tostring(team))
    return team
end

function Teams:SetRespawnCost(respawnCost)
    self.RespawnCost = respawnCost
end

function Teams:SetMessageImportance(messageImportance)
    self.MessageImportance = messageImportance
end

function Teams:GetId()
    return self.Id
end

function Teams:RoundStart(
    respawnCost,
    displayScoreMessage,
    displayScoreMilestone,
    displayObjectiveMessage,
    displayObjectivePrompt
)
    self.Score = 0
    self.RespawnCost = respawnCost
    self.Display.ScoreMessage = displayScoreMessage
    self.Display.ScoreMilestone = displayScoreMilestone
    self.Display.ObjectiveMessage = displayObjectiveMessage
    self.Display.ObjectivePrompt = displayObjectivePrompt
    self:UpdatePlayers()
    self:SetAllowedToRestart(false)
end

--#region Players

function Teams:UpdatePlayers()
    self.Players.All = gamemode.GetPlayerList(self.Id, self.IncludeBots)
    self.Players.Alive = {}
    self.Players.Dead = {}
    print('Found ' .. #self.Players.All .. ' Players')
    for i, playerInstance in ipairs(self.Players.All) do
        if player.GetLives(playerInstance) == 1 then
            print('Player ' .. i .. ' is alive')
            table.insert(self.Players.Alive, playerInstance)
        else
            print('Player ' .. i .. ' is dead')
            table.insert(self.Players.Dead, playerInstance)
        end
    end
end

function Teams:GetAllPlayersCount()
    return #self.Players.All
end

--#endregion

--#region Alive players

function Teams:GetAlivePlayers()
    return self.Players.Alive
end

function Teams:GetAlivePlayersCount()
    return #self.Players.Alive
end

function Teams:IsWipedOut()
    return #self.Players.Alive <= 0 and self.Score < self.RespawnCost
end

--#endregion

--#region Score

function Teams:IncreaseScore(scoringPlayer, reason, scoreIncrease)
    self.Score = self.Score + scoreIncrease
    if self.Score < 0 then
        self.Score = 0
    end
    self:SetAllowedToRestart(self.Score >= self.RespawnCost)
    local message = nil
    if scoreIncrease >= 0 then
        message = reason .. ' +' .. scoreIncrease .. ' [' .. self.Score .. ']'
    else
        message = reason .. ' -' .. -scoreIncrease .. ' [' .. self.Score .. ']'
    end
    if scoringPlayer then
        self:DisplayMessageToPlayer(scoringPlayer, message, 'Lower', 2.0, 'ScoreMessage')
    else
        self:DisplayMessageToAllPlayers(message, 'Lower', 2.0, 'ScoreMilestone')
    end
    return self.Score
end

function Teams:SetAllowedToRestart(allowRespawn)
    for _, playerInstance in ipairs(self.Players.All) do
        player.SetAllowedToRestart(playerInstance, allowRespawn)
    end
end

function Teams:PlayerDied(deadPlayer)
    if gamemode.GetRoundStage() ~= 'InProgress' then
        return
    end
    player.SetLives(deadPlayer, 1)
    self:UpdatePlayers()
end

function Teams:PlayerRespawned(respawnedPlayer)
    if gamemode.GetRoundStage() ~= 'InProgress' then
        return
    end
	self:IncreaseScore(nil, 'Respawn', -self.RespawnCost)
    player.SetLives(respawnedPlayer, 1)
    self:UpdatePlayers()
end

--#endregion

function Teams:DisplayMessageToPlayer(playerInstance, message, position, duration, messageType)
    if not self.Display[messageType] then
        return
    end
    player.ShowGameMessage(
        playerInstance,
        message,
        position,
        duration
    )
end

function Teams:DisplayMessageToAlivePlayers(message, position, duration, messageType)
    if not self.Display[messageType] then
        return
    end
    if #self.Players.Alive > 0 then
        for _, playerInstance in ipairs(self.Players.Alive) do
            player.ShowGameMessage(
                playerInstance,
                message,
                position,
                duration
            )
        end
    end
end

function Teams:DisplayMessageToAllPlayers(message, position, duration, messageType)
    if not self.Display[messageType] then
        return
    end
    if #self.Players.All > 0 then
        for _, playerInstance in ipairs(self.Players.All) do
            player.ShowGameMessage(
                playerInstance,
                message,
                position,
                duration
            )
        end
    end
end

function Teams:DisplayPromptToAlivePlayers(location, label, duration, messageType)
    if not self.Display[messageType] then
        return
    end
    if #self.Players.Alive > 0 then
        for _, playerInstance in ipairs(self.Players.Alive) do
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