local intelretrieval = {
	UseReadyRoom = true,
	UseRounds = true,
	StringTables = { "IntelRetrieval" },
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
		TeamExfil = {
			Min = 0,
			Max = 1,
			Value = 1,
		},
		SearchTime = {
			Min = 1,
			Max = 60,
			Value = 10,
		},
	},
	OpForTeamTag = "OpFor",
	PriorityTags = { "AISpawn_1", "AISpawn_2", "AISpawn_3", "AISpawn_4", "AISpawn_5",
		"AISpawn_6_10", "AISpawn_11_20", "AISpawn_21_30", "AISpawn_31_40", "AISpawn_41_50" },
	PriorityGroupedSpawns = {},
	ExtractionPoints = {},
	ExtractionPointMarkers = {},
	ExtractionPoint = nil,
	Laptops = {},
	LaptopTag = "TheIntelIsALie",
	TeamExfilWarning = false;
}

function intelretrieval:PreInit()
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

	TotalSpawns = math.min(ai.GetMaxCount(), TotalSpawns)
	self.Settings.OpForCount.Max = TotalSpawns
	self.Settings.OpForCount.Value = math.min(self.Settings.OpForCount.Value, TotalSpawns)
	
	self.ExtractionPoints = gameplaystatics.GetAllActorsOfClass('/Game/GroundBranch/Props/GameMode/BP_ExtractionPoint.BP_ExtractionPoint_C')

	for i = 1, #self.ExtractionPoints do
		local Location = actor.GetLocation(self.ExtractionPoints[i])
		self.ExtractionPointMarkers[i] = gamemode.AddObjectiveMarker(Location, self.PlayerTeams.BluFor.TeamId, "ExtractionPoint", false)
	end
	
	self.Laptops = gameplaystatics.GetAllActorsOfClass('/Game/GroundBranch/Props/Electronics/MilitaryLaptop/BP_Laptop_Usable.BP_Laptop_Usable_C')
end

function intelretrieval:PostInit()
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "RetrieveIntel", 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "ExfiltrateBluFor", 1)
end

function intelretrieval:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	if InsertionPoint == nil then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	else
		timer.Set("CheckReadyUp", self, self.CheckReadyUpTimer, 0.25, false)
	end
end

function intelretrieval:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	if ReadyStatus ~= "DeclaredReady" then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	elseif gamemode.GetRoundStage() == "PreRoundWait" and gamemode.PrepLatecomer(PlayerState) then
		gamemode.EnterPlayArea(PlayerState)
	end
end

function intelretrieval:CheckReadyUpTimer()
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

function intelretrieval:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
	
		if ReadyPlayerTeamCounts[self.PlayerTeams.BluFor.TeamId] < 1 then
			gamemode.SetRoundStage("WaitingForReady")
		end
	end
end

function intelretrieval:OnRoundStageSet(RoundStage)
	if RoundStage == "WaitingForReady" then
		timer.ClearAll()

		ai.CleanUp(self.OpForTeamTag)

		self.TeamExfilWarning = false
		self.ExtractionPointIndex = umath.random(#self.ExtractionPoints)

		for i = 1, #self.ExtractionPoints do
			local bActive = (i == self.ExtractionPointIndex)
			actor.SetActive(self.ExtractionPoints[i], bActive)
			actor.SetActive(self.ExtractionPointMarkers[i], bActive)
		end

		local RandomLaptopIndex = umath.random(#self.Laptops);
		for i = 1, #self.Laptops do
			actor.SetActive(self.Laptops[i], true)
			if (i == RandomLaptopIndex) then
				actor.AddTag(self.Laptops[i], self.LaptopTag)
			else
				actor.RemoveTag(self.Laptops[i], self.LaptopTag)
			end
		end
	elseif RoundStage == "PreRoundWait" then
		self:SpawnOpFor()
	end
end

function intelretrieval:SpawnOpFor()
	local OrderedSpawns = {}

	for Key, Group in ipairs(self.PriorityGroupedSpawns) do
		for i = #Group, 1, -1 do
			local j = umath.random(i)
			Group[i], Group[j] = Group[j], Group[i]
			table.insert(OrderedSpawns, Group[i])
		end
	end

	ai.CreateOverDuration(4.0, self.Settings.OpForCount.Value, OrderedSpawns, self.OpForTeamTag)
end

function intelretrieval:OnCharacterDied(Character, CharacterController, KillerController)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		if CharacterController ~= nil then
			if not actor.HasTag(CharacterController, self.OpForTeamTag) then
				player.SetLives(CharacterController, player.GetLives(CharacterController) - 1)
				timer.Set("CheckBluForCount", self, self.CheckBluForCountTimer, 1.0, false)
			end
		end
	end
end

function intelretrieval:CheckBluForCountTimer()
	local PlayersWithLives = gamemode.GetPlayerListByLives(self.PlayerTeams.BluFor.TeamId, 1, false)
	if #PlayersWithLives == 0 then
		gamemode.AddGameStat("Result=None")
		gamemode.AddGameStat("Summary=BluForEliminated")
		gamemode.SetRoundStage("PostRoundWait")
	end
end

function intelretrieval:ShouldCheckForTeamKills()
	if gamemode.GetRoundStage() == "InProgress" then
		return true
	end
	return false
end

function intelretrieval:PlayerCanEnterPlayArea(PlayerState)
	if player.GetInsertionPoint(PlayerState) ~= nil then
		return true
	end
	return false
end

function intelretrieval:OnGameTriggerBeginOverlap(GameTrigger, Character)
	if player.HasItemWithTag(Character, self.LaptopTag) == true then
		if self.Settings.TeamExfil.Value == 1 then
			timer.Set("CheckOpForExfil", self, self.CheckOpForExfilTimer, 1.0, true)
		else
			gamemode.AddGameStat("Result=Team1")
			gamemode.AddGameStat("Summary=IntelRetrieved")
			gamemode.AddGameStat("CompleteObjectives=RetrieveIntel,ExfiltrateBluFor")
			gamemode.SetRoundStage("PostRoundWait")
		end
	end
end

function intelretrieval:CheckOpForExfilTimer()
	local Overlaps = actor.GetOverlaps(self.ExtractionPoints[self.ExtractionPointIndex], 'GroundBranch.GBCharacter')
	local PlayersWithLives = gamemode.GetPlayerListByLives(self.PlayerTeams.BluFor.TeamId, 1, false)
	
	local bExfiltrated = false
	local bLivingOverlap = false
	local bLaptopSecure = false
	local PlayerWithLapTop = nil

	for i = 1, #PlayersWithLives do
		bExfiltrated = false

		local PlayerCharacter = player.GetCharacter(PlayersWithLives[i])
	
		-- May have lives, but no character, alive or otherwise.
		if PlayerCharacter ~= nil then
			for j = 1, #Overlaps do
				if Overlaps[j] == PlayerCharacter then
					bLivingOverlap = true
					bExfiltrated = true
					if player.HasItemWithTag(PlayerCharacter, self.LaptopTag) then
						bLaptopSecure = true
						PlayerWithLapTop = PlayersWithLives[i]
					end
					break
				end
			end
		end

		if bExfiltrated == false then
			break
		end
	end
	
	if bLaptopSecure then
		if bExfiltrated then
		 	timer.Clear(self, "CheckOpForExfil")
		 	gamemode.AddGameStat("Result=Team1")
		 	gamemode.AddGameStat("Summary=IntelRetrieved")
		 	gamemode.AddGameStat("CompleteObjectives=RetrieveIntel,ExfiltrateBluFor")
		 	gamemode.SetRoundStage("PostRoundWait")
		elseif PlayerWithLapTop ~= nil and self.TeamExfilWarning == false then
			player.ShowGameMessage(PlayerWithLapTop, "TeamExfil", "Engine", 5.0)
			self.TeamExfilWarning = true
		end
	end
end

function intelretrieval:LogOut(Exiting)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		timer.Set("CheckBluForCount", self, self.CheckBluForCountTimer, 1.0, false);
	end
end

return intelretrieval