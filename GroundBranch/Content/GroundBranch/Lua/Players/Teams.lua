local Teams = {
    Id = 0,
    Score = 0,
    Milestones = 0,
    Players = {
        All = {},
        Alive = {},
        Dead = {},
    },
    IncludeBots = false,
    RespawnCost = 1000,
    Display = {
        ScoreMessage = false,
        ScoreMilestone = true,
        ObjectiveMessage = true,
        ObjectivePrompt = true
    },
    PlayerStarts = {},
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
    self.Milestones = 0
    self.IncludeBots = includeBots
    self.Players.All = {}
    self.Players.Alive = {}
    self.Players.Dead = {}
    self.RespawnCost = 1000
    self.Display.ScoreMessage = false
    self.Display.ScoreMilestone = true
    self.Display.ObjectiveMessage = true
    self.Display.ObjectivePrompt = true
    local allPlayerStarts = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBPlayerStart')
	for _, playerStart in ipairs(allPlayerStarts) do
		if actor.GetTeamId(playerStart) == teamId then
			table.insert(self.PlayerStarts, playerStart)
		end
	end
    print('Intialized Team ' .. tostring(team))
    return team
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
    self.Milestones = 0
    self.RespawnCost = respawnCost
    self.Display.ScoreMessage = displayScoreMessage
    self.Display.ScoreMilestone = displayScoreMilestone
    self.Display.ObjectiveMessage = displayObjectiveMessage
    self.Display.ObjectivePrompt = displayObjectivePrompt
    self:SetAllowedToRespawn(self.Score >= self.RespawnCost)
    self:UpdatePlayers()
end

--#region Players

function Teams:UpdatePlayers()
    self.Players.All = gamemode.GetPlayerList(self.Id, self.IncludeBots)
    self.Players.Alive = {}
    self.Players.Dead = {}
    print('Found ' .. #self.Players.All .. ' Players')
    for i, playerState in ipairs(self.Players.All) do
        if player.GetLives(playerState) == 1 then
            print('Player ' .. i .. ' is alive')
            table.insert(self.Players.Alive, playerState)
        else
            print('Player ' .. i .. ' is dead')
            table.insert(self.Players.Dead, playerState)
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

function Teams:ChangeScore(scoringPlayer, reason, scoreChange)
    self.Score = self.Score + scoreChange
    if self.Score < 0 then
        self.Score = 0
    end
    print('Changed team score to ' .. self.Score)

    local message = nil
    if scoreChange >= 0 then
        message = reason .. ' +' .. scoreChange .. ' [' .. self.Score .. ']'
    else
        message = reason .. ' -' .. -scoreChange .. ' [' .. self.Score .. ']'
    end
    self:DisplayMessageToPlayer(scoringPlayer, message, 'Lower', 2.0, 'ScoreMessage')

    if self.RespawnCost == 0 then
        return
    end
    self:SetAllowedToRespawn(self.Score >= self.RespawnCost)
    local newMilestone = math.floor(self.Score / self.RespawnCost)
    if newMilestone ~= self.Milestones then
        message = 'Respawns available ' .. newMilestone
        self.Milestones = newMilestone
        self:DisplayMessageToAllPlayers(message, 'Lower', 2.0, 'ScoreMilestone')
    end

    return self.Score
end

--#endregion

--#region Respawns

function Teams:SetAllowedToRespawn(respawnAllowed)
    print('Setting team allowed to respawn to ' .. tostring(respawnAllowed))
    for _, playerController in ipairs(self.Players.All) do
        player.SetAllowedToRestart(playerController, respawnAllowed)
    end
end

function Teams:PlayerDied(playerController, playerCharacter)
    print('Player died')
    if gamemode.GetRoundStage() ~= 'InProgress' then
        return
    end
    if self.Score >= self.RespawnCost then
        player.ShowGameMessage(
            playerController,
            'RespawnAvailable',
            'Lower',
            2.5
        )
    end
    player.SetLives(playerController, 0)
    self:UpdatePlayers()
end

function Teams:RespawnFromReadyRoom(playerController)
    print('Player respawning from ready room')
    if gamemode.GetRoundStage() ~= 'InProgress' then
        player.ShowGameMessage(
            playerController,
            'RespawnNotInProgress',
            'Lower',
            2.5
        )
        return
    end
    if self:CanRespawn() then
        gamemode.EnterPlayArea(playerController)
    else
        player.ShowGameMessage(
            playerController,
            'RespawnInsufficientScore',
            'Lower',
            2.5
        )
    end
end

function Teams:RespawnCleanUp(playerState)
    print('Cleaning up after respawn')
    player.SetLives(playerState, 1)
    self:UpdatePlayers()
    self:ChangeScore(playerState, 'Respawn', -self.RespawnCost)
end

function Teams:CanRespawn()
    return self.Score >= self.RespawnCost
end

--#endregion

--#region Messages

function Teams:DisplayMessageToPlayer(playerController, message, position, duration, messageType)
    if not self.Display[messageType] then
        return
    end
    player.ShowGameMessage(
        playerController,
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
        for _, playerController in ipairs(self.Players.Alive) do
            player.ShowGameMessage(
                playerController,
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
        for _, playerController in ipairs(self.Players.All) do
            player.ShowGameMessage(
                playerController,
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
        for _, playerController in ipairs(self.Players.Alive) do
            player.ShowWorldPrompt(
                playerController,
                location,
                label,
                duration
            )
        end
    end
end

--#endregion

return Teams