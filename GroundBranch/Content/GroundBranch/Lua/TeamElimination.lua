local teamelimination = {
	UseReadyRoom = true,
	UseRounds = true,
	StringTables = { "TeamElimination" },
	PlayerTeams = {
		Blue = {
			TeamId = 1,
			Loadout = "Blue",
		},
		Red = {
			TeamId = 2,
			Loadout = "Red",
		},
	},
	Settings = {
		RoundTime = {
			Min = 5,
			Max = 30,
			Value = 10,
		},
	},
	RoundResult = "",
	InsertionPoints = {},
	bFixedInsertionPoints = false,
	NumInsertionPointGroups = 0,
	PrevGroupIndex = 0,
}

function teamelimination:PreInit()
	local AllInsertionPoints = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBInsertionPoint')
	
	if #AllInsertionPoints > 2 then
		local GroupedInsertionPoints = {}
		
		for i, InsertionPoint in ipairs(AllInsertionPoints) do
			if #actor.GetTags(InsertionPoint) > 1 then
				local Group = actor.GetTag(InsertionPoint, 1)
				if GroupedInsertionPoints[Group] == nil then
					GroupedInsertionPoints[Group] = {}
					self.NumInsertionPointGroups = self.NumInsertionPointGroups + 1
				end
				table.insert(GroupedInsertionPoints[Group], InsertionPoint)
			end
		end

		if self.NumInsertionPointGroups > 1 then
			self.InsertionPoints = GroupedInsertionPoints
		else
			self.InsertionPoints = AllInsertionPoints
		end
	else
		self.InsertionPoints = AllInsertionPoints
		for i, InsertionPoint in ipairs(self.InsertionPoints) do
			if actor.GetTeamId(InsertionPoint) ~= 255 then
				-- Disables insertion point randomisation.
				self.bFixedInsertionPoints = true
				break
			end
		end
	end
end

function teamelimination:PostInit()
	gamemode.AddGameObjective(self.PlayerTeams.Blue.TeamId, "EliminateRed", 1)
	gamemode.AddGameObjective(self.PlayerTeams.Red.TeamId, "EliminateBlue", 1)
end

function teamelimination:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	if InsertionPoint == nil then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false);
	else
		timer.Set("CheckReadyUp", self, self.CheckReadyUpTimer, 0.25, false);
	end
end

function teamelimination:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	if ReadyStatus ~= "DeclaredReady" then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false);
	elseif gamemode.GetRoundStage() == "PreRoundWait" and gamemode.PrepLatecomer(PlayerState) then
		gamemode.EnterPlayArea(PlayerState)
	end
end

function teamelimination:CheckReadyUpTimer()
	if gamemode.GetRoundStage() == "WaitingForReady" or gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		local BlueReady = ReadyPlayerTeamCounts[self.PlayerTeams.Blue.TeamId]
		local RedReady = ReadyPlayerTeamCounts[self.PlayerTeams.Red.TeamId]
		if BlueReady > 0 and RedReady > 0 then
			if BlueReady + RedReady >= gamemode.GetPlayerCount(true) then
				gamemode.SetRoundStage("PreRoundWait")
			else
				gamemode.SetRoundStage("ReadyCountdown")
			end
		end
	end
end

function teamelimination:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		local BlueReady = ReadyPlayerTeamCounts[self.PlayerTeams.Blue.TeamId]
		local RedReady = ReadyPlayerTeamCounts[self.PlayerTeams.Red.TeamId]
		if BlueReady < 1 or RedReady < 1 then
			gamemode.SetRoundStage("WaitingForReady")
		end
	end
end

function teamelimination:OnRoundStageSet(RoundStage)
	if RoundStage == "WaitingForReady" then
		if not self.bFixedInsertionPoints then
			if self.NumInsertionPointGroups > 1 then
				self:RandomiseInsertionPointGroups()
			else
				self:RandomiseInsertionPoints(self.InsertionPoints)
			end
		end
	end
end

function teamelimination:OnCharacterDied(Character, CharacterController, KillerController)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		if CharacterController ~= nil then
			player.SetLives(CharacterController, player.GetLives(CharacterController) - 1)
			timer.Set("CheckEndRound", self, self.CheckEndRoundTimer, 1.0, false);
		end
	end
end

function teamelimination:CheckEndRoundTimer()
	local BluePlayersWithLives = gamemode.GetPlayerListByLives(self.PlayerTeams.Blue.TeamId, 1, false)
	local RedPlayersWithLives = gamemode.GetPlayerListByLives(self.PlayerTeams.Red.TeamId, 1, false)
	
	if #BluePlayersWithLives > 0 and #RedPlayersWithLives == 0 then
		gamemode.AddGameStat("Result=Team1")
		gamemode.AddGameStat("Summary=RedEliminated")
		gamemode.AddGameStat("CompleteObjectives=EliminateBlue")
		gamemode.SetRoundStage("PostRoundWait")
	elseif #BluePlayersWithLives == 0 and #RedPlayersWithLives > 0 then
		gamemode.AddGameStat("Result=Team2")
		gamemode.AddGameStat("Summary=BlueEliminated")
		gamemode.AddGameStat("CompleteObjectives=EliminateRed")
		gamemode.SetRoundStage("PostRoundWait")
	elseif #BluePlayersWithLives == 0 and #RedPlayersWithLives == 0 then
		gamemode.AddGameStat("Result=None")
		gamemode.AddGameStat("Summary=BothEliminated")
		gamemode.SetRoundStage("PostRoundWait")
	end
end

function teamelimination:RandomiseInsertionPointGroups()
	local NewGroupIndex = self.PrevGroupIndex

	while (NewGroupIndex == self.PrevGroupIndex) do
		NewGroupIndex = umath.random(self.NumInsertionPointGroups)
	end

	self.PrevGroupIndex = NewGroupIndex
	
	local GroupIndex = 0
	
	for Key, Value in pairs(self.InsertionPoints) do
		GroupIndex = GroupIndex + 1
		if GroupIndex == NewGroupIndex then
			self:RandomiseInsertionPoints(Value)
		else
			for i = #Value, 1, -1 do
				actor.SetActive(Value[i], false)
				actor.SetTeamId(Value[i], 255)
			end
		end
	end
end

function teamelimination:RandomiseInsertionPoints(TargetInsertionPoints)
	if #TargetInsertionPoints < 2 then
		print("Error: #TargetInsertionPoints < 2")
		return
	end

	local ShuffledInsertionPoints = {}

	local BlueIndex = umath.random(#TargetInsertionPoints)
	local RedIndex = BlueIndex + umath.random(#TargetInsertionPoints - 1)
	if RedIndex > #TargetInsertionPoints then
		RedIndex = RedIndex - #TargetInsertionPoints
	end

	for i, InsertionPoint in ipairs(TargetInsertionPoints) do
		if i == BlueIndex then
			actor.SetActive(InsertionPoint, true)
			actor.SetTeamId(InsertionPoint, self.PlayerTeams.Blue.TeamId)
		elseif i == RedIndex then
			actor.SetActive(InsertionPoint, true)
			actor.SetTeamId(InsertionPoint, self.PlayerTeams.Red.TeamId)
		else
			actor.SetActive(InsertionPoint, false)
			actor.SetTeamId(InsertionPoint, 255)
		end
	end
end

function teamelimination:ShouldCheckForTeamKills()
	if gamemode.GetRoundStage() == "InProgress" then
		return true
	end
	return false
end

function teamelimination:PlayerCanEnterPlayArea(PlayerState)
	if player.GetInsertionPoint(PlayerState) ~= nil then
		return true
	end
	return false
end

function teamelimination:LogOut(Exiting)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		timer.Set("CheckEndRound", self, self.CheckEndRoundTimer, 1.0, false);
	end
end

return teamelimination