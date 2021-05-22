local tableOperations = require("common.tableOperations")

local BreakOut = {
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
	PriorityTags = {
		"AISpawn_1", "AISpawn_2", "AISpawn_3", "AISpawn_4", "AISpawn_5", "AISpawn_6_10",
		"AISpawn_11_20", "AISpawn_21_30", "AISpawn_31_40", "AISpawn_41_50"
	},
	OpForPriorityGroupedSpawns = {},
	OpForPriorityGroupedSpawnsShuffled = {},
	-- Extraction points
	ExtractionPoints = {},
	ExtractionPoint = nil,
	ExtractionPointMarkers = {},
	-- Game objective tracking variables
	BluForExfiltrated = false,
}

function BreakOut:PreInit()
	local AllSpawns = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAISpawnPoint')
	local PriorityIndex = 1
	local TotalSpawns = 0

	-- Orders spawns by priority while allowing spawns of the same priority to be
	-- randomised.
	for i, PriorityTag in ipairs(self.PriorityTags) do
		local bFoundTag = false
		for j, SpawnPoint in ipairs(AllSpawns) do
			if actor.HasTag(SpawnPoint, PriorityTag) then
				bFoundTag = true
				if self.OpForPriorityGroupedSpawns[PriorityIndex] == nil then
					self.OpForPriorityGroupedSpawns[PriorityIndex] = {}
				end
				-- Ensures we can't spawn more AI then this map can handle.
				TotalSpawns = TotalSpawns + 1
				table.insert(self.OpForPriorityGroupedSpawns[PriorityIndex], SpawnPoint)
			end
		end
		-- Ensures we don't create empty tables for unused priorities.
		if bFoundTag then
			PriorityIndex = PriorityIndex + 1
		end
	end

	self.Settings.OpForCount.Max = math.min(
		ai.GetMaxCount(),
		TotalSpawns
	)
	self.Settings.OpForCount.Value = math.min(
		self.Settings.OpForCount.Value,
		self.Settings.OpForCount.Max
	)

	-- Gathers all extraction points placed in the mission
	self.ExtractionPoints = gameplaystatics.GetAllActorsOfClass(
		'/Game/GroundBranch/Props/GameMode/BP_ExtractionPoint.BP_ExtractionPoint_C'
	)
	-- Adds objective markers for all possible extraction points
	for i = 1, #self.ExtractionPoints do
		local Location = actor.GetLocation(self.ExtractionPoints[i])
		self.ExtractionPointMarkers[i] = gamemode.AddObjectiveMarker(
			Location,
			self.PlayerTeams.BluFor.TeamId,
			"Extraction",
			false
		)
	end
end

function BreakOut:PostInit()
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "ExfiltrateBluFor", 1)
end

function BreakOut:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	if InsertionPoint == nil then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	else
		timer.Set("CheckReadyUp", self, self.CheckReadyUpTimer, 0.25, false)
	end
end

function BreakOut:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	if ReadyStatus ~= "DeclaredReady" then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	elseif
		gamemode.GetRoundStage() == "PreRoundWait" and
		gamemode.PrepLatecomer(PlayerState)
	then
		gamemode.EnterPlayArea(PlayerState)
	end
end

function BreakOut:CheckReadyUpTimer()
	if
		gamemode.GetRoundStage() == "WaitingForReady" or
		gamemode.GetRoundStage() == "ReadyCountdown"
	then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		local BluForReady = ReadyPlayerTeamCounts[self.PlayerTeams.BluFor.TeamId]
		if BluForReady >= gamemode.GetPlayerCount(true) then
			gamemode.SetRoundStage("PreRoundWait")
		elseif BluForReady > 0 then
			gamemode.SetRoundStage("ReadyCountdown")
		end
	end
end

function BreakOut:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		if ReadyPlayerTeamCounts[self.PlayerTeams.BluFor.TeamId] < 1 then
			gamemode.SetRoundStage("WaitingForReady")
		end
	end
end

function BreakOut:OnRoundStageSet(RoundStage)
	if RoundStage == "WaitingForReady" then
		self:CleanUp()
		self:ShuffleSpawns()
		self:SetUpObjectiveMarkers()
	elseif RoundStage == "PreRoundWait" then
		self:SpawnOpFor()
	end
end

function BreakOut:CleanUp()
	ai.CleanUp(self.OpForTeamTag)
	self.BluForExfiltrated = false
end

function BreakOut:ShuffleSpawns()
	local tableWithShuffledSpawns = tableOperations.ShuffleTables(
		self.OpForPriorityGroupedSpawns
	)
	self.OpForPriorityGroupedSpawnsShuffled = tableOperations.GetTableFromTables(
		tableWithShuffledSpawns
	)
end

function BreakOut:SetUpObjectiveMarkers()
	self.ExtractionPointIndex = math.random(#self.ExtractionPoints)
	self.ExtractionPoint = self.ExtractionPoints[self.ExtractionPointIndex]
	for i = 1, #self.ExtractionPoints do
		local bActive = (i == self.ExtractionPointIndex)
		actor.SetActive(self.ExtractionPoints[i], bActive)
		actor.SetActive(self.ExtractionPointMarkers[i], bActive)
	end
end

function BreakOut:SpawnOpFor()
	ai.CreateOverDuration(
		4.0,
		self.Settings.OpForCount.Value,
		self.OpForPriorityGroupedSpawnsShuffled,
		self.OpForTeamTag
	)
end

function BreakOut:OnCharacterDied(Character, CharacterController, KillerController)
	if
		gamemode.GetRoundStage() == "PreRoundWait" or
		gamemode.GetRoundStage() == "InProgress"
	then
		if CharacterController ~= nil then
			if actor.HasTag(CharacterController, self.OpForTeamTag) then
				-- OpFor standard eliminated
			else
				-- BluFor standard eliminated
				player.SetLives(
					CharacterController,
					player.GetLives(CharacterController) - 1
				)
				timer.Set(
					"CheckBluForCount",
					self,
					self.CheckBluForCountTimer,
					1.0,
					false
				)
			end
		end
	end
end

function BreakOut:CheckBluForCountTimer()
	local PlayersWithLives = gamemode.GetPlayerListByLives(
		self.PlayerTeams.BluFor.TeamId,
		 1,
		 true
	)
	if #PlayersWithLives == 0 then
		timer.Clear(self, "CheckOpForExfil")
		gamemode.AddGameStat("Result=None")
		gamemode.AddGameStat("Summary=BluForEliminated")
		gamemode.SetRoundStage("PostRoundWait")
	end
end

function BreakOut:ShouldCheckForTeamKills()
	if gamemode.GetRoundStage() == "InProgress" then
		return true
	end
	return false
end

function BreakOut:OnGameTriggerBeginOverlap(GameTrigger, Player)
	timer.Set("CheckOpForExfil", self, self.CheckOpForExfilTimer, 1.0, false)
end

function BreakOut:CheckOpForExfilTimer()
	local Overlaps = actor.GetOverlaps(
		self.ExtractionPoint,
		'GroundBranch.GBCharacter'
	)
	local PlayersWithLives = gamemode.GetPlayerListByLives(
		self.PlayerTeams.BluFor.TeamId,
		1,
		true
	)

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
			gamemode.AddGameStat("CompleteObjectives=ExfiltrateBluFor")
			gamemode.SetRoundStage("PostRoundWait")
		else
			timer.Set("CheckOpForExfil", self, self.CheckOpForExfilTimer, 1.0, false)
		end
	end
end

function BreakOut:PlayerCanEnterPlayArea(PlayerState)
	if player.GetInsertionPoint(PlayerState) ~= nil then
		return true
	end
	return false
end

function BreakOut:LogOut(Exiting)
	if
		gamemode.GetRoundStage() == "PreRoundWait" or
		gamemode.GetRoundStage() == "InProgress"
	then
		timer.Set("CheckBluForCount", self, self.CheckBluForCountTimer, 1.0, false)
	end
end

return BreakOut
