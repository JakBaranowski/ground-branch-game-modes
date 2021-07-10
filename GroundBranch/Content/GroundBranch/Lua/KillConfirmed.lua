local TabOps = require("common.TableOperations")
local StrOps = require("common.StringOperations")

--#region Properties

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
		HVTCount = {
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
	Players = {
		WithLives = {},
	},
	OpFor = {
		Tag = "OpFor",
		PriorityTags = {
			"AISpawn_1", "AISpawn_2", "AISpawn_3", "AISpawn_4", "AISpawn_5", "AISpawn_6_10",
			"AISpawn_11_20", "AISpawn_21_30", "AISpawn_31_40", "AISpawn_41_50"
		},
		SpawnsPriorityGrouped = {},
		SpawnsShuffled = {},
	},
	HVT = {
		Tag = "HVT",
		Spawns = {},
		SpawnsShuffled = {},
		SpawnMarkers = {},
		EliminatedNotConfirmed = {},
		EliminatedAndConfirmed = {},
	},
	Extraction = {
		AllPoints = {},
		ActivePoint = nil,
		AllMarkers = {},
		PlayersIn = 0,
	},
	UI = {
		ObjectiveWorldPromptShowTime = 5.0,
		ObjectiveWorldPromptDelay = 15.0,
	},
	SettingsTracker = {
		LastHVTCount = 0
	},
	Timers = {
		Exfiltration = {
			Name = "ExfilTimer",
			DefaultTime = 4.0,
			CurrentTime = 4.0,
			TimeStep = 1.0,
			InProgress = false
		},
	},
	Subscriptions = {
		OnGameTriggerBeginOverlap = {},
		OnGameTriggerEndOverlap = {},
	},
}

--#endregion

--#region Preparation

function KillConfirmed:PreInit()
	local PriorityIndex = 1
	local TotalSpawns = 0
	-- Gathers all OpFor spawn points
	for _, PriorityTag in ipairs(self.OpFor.PriorityTags) do
		local spawnsWithTag = gameplaystatics.GetAllActorsOfClassWithTag(
			'GroundBranch.GBAISpawnPoint',
			PriorityTag
		)
		if #spawnsWithTag > 0 then
			self.OpFor.SpawnsPriorityGrouped[PriorityIndex] = spawnsWithTag
			TotalSpawns = TotalSpawns + #spawnsWithTag
			PriorityIndex = PriorityIndex + 1
		end
	end
	-- Gathers all HVT spawn points
	self.HVT.Spawns = gameplaystatics.GetAllActorsOfClassWithTag(
		'GroundBranch.GBAISpawnPoint',
		self.HVT.Tag
	)
	-- Gathers all extraction points placed in the mission
	self.Extraction.AllPoints = gameplaystatics.GetAllActorsOfClass(
		'/Game/GroundBranch/Props/GameMode/BP_ExtractionPoint.BP_ExtractionPoint_C'
	)
	-- Set maximum HVT count and ensure that HVT value is within limit
	self.Settings.HVTCount.Max = math.min(ai.GetMaxCount(), #self.HVT.Spawns)
	self.Settings.HVTCount.Value = math.min(
		self.Settings.HVTCount.Value,
		self.Settings.HVTCount.Max
	)
	-- Set maximum OpFor count and ensure that value is within limit
	self.Settings.OpForCount.Max = math.min(
		ai.GetMaxCount() - self.Settings.HVTCount.Max,
		TotalSpawns
	)
	self.Settings.OpForCount.Value = math.min(
		self.Settings.OpForCount.Value,
		self.Settings.OpForCount.Max
	)
	-- Set last HVT count for tracking if the setting has changed.
	-- This is neccessary for adding objective markers on map.
	self.SettingsTracker.LastHVTCount = self.Settings.HVTCount.Value
end

function KillConfirmed:PostInit()
	-- Add inactive objective markers to all possible HVT spawn points.
	for _, SpawnPoint in ipairs(self.HVT.Spawns) do
		local description = "HVT"
		description = self:GetSuffixFromActorTag(SpawnPoint, "ObjectiveMarker")
		self.HVT.SpawnMarkers[description] = gamemode.AddObjectiveMarker(
			actor.GetLocation(SpawnPoint),
			self.PlayerTeams.BluFor.TeamId,
			description,
			false
		)
	end
	-- Adds inactive objective markers for all possible extraction points.
	for i = 1, #self.Extraction.AllPoints do
		local Location = actor.GetLocation(self.Extraction.AllPoints[i])
		self.Extraction.AllMarkers[i] = gamemode.AddObjectiveMarker(
			Location,
			self.PlayerTeams.BluFor.TeamId,
			"Extraction",
			false
		)
	end
	-- Add game mode objectives
	gamemode.AddGameObjective(
		self.PlayerTeams.BluFor.TeamId,
		"EliminateHighValueTargets",
		1
	)
	gamemode.AddGameObjective(
		self.PlayerTeams.BluFor.TeamId,
		"ConfirmHighValueTargets",
		1
	)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "ExfiltrateBluFor", 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "LastKnownLocation", 2)
end

--#endregion

--#region Common

function KillConfirmed:OnRoundStageSet(RoundStage)
	-- On every round stage change clear all timers.
	timer.ClearAll()
	if RoundStage == "WaitingForReady" then
		-- At this stage players have been assigned to teams.
		self:ShuffleSpawns()
		self:SetUpExtractionObjectiveMarkers()
		self:SetUpLeaderObjectiveMarkeres()
		timer.Set(
			"CheckIfHVTCountChanged",
			self,
			self.CheckIfHVTCountChanged,
			1,
			true
		)
	elseif RoundStage == "PreRoundWait" then
		-- At this stage players are already spawned in AO, but still frozen.
		self:SpawnOpFor()
	elseif RoundStage == "InProgress" then
		-- At this stage players become unfrozen, and the round is properly started.
		self.Players.WithLives = gamemode.GetPlayerListByLives(
			self.PlayerTeams.BluFor.TeamId,
			1,
			false
		)
		timer.Set(
			"GuideToEliminatedLeaders",
			self,
			self.GuideToEliminatedLeaderTimer,
			self.UI.ObjectiveWorldPromptDelay,
			true
		)
	elseif RoundStage == "PostRoundWait" then
		-- The round have ended, either with victory or loss. Players will be moved
		-- to ready room soon.
		self:PostRoundCleanUp()
	end
end

function KillConfirmed:ShouldCheckForTeamKills()
	if gamemode.GetRoundStage() == "InProgress" then
		return true
	end
	return false
end

function KillConfirmed:PlayerCanEnterPlayArea(PlayerState)
	if player.GetInsertionPoint(PlayerState) ~= nil then
		return true
	end
	return false
end

function KillConfirmed:OnCharacterDied(Character, CharacterController, KillerController)
	if gamemode.GetRoundStage() == "PreRoundWait" or
	gamemode.GetRoundStage() == "InProgress" then
		if CharacterController ~= nil then
			if actor.HasTag(CharacterController, self.HVT.Tag) then
				-- OpFor leader eliminated.
				self:ShowHVTEliminated()
				table.insert(
					self.HVT.EliminatedNotConfirmed,
					actor.GetLocation(Character)
				)
				timer.Set(
					"CheckIfConfirmed",
					self,
					self.CheckIfKillConfirmedTimer,
					0.1,
					false
				)
			elseif actor.HasTag(CharacterController, self.OpFor.Tag) then
				-- OpFor standard eliminated.
			else
				-- BluFor eliminated.
				player.SetLives(
					CharacterController,
					player.GetLives(CharacterController) - 1
				)
				self.Players.WithLives = gamemode.GetPlayerListByLives(
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

function KillConfirmed:LogOut(Exiting)
	-- Player lef the game.
	if gamemode.GetRoundStage() == "PreRoundWait" or
	gamemode.GetRoundStage() == "InProgress" then
		timer.Set("CheckBluForCount", self, self.CheckBluForCountTimer, 1.0, false)
	end
end

--#endregion

--#region Player Status

function KillConfirmed:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	if InsertionPoint == nil then
		-- Player unchecked insertion point.
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	else
		-- Player checked insertion point.
		timer.Set("CheckReadyUp", self, self.CheckReadyUpTimer, 0.25, false)
	end
end

function KillConfirmed:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	if ReadyStatus ~= "DeclaredReady" then
		-- Player declared they're ready.
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	elseif gamemode.GetRoundStage() == "PreRoundWait" and
	gamemode.PrepLatecomer(PlayerState) then
		-- Player did not declare ready, but the timer run out.
		gamemode.EnterPlayArea(PlayerState)
	end
end

function KillConfirmed:CheckReadyUpTimer()
	if gamemode.GetRoundStage() == "WaitingForReady" or
	gamemode.GetRoundStage() == "ReadyCountdown" then
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

--#endregion

--#region Objective Markers

function KillConfirmed:SetUpLeaderObjectiveMarkeres()
	for i, v in ipairs(self.HVT.SpawnsShuffled) do
		local spawnTag = self:GetSuffixFromActorTag(v, "ObjectiveMarker")
		if i <= self.Settings.HVTCount.Value then
			actor.SetActive(self.HVT.SpawnMarkers[spawnTag], true)
		else
			actor.SetActive(self.HVT.SpawnMarkers[spawnTag], false)
		end
	end
end

function KillConfirmed:SetUpExtractionObjectiveMarkers()
	self.ExtractionPointIndex = math.random(#self.Extraction.AllPoints)
	self.Extraction.ActivePoint = self.Extraction.AllPoints[self.ExtractionPointIndex]
	for i = 1, #self.Extraction.AllPoints do
		local bActive = (i == self.ExtractionPointIndex)
		actor.SetActive(self.Extraction.AllPoints[i], bActive)
		actor.SetActive(self.Extraction.AllMarkers[i], bActive)
	end
end

--#endregion

--#region Spawn OpFor

function KillConfirmed:ShuffleSpawns()
	local tableWithShuffledSpawns = TabOps.ShuffleIndexedTables(
		self.OpFor.SpawnsPriorityGrouped
	)
	self.OpFor.SpawnsShuffled = TabOps.GetTableFromIndexedTables(
		tableWithShuffledSpawns
	)
	self.HVT.SpawnsShuffled = TabOps.ShuffleTable(
		self.HVT.Spawns
	)
end

function KillConfirmed:SpawnOpFor()
	ai.CreateOverDuration(
		0.4,
		self.Settings.HVTCount.Value,
		self.HVT.SpawnsShuffled,
		self.HVT.Tag
	)
	timer.Set("SpawnStandardOpFor", self, self.SpawnStandardOpForTimer, 0.5, false)
end

function KillConfirmed:SpawnStandardOpForTimer()
	ai.CreateOverDuration(
		3.5,
		self.Settings.OpForCount.Value,
		self.OpFor.SpawnsShuffled,
		self.OpFor.Tag
	)
end

--#endregion

--#region Game Messages and World Prompts

function KillConfirmed:ShowHVTEliminated()
	gamemode.BroadcastGameMessage("HighValueTargetEliminated", "Engine", 5.0)
end

function KillConfirmed:ShowKillConfirmed()
	gamemode.BroadcastGameMessage("HighValueTargetConfirmed", "Engine", 5.0)
end

function KillConfirmed:ShowAllKillConfirmed()
	gamemode.BroadcastGameMessage("AllHighValueTargetsConfirmed", "Engine", 5.0)
end

function KillConfirmed:GuideToExtractionTimer()
	local ExtractionLocation = actor.GetLocation(self.Extraction.ActivePoint)
	for _, Player in ipairs(self.Players.WithLives) do
		player.ShowWorldPrompt(
			Player,
			ExtractionLocation,
			"Extraction",
			self.UI.ObjectiveWorldPromptShowTime
		)
	end
end

function KillConfirmed:GuideToEliminatedLeaderTimer()
	if #self.HVT.EliminatedNotConfirmed <= 0 then
		return
	end
	for _, LeaderLocation in ipairs(self.HVT.EliminatedNotConfirmed) do
		for _, Player in ipairs(self.Players.WithLives) do
			player.ShowWorldPrompt(
				Player,
				LeaderLocation,
				"ConfirmKill",
				self.UI.ObjectiveWorldPromptShowTime
			)
		end
	end
end

--#endregion

--#region Objective: Kill confirmed

function KillConfirmed:CheckIfKillConfirmedTimer()
	local LowestDist = 1000.0
	local TimeTillNextCheck = 1.0
	for index, LeaderLocation in ipairs(self.HVT.EliminatedNotConfirmed) do
		for _, PlayerController in ipairs(self.Players.WithLives) do
			local PlayerLocation = actor.GetLocation(
				player.GetCharacter(PlayerController)
			)
			local DistVector = PlayerLocation - LeaderLocation
			local Dist = vector.Size(DistVector)
			LowestDist = math.min(LowestDist, Dist)
			if Dist <= 250 and math.abs(DistVector.z) < 110 then
				table.insert(self.HVT.EliminatedAndConfirmed, LeaderLocation)
				table.remove(self.HVT.EliminatedNotConfirmed, index)
				self:ConfirmKill()
			end
		end
	end
	if #self.HVT.EliminatedNotConfirmed > 0 then
		TimeTillNextCheck = math.max(math.min(LowestDist/1000, 1.0), 0.1)
		timer.Set(
			"CheckIfKillConfirmedTimer",
			self,
			self.CheckIfKillConfirmedTimer,
			TimeTillNextCheck,
			false
		)
	end
end

function KillConfirmed:ConfirmKill()
	if #self.HVT.EliminatedAndConfirmed >= self.Settings.HVTCount.Value then
		self:ShowAllKillConfirmed()
		timer.Set(
			"GuideToExtraction",
			self,
			self.GuideToExtractionTimer,
			self.UI.ObjectiveWorldPromptDelay,
			true
		)
		if self.Extraction.PlayersIn > 0 then
			timer.Set(self.Timers.Exfiltration.Name, self, self.CheckBluForExfilTimer, 0.1, false)
		end
	else
		self:ShowKillConfirmed()
	end
end

--#endregion

--#region Objective: Extraction

function KillConfirmed:OnGameTriggerBeginOverlap(GameTrigger, Player)
	local playerCharacter = player.GetCharacter(Player)
	if playerCharacter ~= nil then
		local teamId = actor.GetTeamId(playerCharacter)
		if teamId == self.PlayerTeams.BluFor.TeamId and
		GameTrigger == self.Extraction.ActivePoint then
			local total = math.min(self.Extraction.PlayersIn + 1, #self.Players.WithLives)
			self.Extraction.PlayersIn = total
			if not self.Timers.Exfiltration.InProgress and
			#self.HVT.EliminatedAndConfirmed >= self.Settings.HVTCount.Value then
				self.Timers.Exfiltration.InProgress = true
				timer.Set(self.Timers.Exfiltration.Name, self, self.CheckBluForExfilTimer, 0.1, false)
			end
		end
	end
end

function KillConfirmed:OnGameTriggerEndOverlap(GameTrigger, Player)
	local playerCharacter = player.GetCharacter(Player)
	if playerCharacter ~= nil then
		local teamId = actor.GetTeamId(playerCharacter)
		if teamId == self.PlayerTeams.BluFor.TeamId and
		GameTrigger == self.Extraction.ActivePoint then
			local total = math.max(self.Extraction.PlayersIn - 1, 0)
			self.Extraction.PlayersIn = total
		end
	end
end

function KillConfirmed:CheckBluForExfilTimer()
	if self.Extraction.PlayersIn >= #self.Players.WithLives then
		self.Timers.Exfiltration.CurrentTime = self.Timers.Exfiltration.CurrentTime - self.Timers.Exfiltration.TimeStep
		gamemode.BroadcastGameMessage("ExfiltrationInProgress.T-" .. math.floor(self.Timers.Exfiltration.CurrentTime), "Engine", self.Timers.Exfiltration.TimeStep)
	elseif self.Extraction.PlayersIn > 0 then
		gamemode.BroadcastGameMessage("ExfiltrationPaused.T-" .. math.floor(self.Timers.Exfiltration.CurrentTime), "Engine", self.Timers.Exfiltration.TimeStep)
	else
		self.Timers.Exfiltration.CurrentTime = self.Timers.Exfiltration.DefaultTime
		gamemode.BroadcastGameMessage("ExfiltrationCancelled.TeamLeftExtractionZone.", "Engine", self.Timers.Exfiltration.TimeStep*2)
		timer.Clear(self, self.Timers.Exfiltration.Name)
		self.Timers.Exfiltration.InProgress = false
		return
	end
	if self.Timers.Exfiltration.CurrentTime > 0 then
		timer.Set(self.Timers.Exfiltration.Name, self, self.CheckBluForExfilTimer, self.Timers.Exfiltration.TimeStep, false)
		self.Timers.Exfiltration.InProgress = true
	else
		self:Exfiltrate()
		timer.Clear(self, self.Timers.Exfiltration.Name)
		self.Timers.Exfiltration.InProgress = false
		self.Timers.Exfiltration.CurrentTime = self.Timers.Exfiltration.DefaultTime
	end
end

function KillConfirmed:Exfiltrate()
	if gamemode.GetRoundStage() ~= "InProgress" then
		return
	end
	gamemode.AddGameStat("Result=Team1")
	gamemode.AddGameStat("Summary=HighValueTargetsConfirmed")
	gamemode.AddGameStat(
		"CompleteObjectives=EliminateHighValueTargets,ConfirmHighValueTargets," ..
		"LastKnownLocation,ExfiltrateBluFor"
	)
	gamemode.SetRoundStage("PostRoundWait")
end

--#endregion

--#region Fail Condition

function KillConfirmed:CheckBluForCountTimer()
	if #self.Players.WithLives == 0 then
		timer.Clear(self, "CheckBluForExfil")
		gamemode.AddGameStat("Result=None")
		if #self.HVT.EliminatedNotConfirmed ==
		self.Settings.HVTCount.Value then
			gamemode.AddGameStat("Summary=BluForExfilFailed")
			gamemode.AddGameStat(
				"CompleteObjectives=EliminateHighValueTargets,LastKnownLocation"
			)
		elseif #self.HVT.EliminatedAndConfirmed ==
		self.Settings.HVTCount.Value then
			gamemode.AddGameStat("Summary=BluForExfilFailed")
			gamemode.AddGameStat(
				"CompleteObjectives=EliminateHighValueTargets," ..
				"ConfirmHighValueTargets,LastKnownLocation"
			)
		else
			gamemode.AddGameStat("Summary=BluForEliminated")
		end
		gamemode.SetRoundStage("PostRoundWait")
	end
end

--#endregion

--#region Helpers

function KillConfirmed:PostRoundCleanUp()
	ai.CleanUp(self.HVT.Tag)
	ai.CleanUp(self.OpFor.Tag)
	self.Players.WithLives = {}
	self.HVT.EliminatedNotConfirmed = {}
	self.HVT.EliminatedAndConfirmed = {}
	self.Extraction.PlayersIn = 0
end

function KillConfirmed:CheckIfHVTCountChanged()
	if self.SettingsTracker.LastHVTCount ~= self.Settings.HVTCount.Value then
		self:SetUpLeaderObjectiveMarkeres()
		self.SettingsTracker.LastHVTCount = self.Settings.HVTCount.Value
	end
end

function KillConfirmed:GetSuffixFromActorTag(actorWithTag, tagPrefix)
	for _, actorTag in ipairs(actor.GetTags(actorWithTag)) do
		if StrOps.StartsWith(actorTag, tagPrefix) then
			return StrOps.GetSuffix(actorTag, tagPrefix)
		end
	end
end

--#endregion

return KillConfirmed
