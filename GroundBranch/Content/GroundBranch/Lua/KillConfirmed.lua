local TableOperations = require("common.TableOperations")

--#region variables

local KillConfirmed = {
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
	-- Players
	PlayersWithLives = {},
	-- OpFor standard spawns
	OpForTeamTag = "OpFor",
	PriorityTags = {
		"AISpawn_1", "AISpawn_2", "AISpawn_3", "AISpawn_4", "AISpawn_5", "AISpawn_6_10",
		"AISpawn_11_20", "AISpawn_21_30", "AISpawn_31_40", "AISpawn_41_50"
	},
	OpForPriorityGroupedSpawns = {},
	OpForPriorityGroupedSpawnsShuffled = {},
	-- OpFor leader spawns
	OpForLeaderTag = "OpForLeader",
	OpForLeaderSpawns = {},
	OpForLeaderSpawnsShuffled = {},
	OpForLeaderSpawnMarkers = {},
	-- Extraction points
	ExtractionPoints = {},
	ExtractionPoint = nil,
	ExtractionPointMarkers = {},
	PlayersInExtractionZone = 0,
	-- Game objective tracking variables
	OpForLeadersEliminatedNotConfirmed = {},
	OpForLeadersEliminatedAndConfirmed = {},
	BluForExfiltrated = false,
	-- Objective world prompt timers
	ObjectiveWorldPromptShowTime = 5.0,
	ObjectiveWorldPromptDelay = 15.0,
	-- Updating HVT position workaround data
	LastLeaderCount = 0
}

--#endregion

--#region overloads

function KillConfirmed:PreInit()
	local AllSpawns = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAISpawnPoint')
	local PriorityIndex = 1
	local TotalSpawns = 0
	-- Orders spawns by priority while allowing spawns of the same priority to be
	-- randomised and gathers all HVT spawns.
	for _, SpawnPoint in ipairs(AllSpawns) do
		for _, PriorityTag in ipairs(self.PriorityTags) do
			local bFoundTag = false
			if actor.HasTag(SpawnPoint, PriorityTag) and
			not actor.HasTag(SpawnPoint, self.OpForLeaderTag) then
				bFoundTag = true
				if self.OpForPriorityGroupedSpawns[PriorityIndex] == nil then
					self.OpForPriorityGroupedSpawns[PriorityIndex] = {}
				end
				-- Ensures we can't spawn more AI then this map can handle.
				TotalSpawns = TotalSpawns + 1
				table.insert(self.OpForPriorityGroupedSpawns[PriorityIndex], SpawnPoint)
			end
			-- Ensures we don't create empty tables for unused priorities.
			if bFoundTag then
				PriorityIndex = PriorityIndex + 1
			end
		end
		if actor.HasTag(SpawnPoint, self.OpForLeaderTag) then
			table.insert(self.OpForLeaderSpawns, SpawnPoint)
		end
	end
	-- Set maximum and minimum values for game settings
	self.Settings.LeaderCount.Max = math.min(ai.GetMaxCount(), #self.OpForLeaderSpawns)
	self.Settings.LeaderCount.Value = math.min(
		self.Settings.LeaderCount.Value,
		self.Settings.LeaderCount.Max
	)
	self.LastLeaderCount = self.Settings.LeaderCount.Value
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

function KillConfirmed:PostInit()
	-- Add objective markers to all possible HVT spawn points
	for _, SpawnPoint in ipairs(self.OpForLeaderSpawns) do
		local description = "HVT"
		description = self:GetSuffixFromActorTag(SpawnPoint, "ObjectiveMarker")
		self.OpForLeaderSpawnMarkers[description] = gamemode.AddObjectiveMarker(
			actor.GetLocation(SpawnPoint),
			self.PlayerTeams.BluFor.TeamId,
			description,
			false
		)
	end
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
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "EliminateHighValueTargets", 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "ConfirmHighValueTargets", 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "ExfiltrateBluFor", 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "LastKnownLocation", 1)
end

function KillConfirmed:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	if InsertionPoint == nil then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	else
		timer.Set("CheckReadyUp", self, self.CheckReadyUpTimer, 0.25, false)
	end
end

function KillConfirmed:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	if ReadyStatus ~= "DeclaredReady" then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	elseif
		gamemode.GetRoundStage() == "PreRoundWait" and
		gamemode.PrepLatecomer(PlayerState)
	then
		gamemode.EnterPlayArea(PlayerState)
	end
end

function KillConfirmed:OnRoundStageSet(RoundStage)
	if RoundStage == "WaitingForReady" then
		self:CleanUp()
		self:ShuffleSpawns()
		self:SetUpExtractionObjectiveMarkers()
		self:SetUpLeaderObjectiveMarkeres()
		timer.Set("CheckIfLeaderCountChanged", self, self.CheckIfLeaderCountChanged, 1, true)
	elseif RoundStage == "PreRoundWait" then
		timer.Clear("CheckIfLeaderCountChanged")
		self:SpawnOpFor()
	elseif RoundStage == "InProgress" then
		self.PlayersWithLives = gamemode.GetPlayerListByLives(
			self.PlayerTeams.BluFor.TeamId,
			1,
			false
		)
		timer.Set(
			"GuideToEliminatedLeaders",
			self,
			self.GuideToEliminatedLeaderTimer,
			self.ObjectiveWorldPromptDelay,
			true
		)
	elseif RoundStage == "PostRoundWait" then
		timer.ClearAll()
	end
end

function KillConfirmed:OnCharacterDied(Character, CharacterController, KillerController)
	if gamemode.GetRoundStage() == "PreRoundWait" or
	gamemode.GetRoundStage() == "InProgress" then
		if CharacterController ~= nil then
			if actor.HasTag(CharacterController, self.OpForLeaderTag) then
				-- OpFor leader eliminated
				timer.Set(
					"ShowHVTEliminated",
					self,
					self.ShowHVTEliminatedTimer,
					1.0,
					false
				)
				table.insert(
					self.OpForLeadersEliminatedNotConfirmed,
					actor.GetLocation(Character)
				)
				timer.Set("CheckIfConfirmed", self, self.CheckIfKillConfirmedTimer, 0.1, false)
			elseif actor.HasTag(CharacterController, self.OpForTeamTag) then
				-- OpFor standard eliminated
			else
				-- BluFor standard eliminated
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

function KillConfirmed:ShouldCheckForTeamKills()
	if gamemode.GetRoundStage() == "InProgress" then
		return true
	end
	return false
end

function KillConfirmed:OnGameTriggerBeginOverlap(GameTrigger, Player)
	local playerCharacter = player.GetCharacter(Player)
	if playerCharacter ~= nil then
		local teamId = actor.GetTeamId(playerCharacter)
		if teamId == self.PlayerTeams.BluFor.TeamId and
		GameTrigger == self.ExtractionPoint then
			self.PlayersInExtractionZone = self.PlayersInExtractionZone + 1
			timer.Set("CheckOpForExfil", self, self.CheckBluForExfilTimer, 1.0, false)
		end
	end
end

function KillConfirmed:OnGameTriggerEndOverlap(GameTrigger, Player)
	local playerCharacter = player.GetCharacter(Player)
	if playerCharacter ~= nil then
		local teamId = actor.GetTeamId(playerCharacter)
		if teamId == self.PlayerTeams.BluFor.TeamId and
		GameTrigger == self.ExtractionPoint then
			self.PlayersInExtractionZone = math.max(self.PlayersInExtractionZone - 1, 0)
		end
	end
end

function KillConfirmed:PlayerCanEnterPlayArea(PlayerState)
	if player.GetInsertionPoint(PlayerState) ~= nil then
		return true
	end
	return false
end

function KillConfirmed:LogOut(Exiting)
	if
		gamemode.GetRoundStage() == "PreRoundWait" or
		gamemode.GetRoundStage() == "InProgress"
	then
		timer.Set("CheckBluForCount", self, self.CheckBluForCountTimer, 1.0, false)
	end
end

--#endregion

--#region methods

function KillConfirmed:CleanUp()
	ai.CleanUp(self.OpForLeaderTag)
	ai.CleanUp(self.OpForTeamTag)
	self.PlayersWithLives = {}
	self.OpForLeadersEliminatedNotConfirmed = {}
	self.OpForLeadersEliminatedAndConfirmed = {}
	self.PlayersInExtractionZone = 0
	self.BluForExfiltrated = false
end

function KillConfirmed:ShuffleSpawns()
	local tableWithShuffledSpawns = TableOperations.ShuffleTables(
		self.OpForPriorityGroupedSpawns
	)
	self.OpForPriorityGroupedSpawnsShuffled = TableOperations.GetTableFromTables(
		tableWithShuffledSpawns
	)
	self.OpForLeaderSpawnsShuffled = TableOperations.ShuffleTable(
		self.OpForLeaderSpawns
	)
end

function KillConfirmed:SetUpLeaderObjectiveMarkeres()
	-- High value targets
	for i, v in ipairs(self.OpForLeaderSpawnsShuffled) do
		local spawnTag = self:GetSuffixFromActorTag(v, "ObjectiveMarker")
		if i <= self.Settings.LeaderCount.Value then
			actor.SetActive(self.OpForLeaderSpawnMarkers[spawnTag], true)
		else
			actor.SetActive(self.OpForLeaderSpawnMarkers[spawnTag], false)
		end
	end
end

function KillConfirmed:SetUpExtractionObjectiveMarkers()
	-- Extraction points
	self.ExtractionPointIndex = math.random(#self.ExtractionPoints)
	self.ExtractionPoint = self.ExtractionPoints[self.ExtractionPointIndex]
	for i = 1, #self.ExtractionPoints do
		local bActive = (i == self.ExtractionPointIndex)
		actor.SetActive(self.ExtractionPoints[i], bActive)
		actor.SetActive(self.ExtractionPointMarkers[i], bActive)
	end
end

function KillConfirmed:SpawnOpFor()
	ai.CreateOverDuration(
		3.5,
		self.Settings.OpForCount.Value,
		self.OpForPriorityGroupedSpawnsShuffled,
		self.OpForTeamTag
	)
	-- We need to wait for the execution of the ai.CreateOverDuration to finish
	-- before calling it again. As a precaution wait is slightly longer than neccessary.
	timer.Set("SpawnOpForLeaders", self, self.SpawnOpForLeadersTimer, 3.6, false)
end

function KillConfirmed:ConfirmKill()
	if #self.OpForLeadersEliminatedAndConfirmed >= self.Settings.LeaderCount.Value then
		timer.Set(
			"ShowAllKillConfirmed",
			self,
			self.ShowAllKillConfirmedTimer,
			1.0,
			false
		)
	else
		timer.Set(
			"ShowKillConfirmed",
			self,
			self.ShowKillConfirmedTimer,
			1.0,
			false
		)
	end
end

function KillConfirmed:GetSuffixFromActorTag(spawnPoint, tagPrefix)
	for _, value in ipairs(actor.GetTags(spawnPoint)) do
		if string.sub(value, 1, #tagPrefix) == tagPrefix then
			return string.sub(value, #tagPrefix + 1)
		end
	end
end

--#endregion

--#region timers

function KillConfirmed:CheckIfKillConfirmedTimer()
	local LowestDist = 1000.0
	local TimeTillNextCheck = 1.0
	for index, LeaderLocation in ipairs(self.OpForLeadersEliminatedNotConfirmed) do
		for _, PlayerController in ipairs(self.PlayersWithLives) do
			local PlayerLocation = actor.GetLocation(player.GetCharacter(PlayerController))
			local DistVector = PlayerLocation - LeaderLocation
			local Dist = vector.Size(DistVector)
			LowestDist = math.min(LowestDist, Dist)
			if vector.Size2D({DistVector.x, DistVector.y}) <= 250 and math.abs(DistVector.z) < 110 then
				table.insert(self.OpForLeadersEliminatedAndConfirmed, LeaderLocation)
				table.remove(self.OpForLeadersEliminatedNotConfirmed, index)
				self:ConfirmKill()
			end
		end
	end
	print("Leaders count NC C " .. #self.OpForLeadersEliminatedNotConfirmed .. " " .. #self.OpForLeadersEliminatedAndConfirmed)
	if #self.OpForLeadersEliminatedNotConfirmed > 0 then
		TimeTillNextCheck = math.max(math.min(LowestDist/1000, 1.0), 0.1)
		print("Time till next check " .. TimeTillNextCheck)
		timer.Set("CheckIfKillConfirmedTimer", self, self.CheckIfKillConfirmedTimer, TimeTillNextCheck, false)
	end
end

function KillConfirmed:CheckBluForCountTimer()
	if #self.PlayersWithLives == 0 then
		timer.Clear(self, "CheckOpForExfil")
		gamemode.AddGameStat("Result=None")
		if #self.OpForLeadersEliminatedNotConfirmed == self.Settings.LeaderCount.Value then
			gamemode.AddGameStat("Summary=BluForExfilFailed")
			gamemode.AddGameStat(
				"CompleteObjectives=EliminateHighValueTargets,LastKnownLocation"
			)
		elseif #self.OpForLeadersEliminatedAndConfirmed == self.Settings.LeaderCount.Value then
			gamemode.AddGameStat("Summary=BluForExfilFailed")
			gamemode.AddGameStat(
				"CompleteObjectives=EliminateHighValueTargets,ConfirmHighValueTargets,LastKnownLocation"
			)
		else
			gamemode.AddGameStat("Summary=BluForEliminated")
		end
		gamemode.SetRoundStage("PostRoundWait")
	end
end

function KillConfirmed:CheckBluForExfilTimer()
	if #self.OpForLeadersEliminatedAndConfirmed >= self.Settings.LeaderCount.Value and
	self.PlayersInExtractionZone >= #self.PlayersWithLives then
		self.BluForExfiltrated = true
		gamemode.AddGameStat("Result=Team1")
		gamemode.AddGameStat("Summary=HighValueTargetsConfirmed")
		gamemode.AddGameStat(
			"CompleteObjectives=EliminateHighValueTargets,ConfirmHighValueTargets,LastKnownLocation,ExfiltrateBluFor"
		)
		gamemode.SetRoundStage("PostRoundWait")
	end
end

function KillConfirmed:CheckReadyUpTimer()
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

function KillConfirmed:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		if ReadyPlayerTeamCounts[self.PlayerTeams.BluFor.TeamId] < 1 then
			gamemode.SetRoundStage("WaitingForReady")
		end
	end
end

function KillConfirmed:SpawnOpForLeadersTimer()
	ai.CreateOverDuration(
		0.4,
		self.Settings.LeaderCount.Value,
		self.OpForLeaderSpawnsShuffled,
		self.OpForLeaderTag
	)
end

function KillConfirmed:ShowHVTEliminatedTimer()
	gamemode.BroadcastGameMessage("HighValueTargetEliminated", "Engine", 10.0)
end

function KillConfirmed:ShowKillConfirmedTimer()
	gamemode.BroadcastGameMessage("HighValueTargetConfirmed", "Engine", 10.0)
end

function KillConfirmed:ShowAllKillConfirmedTimer()
	gamemode.BroadcastGameMessage("AllHighValueTargetsConfirmed", "Engine", 10.0)
	timer.Set(
		"GuideToExtraction",
		self,
		self.GuideToExtractionTimer,
		self.ObjectiveWorldPromptDelay,
		true
	)
end

function KillConfirmed:GuideToExtractionTimer()
	local ExtractionLocation = actor.GetLocation(self.ExtractionPoint)
	for _, Player in ipairs(self.PlayersWithLives) do
		player.ShowWorldPrompt(Player, ExtractionLocation, "Extraction", self.ObjectiveWorldPromptShowTime)
	end
end

function KillConfirmed:GuideToEliminatedLeaderTimer()
	for _, LeaderLocation in ipairs(self.OpForLeadersEliminatedNotConfirmed) do
		for _, Player in ipairs(self.PlayersWithLives) do
			player.ShowWorldPrompt(Player, LeaderLocation, "ConfirmKill", self.ObjectiveWorldPromptShowTime)
		end
	end
end

function KillConfirmed:CheckIfLeaderCountChanged()
	if self.LastLeaderCount ~= self.Settings.LeaderCount.Value then
		self:SetUpLeaderObjectiveMarkeres()
		self.LastLeaderCount = self.Settings.LeaderCount.Value
	end
end

--#endregion

return KillConfirmed
