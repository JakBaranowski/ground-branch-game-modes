local assassination = {
	UseReadyRoom = true,
	UseRounds = true,
	StringTables = { "Assassination" },
	PlayerTeams = {
		BluFor = {
			TeamId = 1,
			Loadout = "NoTeam",
		},
	},
	Settings = {
		OpForCount = {
			Min = 1,
			Max = 50,
			Value = 15,
		},
		Difficulty = {
			Min = 0,
			Max = 4,
			Value = 2,
		},
		RoundTime = {
			Min = 10,
			Max = 60,
			Value = 60,
		},
	},
	OpForTeamTag = "OpFor",
	PriorityTags = { "AISpawn_1", "AISpawn_2", "AISpawn_3", "AISpawn_4", "AISpawn_5",
		"AISpawn_6_10", "AISpawn_11_20", "AISpawn_21_30", "AISpawn_31_40", "AISpawn_41_50" },
	PriorityGroupedSpawns = {},
	OpForLeaderTag = "OpForLeader",
	LeaderSpawns = {},
	OpForLeaderEliminated = false,
	BluForExtracionPointTag = "BluForExtracionPoint",
	ExtractionPoints = {},
	ExtractionPointMarkers = {},
	BluForExfiltrated = false,
	ExtractionPoint = nil,
}

function assassination:PreInit()
	local AllSpawns = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAISpawnPoint')
	local PriorityIndex = 1
	local TotalSpawns = 0

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
				TotalSpawns = TotalSpawns + 1 
				table.insert(self.PriorityGroupedSpawns[PriorityIndex], SpawnPoint)
			end
		end

		-- Ensures we don't create empty tables for unused priorities.
		if bFoundTag then
			PriorityIndex = PriorityIndex + 1
		end
	end

	-- Keeps one AI spot available for the HVT.
	TotalSpawns = math.min(ai.GetMaxCount(), TotalSpawns) - 1
	self.Settings.OpForCount.Max = TotalSpawns
	self.Settings.OpForCount.Value = math.min(self.Settings.OpForCount.Value, TotalSpawns)
	
	for key, SpawnPoint in next, AllSpawns do
		if actor.HasTag(SpawnPoint, self.OpForLeaderTag) then
			table.insert(self.LeaderSpawns, SpawnPoint)
		end
	end
	
	self.ExtractionPoints = gameplaystatics.GetAllActorsOfClassWithTag('GroundBranch.GBGameTrigger', self.BluForExtracionPointTag)

	for i = 1, #self.ExtractionPoints do
		local Location = actor.GetLocation(self.ExtractionPoints[i])
		self.ExtractionPointMarkers[i] = gamemode.AddObjectiveMarker(Location, self.PlayerTeams.BluFor.TeamId, "ExtractionPoint", false)
	end
end

function assassination:PostInit()
	gamemode.AddGameObjective(1, "EliminateOpForLeader", 1)
	gamemode.AddGameObjective(1, "ExfiltrateBluFor", 1)
end

function assassination:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	if InsertionPoint == nil then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	else
		timer.Set("CheckReadyUp", self, self.CheckReadyUpTimer, 0.25, false)
	end
end

function assassination:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	if ReadyStatus ~= "DeclaredReady" then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	elseif gamemode.GetRoundStage() == "PreRoundWait" and gamemode.PrepLatecomer(PlayerState) then
		gamemode.EnterPlayArea(PlayerState)
	end
end

function assassination:CheckReadyUpTimer()
	if gamemode.GetRoundStage() == "WaitingForReady" or gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
	
		local BluForReady = ReadyPlayerTeamCounts[self.PlayerTeams.BluFor.TeamId]
	
		if BluForReady >= gamemode.GetPlayerCount(true) then
			gamemode.SetRoundStage("PreRoundWait")
		elseif BluForReady > 0 then
			gamemode.SetRoundStage("ReadyCountdown")
		end
	end
end

function assassination:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
	
		if ReadyPlayerTeamCounts[self.PlayerTeams.BluFor.TeamId] < 1 then
			gamemode.SetRoundStage("WaitingForReady")
		end
	end
end

function assassination:OnRoundStageSet(RoundStage)
	if RoundStage == "WaitingForReady" then
		ai.CleanUp(self.OpForTeamTag)

		ai.CleanUp(self.OpForLeaderTag)
		self.OpForLeaderEliminated = false

		self.BluForExfiltrated = false
		
		self.ExtractionPointIndex = math.random(#self.ExtractionPoints)

		for i = 1, #self.ExtractionPoints do
			local bActive = (i == self.ExtractionPointIndex)
			actor.SetActive(self.ExtractionPoints[i], bActive)
			actor.SetActive(self.ExtractionPointMarkers[i], bActive)
		end
	elseif RoundStage == "PreRoundWait" then
		self:SpawnOpFor()
	end
end

function assassination:SpawnOpFor()
	local OrderedSpawns = {}

	for Key, Group in ipairs(self.PriorityGroupedSpawns) do
		for i = #Group, 1, -1 do
			local j = umath.random(i)
			Group[i], Group[j] = Group[j], Group[i]
			table.insert(OrderedSpawns, Group[i])
		end
	end

	ai.CreateOverDuration(4.0, self.Settings.OpForCount.Value, OrderedSpawns, self.OpForTeamTag)

	local RandomLeaderSpawnIndex = umath.random(#self.LeaderSpawns);
	ai.Create(self.LeaderSpawns[RandomLeaderSpawnIndex], self.OpForLeaderTag, 5.0)
end

function assassination:OnCharacterDied(Character, CharacterController, KillerController)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		if CharacterController ~= nil then
			if actor.HasTag(CharacterController, self.OpForLeaderTag) then
				self.OpForLeaderEliminated = true
			elseif actor.HasTag(CharacterController, self.OpForTeamTag) then
				-- timer.Set("CheckOpForCount", self, self.CheckOpForCountTimer, 1.0, false)
			else
				player.SetLives(CharacterController, player.GetLives(CharacterController) - 1)
				timer.Set("CheckBluForCount", self, self.CheckBluForCountTimer, 1.0, false)
			end
		end
	end
end

function assassination:CheckOpForCountTimer()
	local OpForControllers = ai.GetControllers('GroundBranch.GBAIController', self.OpForTeamTag, 255, 255)

	if #OpForControllers == 0 then
		gamemode.AddGameStat("Result=Team1")
		gamemode.AddGameStat("Summary=OpForEliminated")
		gamemode.AddGameStat("CompleteObjectives=EliminateOpFor")
		gamemode.SetRoundStage("PostRoundWait")
	end
end

function assassination:CheckBluForCountTimer()
	local PlayersWithLives = gamemode.GetPlayerListByLives(self.PlayerTeams.BluFor.TeamId, 1, true)
	if #PlayersWithLives == 0 then
		timer.Clear(self, "CheckOpForExfil")
		gamemode.AddGameStat("Result=None")
		if self.OpForLeaderEliminated == true then
			gamemode.AddGameStat("Summary=BluForExfilFailed")
			gamemode.AddGameStat("CompleteObjectives=EliminateOpForLeader")
		else
			gamemode.AddGameStat("Summary=BluForEliminated")
		end
		gamemode.SetRoundStage("PostRoundWait")
	end
end

function assassination:ShouldCheckForTeamKills()
	if gamemode.GetRoundStage() == "InProgress" then
		return true
	end
	return false
end

function assassination:OnGameTriggerBeginOverlap(GameTrigger, Player)
	if self.OpForLeaderEliminated == true then
		timer.Set("CheckOpForExfil", self, self.CheckOpForExfilTimer, 1.0, false)
	end
end

function assassination:CheckOpForExfilTimer()
	local Overlaps = actor.GetOverlaps(self.ExtractionPoints[self.ExtractionPointIndex], 'GroundBranch.GBCharacter')
	local PlayersWithLives = gamemode.GetPlayerListByLives(self.PlayerTeams.BluFor.TeamId, 1, true)
	
	local bExfiltrated = false
	local bLivingOverlap = false

	for i = 1, #PlayersWithLives do
		bExfiltrated = false

		local PlayerCharacter = player.GetCharacter(PlayersWithLives[i])

		-- May have lives, but no character, alive or otherwise.
		if PlayerCharacter ~= nil then
			for j = 1, #Overlaps do
				if Overlaps[j] == PlayerCharacter then
					bLivingOverlap = true
					bExfiltrated = true
					break
				end
			end
		end

		if bExfiltrated == false then
			break
		end
	end

	if bLivingOverlap == true then
		if bExfiltrated == true then
			self.BluForExfiltrated = true
			gamemode.AddGameStat("Result=Team1")
			gamemode.AddGameStat("Summary=OpForLeaderEliminated")
			gamemode.AddGameStat("CompleteObjectives=EliminateOpForLeader,ExfiltrateBluFor")
			gamemode.SetRoundStage("PostRoundWait")
		else
			timer.Set("CheckOpForExfil", self, self.CheckOpForExfilTimer, 1.0, false)
		end
	end
end

function assassination:PlayerCanEnterPlayArea(PlayerState)
	if player.GetInsertionPoint(PlayerState) ~= nil then
		return true
	end
	return false
end

function assassination:LogOut(Exiting)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		timer.Set("CheckBluForCount", self, self.CheckBluForCountTimer, 1.0, false)
	end
end

return assassination