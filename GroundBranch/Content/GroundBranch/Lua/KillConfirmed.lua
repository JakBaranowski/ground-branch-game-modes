local killConfirmed = {
	UseReadyRoom = true,
	UseRounds = true,
	StringTables = {"KillConfirmed"},
	PlayerTeams = {
		BluFor = {
			TeamId = 1,
			Loadout = "NoTeam",
		},
	},
	Settings = {
		OpForCount = {
			Min = 0,
			Max = 50,
			Value = 15,
		},
		LeaderCount = {
			Min = 1,
			Max = 5,
			Value = 1,
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
	-- OpFor standard spawns
	OpForTeamTag = "OpFor",
	PriorityTags = { "AISpawn_1", "AISpawn_2", "AISpawn_3", "AISpawn_4", "AISpawn_5",
		"AISpawn_6_10", "AISpawn_11_20", "AISpawn_21_30", "AISpawn_31_40", "AISpawn_41_50" },
	PriorityGroupedSpawns = {},
	-- OpFor leader spawns
	OpForLeaderTag = "OpForLeader",
	OpForLeaderSpawns = {},
	OpForLeaderSpawnMarkers = {},
	-- Extraction points
	ExtractionPoints = {},
	ExtractionPointMarkers = {},
	ExtractionPoint = nil,
	-- Game objective tracking variables
	BluForExfiltrated = false,
	OpForLeadersEliminated = 0,
}

function killConfirmed:PreInit()
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

	-- Get all possible HVT spawn points
	for i, SpawnPoint in ipairs(AllSpawns) do
		if actor.HasTag(SpawnPoint, self.OpForLeaderTag) then
			table.insert(self.OpForLeaderSpawns, SpawnPoint)
		end
	end

	self.Settings.LeaderCount.Max = math.min(ai.GetMaxCount(), #self.OpForLeaderSpawns)
	self.Settings.OpForCount.Value = math.min(self.Settings.LeaderCount.Value, self.Settings.LeaderCount.Max)

	self.Settings.OpForCount.Max = math.min(ai.GetMaxCount(), TotalSpawns)
	self.Settings.OpForCount.Value = math.min(self.Settings.OpForCount.Value, self.Settings.OpForCount.Max)

	-- Adds objective markers for all possible HVT locations.
	for i = 1, #self.OpForLeaderSpawns do
		local Location = actor.GetLocation(self.OpForLeaderSpawns[i])
		self.OpForLeaderSpawnMarkers[i] = gamemode.AddObjectiveMarker(Location, self.PlayerTeams.BluFor.TeamId, "HVT", false)
	end

	-- Gathers all extraction points placed in the mission
	self.ExtractionPoints = gameplaystatics.GetAllActorsOfClass('/Game/GroundBranch/Props/GameMode/BP_ExtractionPoint.BP_ExtractionPoint_C')
	-- Adds objective markers for all possible extraction points
	for i = 1, #self.ExtractionPoints do
		local Location = actor.GetLocation(self.ExtractionPoints[i])
		self.ExtractionPointMarkers[i] = gamemode.AddObjectiveMarker(Location, self.PlayerTeams.BluFor.TeamId, "Exfil", false)
	end
end

function killConfirmed:PostInit()
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "EliminateOpForLeader", 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "ExfiltrateBluFor", 1)
end

function killConfirmed:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	if InsertionPoint == nil then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	else
		timer.Set("CheckReadyUp", self, self.CheckReadyUpTimer, 0.25, false)
	end
end

function killConfirmed:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	if ReadyStatus ~= "DeclaredReady" then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	elseif gamemode.GetRoundStage() == "PreRoundWait" and gamemode.PrepLatecomer(PlayerState) then
		gamemode.EnterPlayArea(PlayerState)
	end
end

function killConfirmed:CheckReadyUpTimer()
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

function killConfirmed:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
	
		if ReadyPlayerTeamCounts[self.PlayerTeams.BluFor.TeamId] < 1 then
			gamemode.SetRoundStage("WaitingForReady")
		end
	end
end

function killConfirmed:OnRoundStageSet(RoundStage)
	if RoundStage == "WaitingForReady" then
		ai.CleanUp(self.OpForLeaderTag)
		ai.CleanUp(self.OpForTeamTag)

		self.OpForLeadersEliminated = 0
		self.BluForExfiltrated = false

		for i = 1, #self.OpForLeaderSpawnMarkers do
			actor.SetActive(self.OpForLeaderSpawnMarkers[i], true)
		end

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

function killConfirmed:SpawnOpFor()
	local OrderedLeaderSpawns = {}
	local OrderedStandardSpawns = {}

	-- Shuffle leader spawns
	local UnorderedLeaderSpawns = self.OpForLeaderSpawns
	for i = #UnorderedLeaderSpawns, 1, -1 do
		local j = umath.random(i)
		UnorderedLeaderSpawns[i], UnorderedLeaderSpawns[j] = UnorderedLeaderSpawns[j], UnorderedLeaderSpawns[i]
		table.insert(OrderedLeaderSpawns, UnorderedLeaderSpawns[i])
	end

	-- Shuffle spawns within priority groups and add them to ordered spawns
	for Key, Group in ipairs(self.PriorityGroupedSpawns) do
		for i = #Group, 1, -1 do
			local j = umath.random(i)
			Group[i], Group[j] = Group[j], Group[i]
			table.insert(OrderedStandardSpawns, Group[i])
		end
	end

	for i = 1, self.Settings.LeaderCount.Value, 1 do
		ai.Create(OrderedLeaderSpawns[i], self.OpForLeaderTag, 4.0)
	end
	ai.CreateOverDuration(4.0, self.Settings.OpForCount.Value, OrderedStandardSpawns, self.OpForTeamTag)
end

function killConfirmed:OnCharacterDied(Character, CharacterController, KillerController)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		if CharacterController ~= nil then
			if actor.HasTag(CharacterController, self.OpForLeaderTag) then
				-- OpFor leader eliminated
				self.OpForLeadersEliminated = self.OpForLeadersEliminated + 1
				if self.OpForLeadersEliminated >= self.Settings.LeaderCount.Value then
					timer.Set("ShowAllKillConfirmed", self, self.ShowAllKillConfirmedTimer, 1.0, false)
				else
					timer.Set("ShowKillConfirmed", self, self.ShowKillConfirmedTimer, 1.0, false)
				end
			elseif actor.HasTag(CharacterController, self.OpForTeamTag) then
				-- OpFor standard eliminated
			else
				-- BluFor standard eliminated
				player.SetLives(CharacterController, player.GetLives(CharacterController) - 1)
				timer.Set("CheckBluForCount", self, self.CheckBluForCountTimer, 1.0, false)
			end
		end
	end
end

function killConfirmed:ShowKillConfirmedTimer()
	gamemode.BroadcastGameMessage("HighValueTargetEliminated", "Engine", 5.0)
end

function killConfirmed:ShowAllKillConfirmedTimer()
	gamemode.BroadcastGameMessage("AllHighValueTargetsEliminated", "Engine", 5.0)
end

function killConfirmed:CheckBluForCountTimer()
	local PlayersWithLives = gamemode.GetPlayerListByLives(self.PlayerTeams.BluFor.TeamId, 1, true)
	if #PlayersWithLives == 0 then
		timer.Clear(self, "CheckOpForExfil")
		gamemode.AddGameStat("Result=None")
		if self.OpForLeadersEliminated == self.Settings.LeaderCount.Value then
			gamemode.AddGameStat("Summary=BluForExfilFailed")
			gamemode.AddGameStat("CompleteObjectives=EliminateOpForLeader")
		else
			gamemode.AddGameStat("Summary=BluForEliminated")
		end
		gamemode.SetRoundStage("PostRoundWait")
	end
end

function killConfirmed:ShouldCheckForTeamKills()
	if gamemode.GetRoundStage() == "InProgress" then
		return true
	end
	return false
end

function killConfirmed:OnGameTriggerBeginOverlap(GameTrigger, Player)
	if self.OpForLeadersEliminated == self.Settings.LeaderCount.Value then
		timer.Set("CheckOpForExfil", self, self.CheckOpForExfilTimer, 1.0, false)
	end
end

function killConfirmed:CheckOpForExfilTimer()
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

function killConfirmed:PlayerCanEnterPlayArea(PlayerState)
	if player.GetInsertionPoint(PlayerState) ~= nil then
		return true
	end
	return false
end

function killConfirmed:LogOut(Exiting)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		timer.Set("CheckBluForCount", self, self.CheckBluForCountTimer, 1.0, false)
	end
end

return killConfirmed