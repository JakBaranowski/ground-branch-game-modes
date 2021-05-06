local assassination = {
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
	OpForLeaderTag = "OpForLeader",
	LeaderSpawns = {},
	OpForLeaderEliminated = false,
	BluForExtracionPointTag = "BluForExtracionPoint",
	ExtractionPoints = {},
	ExtractionPointMarkers = {},
	BluForExfiltrated = false,
	ExtractionPoint = nil,
}

function assassination:PostRun()
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

	-- Keeps one AI spot available for the HVT.
	self.MaxOpforCount = self.MaxOpforCount - 1
	
	for key, SpawnPoint in next, AllSpawns do
		if actor.HasTag(SpawnPoint, self.OpForLeaderTag) then
			table.insert(self.LeaderSpawns, SpawnPoint)
		end
	end
	
	self.ExtractionPoints = gameplaystatics.GetAllActorsOfClassWithTag('GroundBranch.GBGameTrigger', self.BluForExtracionPointTag)

	for i = 1, #self.ExtractionPoints do
		local Location = actor.GetLocation(self.ExtractionPoints[i])
		self.ExtractionPointMarkers[i] = gamemode.AddObjectiveMarker(Location, self.BluForTeamId, "ExtractionPoint", false)
	end

	gamemode.AddGameRule("UseReadyRoom")
	gamemode.AddGameRule("UseRounds")

	if not gamemode.HasGameOption("SpectateFreeCam") then
		gamemode.AddGameRule("SpectateFreeCam")
	end

	if not gamemode.HasGameOption("AllowDeadChat") then
		gamemode.AddGameRule("AllowDeadChat")
	end

	-- Cooperative play requires a team for the players to be on.
	gamemode.AddPlayerTeam(self.BluForTeamId, self.BluForTeamTag, self.BluForLoadoutName)

	gamemode.AddStringTable("assassination")
	gamemode.AddGameObjective(1, "EliminateOpForLeader", 1)
	gamemode.AddGameObjective(1, "ExfiltrateBluFor", 1)
	gamemode.AddGameSetting("opforcount", 1, self.MaxOpforCount, 1, self.OpForCount)
	gamemode.AddGameSetting("difficulty", 0, 4, 1, 2)
	gamemode.AddGameSetting("roundtime", 10, 60, 10, 60)
	gamemode.SetRoundStage("WaitingForReady")
end

function assassination:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	if InsertionPoint == nil then
		timer.Set(self, "CheckReadyDownTimer", 0.1, false)
	else
		timer.Set(self, "CheckReadyUpTimer", 0.25, false)
	end
end

function assassination:PlayerWantsToEnterPlayChanged(PlayerState, WantsToEnterPlay)
	if not WantsToEnterPlay then
		timer.Set(self, "CheckReadyDownTimer", 0.1, false)
	elseif gamemode.GetRoundStage() == "PreRoundWait" and gamemode.PrepLatecomer(PlayerState) then
		gamemode.EnterPlayArea(PlayerState)
	end
end

function assassination:CheckReadyUpTimer()
	if gamemode.GetRoundStage() == "WaitingForReady" or gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
	
		local BluForReady = ReadyPlayerTeamCounts[self.BluForTeamId]
	
		if BluForReady >=  gamemode.GetPlayerCount(true) then
			gamemode.SetRoundStage("PreRoundWait")
		elseif BluForReady > 0 then
			gamemode.SetRoundStage("ReadyCountdown")
		end
	end
end

function assassination:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
	
		if ReadyPlayerTeamCounts[self.BluForTeamId] < 1 then
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

	-- shuffle credits https://stackoverflow.com/questions/35572435/how-do-you-do-the-fisher-yates-shuffle-in-lua
	math.randomseed(os.time()) -- so that the results are always different
	
	for Key, Group in ipairs(self.PriorityGroupedSpawns) do
		for i = #Group, 1, -1 do
			local j = math.random(i)
			Group[i], Group[j] = Group[j], Group[i]
			table.insert(OrderedSpawns, Group[i])
		end
	end

	ai.CreateOverDuration(4.0, self.OpForCount, OrderedSpawns, self.OpForTeamTag)

	local RandomLeaderSpawn = self.LeaderSpawns[math.random(#self.LeaderSpawns)]

	ai.Create(RandomLeaderSpawn, self.OpForLeaderTag, 5.0)
end

function assassination:OnCharacterDied(Character, CharacterController, KillerController)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		if CharacterController ~= nil then
			if actor.HasTag(CharacterController, self.OpForLeaderTag) then
				self.OpForLeaderEliminated = true
			elseif actor.HasTag(CharacterController, self.OpForTeamTag) then
				-- timer.Set(self, "CheckOpForCountTimer", 1.0, false)
			else
				player.SetLives(CharacterController, player.GetLives(CharacterController) - 1)
				timer.Set(self, "CheckBluForCountTimer", 1.0, false)
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
	local BluForPlayers = gamemode.GetPlayerList("Lives", self.BluForTeamId, true, 1, false)
	if #BluForPlayers == 0 then
		timer.Clear(self, "CheckOpForExfilTimer")
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

function assassination:OnProcessCommand(Command, Params)
	if Command == "opforcount" then
		if Params ~= nil then
			self.OpForCount = math.max(tonumber(Params), 0)
			self.OpForCount = math.min(self.OpForCount, self.MaxOpforCount)
		end
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
		timer.Set(self, "CheckOpForExfilTimer", 1.0, false)
	end
end

function assassination:CheckOpForExfilTimer()
	local Overlaps = actor.GetOverlaps(self.ExtractionPoints[self.ExtractionPointIndex], 'GroundBranch.GBCharacter')
	local LivingPlayers = gamemode.GetPlayerList("Lives", self.BluForTeamId, true, 1, false)
	
	local bExfiltrated = true
	local bLivingOverlap = false

	for i = 1, #LivingPlayers do
		local LivingCharacter = player.GetCharacter(LivingPlayers[i])
		local bFound = false

		for j = 1, #Overlaps do
			if Overlaps[j] == LivingCharacter then
				bLivingOverlap = true
				bFound = true
				break
			end
		end

		if bFound == false then
			bExfiltrated = false
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
			timer.Set(self, "CheckOpForExfilTimer", 1.0, false)
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
		timer.Set(self, "CheckBluForCountTimer", 1.0, false)
	end
end

return assassination