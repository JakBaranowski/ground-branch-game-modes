local terroristhunt = {
	OpForCount = 15,
	MaxOpforCount = 0,
	OpForTeamId = 100,
	OpForTeamTag = "OpFor",
	BluForTeamId = 1,
	BluForTeamTag = "BluFor",
	BluForLoadoutName = "NoTeam",
	PriorityTags = {"AISpawn_1", "AISpawn_2", "AISpawn_3", "AISpawn_4", "AISpawn_5",
		"AISpawn_6_10", "AISpawn_11_20", "AISpawn_21_30", "AISpawn_31_40", "AISpawn_41_50"},
	PriorityGroupedSpawns = {},
	BumRushMode = false,
}

function terroristhunt:PostRun()
	local AllSpawns = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAISpawnPoint')
	local PriorityIndex = 1

	-- Orders spawns by priority while allowing spawns of the same priority to be randomised.
	for i, PriorityTag in ipairs(self.PriorityTags) do
		local bFoundTag = false
		
		for j, SpawnPoint in ipairs(AllSpawns) do
			if actor.HasTag(SpawnPoint, PriorityTag) then
				bFoundTag = true
				if self.PriorityGroupedSpawns[PriorityIndex] == nil then
					self.PriorityGroupedSpawns[PriorityIndex] = {}
				end
				-- Ensures we can't spawn more AI then this map can handle.
				self.MaxOpforCount = self.MaxOpforCount + 1 
				table.insert(self.PriorityGroupedSpawns[PriorityIndex], SpawnPoint)
			end
		end

		-- Ensures we don't create empty tables for unused priorities.
		if bFoundTag then
			PriorityIndex = PriorityIndex + 1
		end
	end

	self.MaxOpforCount = math.min(ai.GetMaxCount(), self.MaxOpforCount)

	gamemode.AddGameRule("UseReadyRoom")
	gamemode.AddGameRule("UseRounds")

	if not gamemode.HasGameOption("SpectateFreeCam") then
		gamemode.AddGameRule("SpectateFreeCam")
	end
	
	if not gamemode.HasGameOption("AllowDeadChat") then
		gamemode.AddGameRule("AllowDeadChat")
	end

	if not gamemode.HasGameOption("AllowEnemyBlips") then
		gamemode.AddGameRule("AllowEnemyBlips")
	end
	
	-- Cooperative play requires a team for the players to be on.
	gamemode.AddPlayerTeam(self.BluForTeamId, self.BluForTeamTag, self.BluForLoadoutName)
	
	gamemode.AddStringTable("terroristhunt")
	gamemode.AddGameObjective(1, "EliminateOpFor", 1)
	gamemode.AddGameSetting("opforcount", 1, self.MaxOpforCount, 1, self.OpForCount)
	gamemode.AddGameSetting("difficulty", 0, 4, 1, 2)
	gamemode.AddGameSetting("roundtime", 10, 60, 10, 60)
	gamemode.SetRoundStage("WaitingForReady")
end

function terroristhunt:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	if InsertionPoint == nil then
		timer.Set(self, "CheckReadyDownTimer", 0.1, false)
	else
		timer.Set(self, "CheckReadyUpTimer", 0.25, false)
	end
end

function terroristhunt:PlayerWantsToEnterPlayChanged(PlayerState, WantsToEnterPlay)
	if not WantsToEnterPlay then
		timer.Set(self, "CheckReadyDownTimer", 0.1, false)
	elseif gamemode.GetRoundStage() == "PreRoundWait" and gamemode.PrepLatecomer(PlayerState) then
		gamemode.EnterPlayArea(PlayerState)
	end
end

function terroristhunt:CheckReadyUpTimer()
	if gamemode.GetRoundStage() == "WaitingForReady" or gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
	
		local BluForReady = ReadyPlayerTeamCounts[self.BluForTeamId]
	
		if BluForReady >= gamemode.GetPlayerCount(true) then
			gamemode.SetRoundStage("PreRoundWait")
		elseif BluForReady > 0 then
			gamemode.SetRoundStage("ReadyCountdown")
		end
	end
end

function terroristhunt:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
	
		if ReadyPlayerTeamCounts[self.BluForTeamId] < 1 then
			gamemode.SetRoundStage("WaitingForReady")
		end
	end
end

function terroristhunt:OnRoundStageSet(RoundStage)
	if RoundStage == "WaitingForReady" then
		ai.CleanUp(self.OpForTeamTag)
		self.BumRushMode = false
	elseif RoundStage == "PreRoundWait" then
		self:SpawnOpFor()
	end
end

function terroristhunt:SpawnOpFor()
	local OrderedSpawns = {}

	for Key, Group in ipairs(self.PriorityGroupedSpawns) do
		for i = #Group, 1, -1 do
			local j = umath.random(i)
			Group[i], Group[j] = Group[j], Group[i]
			table.insert(OrderedSpawns, Group[i])
		end
	end

	ai.CreateOverDuration(4.0, self.OpForCount, OrderedSpawns, self.OpForTeamTag)
end

function terroristhunt:OnCharacterDied(Character, CharacterController, KillerController)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		if CharacterController ~= nil then
			if actor.HasTag(CharacterController, self.OpForTeamTag) then
				timer.Set(self, "CheckOpForCountTimer", 1.0, false)
			else
				player.SetLives(CharacterController, player.GetLives(CharacterController) - 1)
				timer.Set(self, "CheckBluForCountTimer", 1.0, false)
			end
		end
	end
end

function terroristhunt:CheckOpForCountTimer()
	local OpForControllers = ai.GetControllers('GroundBranch.GBAIController', self.OpForTeamTag, 255, 255)
	
	if #OpForControllers == 0 then
		timer.Clear(self, "ShowRemainingMessage")
		gamemode.AddGameStat("Result=Team1")
		gamemode.AddGameStat("Summary=OpForEliminated")
		gamemode.AddGameStat("CompleteObjectives=EliminateOpFor")
		gamemode.SetRoundStage("PostRoundWait")
	elseif #OpForControllers <= 10 then
		self.RemainingMessage = "RemainingOpFor" .. tostring(#OpForControllers)
		timer.Set(self, "ShowRemainingMessage", 10, false)
	end
end

function terroristhunt:ShowRemainingMessage()
	local BluForPlayers = gamemode.GetPlayerList("", 255, true, 0, true)
	for i = 1, #BluForPlayers do
		player.ShowGameMessage(BluForPlayers[i], self.RemainingMessage, 2.0)
	end
end

function terroristhunt:CheckBluForCountTimer()
	local BluForPlayers = gamemode.GetPlayerList("Lives", self.BluForTeamId, true, 1, false)
	if #BluForPlayers == 0 then
		gamemode.AddGameStat("Result=None")
		gamemode.AddGameStat("Summary=BluForEliminated")
		gamemode.SetRoundStage("PostRoundWait")
	end
end

function terroristhunt:OnProcessCommand(Command, Params)
	if Command == "opforcount" then
		if Params ~= nil then
			self.OpForCount = math.max(tonumber(Params), 0)
			self.OpForCount = math.min(self.OpForCount, self.MaxOpforCount)
		end
	end
end

function terroristhunt:ShouldCheckForTeamKills()
	if gamemode.GetRoundStage() == "InProgress" then
		return true
	end
	return false
end

function terroristhunt:PlayerCanEnterPlayArea(PlayerState)
	if player.GetInsertionPoint(PlayerState) ~= nil then
		return true
	end
	return false
end

function terroristhunt:LogOut(Exiting)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		timer.Set(self, "CheckBluForCountTimer", 1.0, false)
	end
end

return terroristhunt