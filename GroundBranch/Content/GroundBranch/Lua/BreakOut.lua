local TableOperations = require("common.tableOperations")
local StringOperations = require("common.StringOperations")

local BreakOut = {
	UseReadyRoom = true,
	UseRounds = true,
	StringTables = {"BreakOut"},
	PlayerTeams = {
		BluFor = {
			TeamId = 1,
			Loadout = "Captive",
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
	--Players
	PlayersWithLives = {},
	PlayersInExtractionZone = 0,
	OpForPriorityGroupedSpawns = {},
	OpForPriorityGroupedSpawnsShuffled = {},
	OpForExfilGuardSpawnPoints = {},
	-- Extraction points
	ExtractionPoints = {},
	ExtractionPoint = nil,
	ExtractionPointTag = "",
	ExtractionPointMarkers = {},
	-- Game objective tracking variables
	BluForExfiltrated = false,
}

--#region Overloads

function BreakOut:PreInit()
	local AllSpawns = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAISpawnPoint')
	local PriorityIndex = 1
	local TotalSpawns = 0
	-- Orders spawns by priority while allowing spawns of the same priority to be randomised.
	for _, PriorityTag in ipairs(self.PriorityTags) do
		local bFoundTag = false
		for _, SpawnPoint in ipairs(AllSpawns) do
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
	-- Grabs groups of OpForSpawns guarding the possible exfil zones
	for _, SpawnPoint in ipairs(AllSpawns) do
		local actorTags = actor.GetTags(SpawnPoint)
		for _, actorTag in ipairs(actorTags) do
			if StringOperations.StartsWith(actorTag, "Exfil") then
				if self.OpForExfilGuardSpawnPoints[actorTag] == nil then
					self.OpForExfilGuardSpawnPoints[actorTag] = {}
				end
				table.insert(self.OpForExfilGuardSpawnPoints[actorTag], SpawnPoint)
			end
		end
	end
	-- Set maximum and minimum values for game settings
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
end

function BreakOut:PostInit()
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
	-- Add game objectives
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "ExfiltrateBluFor", 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "ExfiltrateAll", 2)
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
		self:ShuffleSpawns()
		self:SetUpObjectiveMarkers()
	elseif RoundStage == "PreRoundWait" then
		self:SpawnOpFor()
	elseif RoundStage == "InProgress" then
		self.PlayersWithLives = gamemode.GetPlayerListByLives(
			self.PlayerTeams.BluFor.TeamId,
			1,
			false
		)
	elseif RoundStage == "PostRoundWait" then
		timer.ClearAll()
		self:CleanUp()
	end
end

function BreakOut:OnCharacterDied(Character, CharacterController, KillerController)
	if gamemode.GetRoundStage() == "PreRoundWait" or
	gamemode.GetRoundStage() == "InProgress" then
		if CharacterController ~= nil then
			if not actor.HasTag(CharacterController, self.OpForTeamTag) then
				player.SetLives(
					CharacterController,
					player.GetLives(CharacterController) - 1
				)
				self.PlayersWithLives = gamemode.GetPlayerListByLives(
					self.PlayerTeams.BluFor.TeamId,
					1,
					false
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

function BreakOut:OnGameTriggerBeginOverlap(GameTrigger, Player)
	local playerCharacter = player.GetCharacter(Player)
	if playerCharacter ~= nil then
		local teamId = actor.GetTeamId(playerCharacter)
		if teamId == self.PlayerTeams.BluFor.TeamId and
		GameTrigger == self.ExtractionPoint then
			local total = self.PlayersInExtractionZone + 1
			self.PlayersInExtractionZone = total
			timer.Set("CheckBluForExfil", self, self.CheckBluForExfilTimer, 1.0, false)
		end
	end
end

function BreakOut:OnGameTriggerEndOverlap(GameTrigger, Player)
	local playerCharacter = player.GetCharacter(Player)
	if playerCharacter ~= nil then
		local teamId = actor.GetTeamId(playerCharacter)
		if teamId == self.PlayerTeams.BluFor.TeamId and
		GameTrigger == self.ExtractionPoint then
			local total = math.max(self.PlayersInExtractionZone - 1, 0)
			self.PlayersInExtractionZone = total
		end
	end
end

function BreakOut:ShouldCheckForTeamKills()
	if gamemode.GetRoundStage() == "InProgress" then
		return true
	end
	return false
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

--#endregion

--#region Spawn OpFor

function BreakOut:ShuffleSpawns()
	local tableWithShuffledSpawns = TableOperations.ShuffleKeyValueTables(
		self.OpForPriorityGroupedSpawns
	)
	self.OpForPriorityGroupedSpawnsShuffled = TableOperations.GetTableFromKeyValueTables(
		tableWithShuffledSpawns
	)
end

function BreakOut:SpawnOpFor()
	ai.CreateOverDuration(
		0.4,
		#self.OpForExfilGuardSpawnPoints[self.ExtractionPointTag],
		self.OpForExfilGuardSpawnPoints[self.ExtractionPointTag],
		self.OpForTeamTag
	)
	timer.Set("SpawnStandardOpFor", self, self.SpawnStandardOpForTimer, 0.5, false)
end

function BreakOut:SpawnStandardOpForTimer()
	ai.CreateOverDuration(
		3.5,
		self.Settings.OpForCount.Value - #self.OpForExfilGuardSpawnPoints[self.ExtractionPointTag],
		self.OpForPriorityGroupedSpawnsShuffled,
		self.OpForTeamTag
	)
end

--#endregion

--#region Objective markers

function BreakOut:SetUpObjectiveMarkers()
	self.ExtractionPointIndex = math.random(#self.ExtractionPoints)
	self.ExtractionPoint = self.ExtractionPoints[self.ExtractionPointIndex]
	for i = 1, #self.ExtractionPoints do
		local bActive = (i == self.ExtractionPointIndex)
		actor.SetActive(self.ExtractionPoints[i], bActive)
		actor.SetActive(self.ExtractionPointMarkers[i], bActive)
	end
	local exfilTags = actor.GetTags(self.ExtractionPoint)
	for _, exfilTag in ipairs(exfilTags) do
		if StringOperations.StartsWith(exfilTag, "Exfil") then
			self.ExtractionPointTag = exfilTag
		end
	end
end

--#endregion

--#region Objective: Exfiltrate

function BreakOut:CheckBluForExfilTimer()
	if self.PlayersInExtractionZone >= #self.PlayersWithLives then
		self.BluForExfiltrated = true
		gamemode.AddGameStat("Result=Team1")
		if #self.PlayersWithLives >= gamemode.GetPlayerCount(true) then
			gamemode.AddGameStat("CompleteObjectives=ExfiltrateBluFor,ExfiltrateAll")
			gamemode.AddGameStat("Summary=BluForExfilSuccess")
		else
			gamemode.AddGameStat("CompleteObjectives=ExfiltrateBluFor")
			gamemode.AddGameStat("Summary=BluForExfilPartialSuccess")
		end
		gamemode.SetRoundStage("PostRoundWait")
	end
end

--#endregion

--#region Fail condition

function BreakOut:CheckBluForCountTimer()
	if #self.PlayersWithLives == 0 then
		timer.Clear(self, "CheckBluForExfil")
		gamemode.AddGameStat("Result=None")
		gamemode.AddGameStat("Summary=BluForEliminated")
		gamemode.SetRoundStage("PostRoundWait")
	end
end

--#endregion

--region Helper methods

function BreakOut:CleanUp()
	self.PlayersWithLives = {}
	self.PlayersInExtractionZone = 0
	self.OpForPriorityGroupedSpawnsShuffled = {}
	self.OpForExfilGuardSpawnPoints = {}
	self.ExtractionPoint = nil
	self.ExtractionPointTag = ""
	self.BluForExfiltrated = false
	ai.CleanUp(self.OpForTeamTag)
end

--#endregion

return BreakOut
