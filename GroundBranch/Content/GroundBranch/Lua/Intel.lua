local intel = {
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
	ExtractionPoints = {},
	ExtractionPointMarkers = {},
	ExtractionPoint = nil,
	Laptops = {},
	LaptopTag = "TheIntelIsALie",
	SearchTime = 10,
	MinSearchTime = 1,
	MaxSearchTime = 60,
	TeamExfil = true,
	TeamExfilWarning = false;
}

function intel:PostRun()
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
	
	self.ExtractionPoints = gameplaystatics.GetAllActorsOfClass('/Game/GroundBranch/Props/GameMode/BP_ExtractionPoint.BP_ExtractionPoint_C')

	for i = 1, #self.ExtractionPoints do
		local Location = actor.GetLocation(self.ExtractionPoints[i])
		self.ExtractionPointMarkers[i] = gamemode.AddObjectiveMarker(Location, self.BluForTeamId, "ExtractionPoint", false)
	end
	
	self.Laptops = gameplaystatics.GetAllActorsOfClass('/Game/GroundBranch/Props/Electronics/MilitaryLaptop/BP_Laptop_Usable.BP_Laptop_Usable_C')

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

	if gamemode.HasGameOption("teamexfil") then
		self.TeamExfil = (tonumber(gamemode.GetGameOption("teamexfil")) == 1)
	end

	if gamemode.HasGameOption("searchtime") then
		self.SearchTime = math.max(tonumber(gamemode.GetGameOption("searchtime")), self.MinSearchTime)
		self.SearchTime = math.min(self.SearchTime, self.MaxSearchTime)
	end

	-- Cooperative play requires a team for the players to be on.
	gamemode.AddPlayerTeam(self.BluForTeamId, self.BluForTeamTag, self.BluForLoadoutName);

	gamemode.AddStringTable("IntelRetrieval")
	gamemode.AddGameObjective(1, "RetrieveIntel", 1)
	gamemode.AddGameObjective(1, "ExfiltrateBluFor", 1)
	gamemode.AddGameSetting("opforcount", 1, self.MaxOpforCount, 1, self.OpForCount)
	gamemode.AddGameSetting("difficulty", 0, 4, 1, 2);
	gamemode.AddGameSetting("roundtime", 10, 60, 10, 60);
	if self.TeamExfil then
		gamemode.AddGameSetting("teamexfil", 0, 1, 1, 1);
	else
		gamemode.AddGameSetting("teamexfil", 0, 1, 1, 0);
	end
	gamemode.SetRoundStage("WaitingForReady")
end

function intel:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	if InsertionPoint == nil then
		timer.Set(self, "CheckReadyDownTimer", 0.1, false)
	else
		timer.Set(self, "CheckReadyUpTimer", 0.25, false)
	end
end

function intel:PlayerWantsToEnterPlayChanged(PlayerState, WantsToEnterPlay)
	if not WantsToEnterPlay then
		timer.Set(self, "CheckReadyDownTimer", 0.1, false)
	elseif gamemode.GetRoundStage() == "PreRoundWait" and gamemode.PrepLatecomer(PlayerState) then
		gamemode.EnterPlayArea(PlayerState)
	end
end

function intel:CheckReadyUpTimer()
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

function intel:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
	
		if ReadyPlayerTeamCounts[self.BluForTeamId] < 1 then
			gamemode.SetRoundStage("WaitingForReady")
		end
	end
end

function intel:OnRoundStageSet(RoundStage)
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

function intel:SpawnOpFor()
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

function intel:OnCharacterDied(Character, CharacterController, KillerController)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		if CharacterController ~= nil then
			if not actor.HasTag(CharacterController, self.OpForTeamTag) then
				player.SetLives(CharacterController, player.GetLives(CharacterController) - 1)
				timer.Set(self, "CheckBluForCountTimer", 1.0, false)
			end
		end
	end
end

function intel:CheckBluForCountTimer()
	local BluForPlayers = gamemode.GetPlayerList("Lives", self.BluForTeamId, true, 1, false)
	if #BluForPlayers == 0 then
		gamemode.AddGameStat("Result=None")
		gamemode.AddGameStat("Summary=BluForEliminated")
		gamemode.SetRoundStage("PostRoundWait")
	end
end

function intel:OnProcessCommand(Command, Params)
	if Command == "opforcount" then
		if Params ~= nil then
			self.OpForCount = math.max(tonumber(Params), 0)
			self.OpForCount = math.min(self.OpForCount, self.MaxOpforCount)
		end
	elseif Command == "teamexfil" then
		if Params ~= nil then
			self.TeamExfil = (tonumber(Params) == 1)
		end
	end
end

function intel:ShouldCheckForTeamKills()
	if gamemode.GetRoundStage() == "InProgress" then
		return true
	end
	return false
end

function intel:PlayerCanEnterPlayArea(PlayerState)
	if player.GetInsertionPoint(PlayerState) ~= nil then
		return true
	end
	return false
end

function intel:OnGameTriggerBeginOverlap(GameTrigger, Character)
	if player.HasItemWithTag(Character, self.LaptopTag) == true then
		if self.TeamExfil then
			timer.Set(self, "CheckOpForExfilTimer", 1.0, true)
		else
			gamemode.AddGameStat("Result=Team1")
			gamemode.AddGameStat("Summary=IntelRetrieved")
			gamemode.AddGameStat("CompleteObjectives=RetrieveIntel,ExfiltrateBluFor")
			gamemode.SetRoundStage("PostRoundWait")
		end
	end
end

function intel:CheckOpForExfilTimer()
	local Overlaps = actor.GetOverlaps(self.ExtractionPoints[self.ExtractionPointIndex], 'GroundBranch.GBCharacter')
	local LivingPlayers = gamemode.GetPlayerList("Lives", self.BluForTeamId, true, 1, false)
	
	local bExfiltrated = false
	local bLivingOverlap = false
	local bLaptopSecure = false
	local PlayerWithLapTop = nil

	for i = 1, #LivingPlayers do
		local LivingCharacter = player.GetCharacter(LivingPlayers[i])
	
		bExfiltrated = false

		for j = 1, #Overlaps do
			if Overlaps[j] == LivingCharacter then
				bLivingOverlap = true
				bExfiltrated = true
				if player.HasItemWithTag(LivingCharacter, self.LaptopTag) then
					bLaptopSecure = true
					PlayerWithLapTop = LivingPlayers[i]
				end
				break
			end
		end

		if bExfiltrated == false then
			break
		end
	end
	
	if bLaptopSecure then
		if bExfiltrated then
		 	timer.Clear(self, "CheckOpForExfilTimer")
		 	gamemode.AddGameStat("Result=Team1")
		 	gamemode.AddGameStat("Summary=IntelRetrieved")
		 	gamemode.AddGameStat("CompleteObjectives=RetrieveIntel,ExfiltrateBluFor")
		 	gamemode.SetRoundStage("PostRoundWait")
		elseif not self.TeamExfilWarning then
			self.TeamExfilWarning = true
			player.ShowGameMessage(Character, "TeamExfil", 5.0)
		end
	end
end

function intel:LogOut(Exiting)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		timer.Set(self, "CheckBluForCountTimer", 1.0, false);
	end
end

return intel