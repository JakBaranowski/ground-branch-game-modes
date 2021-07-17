local TabOps = require("common.TableOperations")
local StrOps = require("common.StringOperations")
local Spawns = require("common.Spawns")

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
		HVTCount = {
			Min = 1,
			Max = 5,
			Value = 1,
		},
		OpForPreset = {
			Min = 0,
			Max = 4,
			Value = 2,
		},
		SpawnMethod = {
			Min = 0,
			Max = 2,
			Value = 0,
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
	SettingTrackers = {
		LastHVTCount = 0,
	},
	Players = {
		WithLives = {},
	},
	OpFor = {
		Tag = "OpFor",
		PriorityTags = {
			"AISpawn_1", "AISpawn_2", "AISpawn_3", "AISpawn_4", "AISpawn_5",
			"AISpawn_6_10", "AISpawn_11_20", "AISpawn_21_30", "AISpawn_31_40",
			"AISpawn_41_50"
		},
		SpawnsByPriority = {},
		TotalSpawnsWithPriority = 0,
		SpawnsByGroup = {},
		TotalSpawnsWithGroup = 0,
		RoundSpawnList = {},
		CalculatedAiCount = 0,
	},
	HVT = {
		Tag = "HVT",
		Spawns = {},
		SpawnsShuffled = {},
		SpawnMarkers = {},
		EliminatedNotConfirmed = {},
		EliminatedAndConfirmed = 0,
		MaxDistanceForGroupConsideration = 20 * 100.0,
	},
	Extraction = {
		AllPoints = {},
		ActivePoint = nil,
		AllMarkers = {},
		PlayersIn = 0,
	},
	UI = {
		WorldPromptShowTime = 5.0,
		WorldPromptDelay = 15.0,
		PlayerShowGameMessageTime = 5.0
	},
	Timers = {
		-- Count down timer with pause and reset
		Exfiltration = {
			Name = "ExfilTimer",
			DefaultTime = 4.0,
			CurrentTime = 4.0,
			TimeStep = 1.0,
		},
		-- Repeating timer with variable delay
		KillConfirm = {
			Name = "KillConfirmTimer",
			TimeStep = {
				Max = 1.0,
				Min = 0.1,
				Value = 1.0,
			},
		},
		-- Repeating timers with constant delay
		SettingsChanged = {
			Name = "SettingsChanged",
			TimeStep = 1.0,
		},
		GuideToObjective = {
			Name = "GuideToObjective",
		},
		-- Delays
		CheckBluForCount = {
			Name = "CheckBluForCount",
			TimeStep = 1.0,
		},
		CheckReadyUp = {
			Name = "CheckReadyUp",
			TimeStep = 0.25,
		},
		CheckReadyDown = {
			Name = "CheckReadyDown",
			TimeStep = 0.1,
		},
		SpawnOpFor = {
			Name = "SpawnOpFor",
			TimeStep = 0.5,
		},
	},
}

--#endregion

--#region Preparation

function KillConfirmed:PreInit()
	print("Initializing Kill Confirmed")
	-- Gathers all OpFor spawn points by priority
	local priorityIndex = 1
	for _, priorityTag in ipairs(self.OpFor.PriorityTags) do
		local spawnsWithTag = gameplaystatics.GetAllActorsOfClassWithTag(
			'GroundBranch.GBAISpawnPoint',
			priorityTag
		)
		if #spawnsWithTag > 0 then
			self.OpFor.SpawnsByPriority[priorityIndex] = spawnsWithTag
			self.OpFor.TotalSpawnsWithPriority =
				self.OpFor.TotalSpawnsWithPriority + #spawnsWithTag
			priorityIndex = priorityIndex + 1
		end
	end
	print(
		"Found " .. self.OpFor.TotalSpawnsWithPriority ..
		" spawns by priority"
	)
	-- Gathers all OpFor spawn points by groups
	local groupIndex = 1
	for i = 1, 32, 1 do
		local groupTag = "Group" .. tostring(i)
		local spawnsWithGroupTag = gameplaystatics.GetAllActorsOfClassWithTag(
			'GroundBranch.GBAISpawnPoint',
			groupTag
		)
		if #spawnsWithGroupTag > 0 then
			self.OpFor.SpawnsByGroup[groupIndex] = spawnsWithGroupTag
			self.OpFor.TotalSpawnsWithGroup =
				self.OpFor.TotalSpawnsWithGroup + #spawnsWithGroupTag
			groupIndex = groupIndex + 1
		end
	end
	print(
		"Found " .. #self.OpFor.SpawnsByGroup ..
		" groups and a total of " .. self.OpFor.TotalSpawnsWithGroup ..
		" spawns"
	)
	-- Gathers all HVT spawn points
	self.HVT.Spawns = gameplaystatics.GetAllActorsOfClassWithTag(
		'GroundBranch.GBAISpawnPoint',
		self.HVT.Tag
	)
	print("Found " .. #self.HVT.Spawns .. " HVT spawns")
	-- Gathers all extraction points placed in the mission
	self.Extraction.AllPoints = gameplaystatics.GetAllActorsOfClass(
		'/Game/GroundBranch/Props/GameMode/BP_ExtractionPoint.BP_ExtractionPoint_C'
	)
	print("Found " .. #self.Extraction.AllPoints .. " extraction points")
	-- Set maximum HVT count and ensure that HVT value is within limit
	self.Settings.HVTCount.Max = math.min(ai.GetMaxCount(), #self.HVT.Spawns)
	self.Settings.HVTCount.Value = math.min(
		self.Settings.HVTCount.Value,
		self.Settings.HVTCount.Max
	)
	-- Set last HVT count for tracking if the setting has changed.
	-- This is neccessary for adding objective markers on map.
	self.SettingTrackers.LastHVTCount = self.Settings.HVTCount.Value
end

function KillConfirmed:PostInit()
	-- Add inactive objective markers to all possible HVT spawn points.
	for _, SpawnPoint in ipairs(self.HVT.Spawns) do
		local description = "HVT"
		description = StrOps.GetSuffixFromActorTag(SpawnPoint, "ObjectiveMarker")
		self.HVT.SpawnMarkers[description] = gamemode.AddObjectiveMarker(
			actor.GetLocation(SpawnPoint),
			self.PlayerTeams.BluFor.TeamId,
			description,
			false
		)
	end
	print("Added objective markers for HVTs")
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
	print("Added objective markers for extraction points")
	-- Add game mode objectives
	gamemode.AddGameObjective(
		self.PlayerTeams.BluFor.TeamId,
		"NeutralizeHVTs",
		1
	)
	gamemode.AddGameObjective(
		self.PlayerTeams.BluFor.TeamId,
		"ConfirmEliminatedHVTs",
		1
	)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "ExfiltrateBluFor", 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "LastKnownLocation", 2)
	print("Added game mode objectives")
end

--#endregion

--#region Common

function KillConfirmed:OnRoundStageSet(RoundStage)
	print("Started round stage " .. RoundStage)
	-- On every round stage change clear all timers.
	timer.ClearAll()
	if RoundStage == "WaitingForReady" then
		-- At this stage players have been assigned to teams.
		self:PreRoundCleanUp()
		self:SetUpOpForHvtSpawns()
		self:ShuffleExtractionAndSetUpObjectiveMarkers()
		self:SetUpHvtObjectiveMarkers()
		timer.Set(
			self.Timers.SettingsChanged.Name,
			self,
			self.CheckIfSettingsChanged,
			self.Timers.SettingsChanged.TimeStep,
			true
		)
	elseif RoundStage == "PreRoundWait" then
		-- At this stage players are already spawned in AO, but still frozen.
		self:SetUpOpForStandardSpawns()
		self:SpawnOpFor()
	elseif RoundStage == "InProgress" then
		-- At this stage players become unfrozen, and the round is properly started.
		self.Players.WithLives = gamemode.GetPlayerListByLives(
			self.PlayerTeams.BluFor.TeamId,
			1,
			false
		)
		timer.Set(
			self.Timers.GuideToObjective.Name,
			self,
			self.GuideToEliminatedLeaderTimer,
			self.UI.WorldPromptDelay,
			true
		)
	elseif RoundStage == "PostRoundWait" then
		-- The round have ended, either with victory or loss. Players will be moved
		-- to ready room soon.
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
				-- OpFor HVT eliminated.
				print("OpFor HVT eliminated")
				self:ShowHvtEliminated()
				table.insert(
					self.HVT.EliminatedNotConfirmed,
					actor.GetLocation(Character)
				)
				timer.Set(
					self.Timers.KillConfirm.Name,
					self,
					self.CheckIfKillConfirmedTimer,
					self.Timers.KillConfirm.TimeStep.Min,
					false
				)
			elseif actor.HasTag(CharacterController, self.OpFor.Tag) then
				print("OpFor standard eliminated")
				-- OpFor standard eliminated.
			else
				print("BluFor eliminated")
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
					self.Timers.CheckBluForCount.Name,
					self,
					self.CheckBluForCountTimer,
					self.Timers.CheckBluForCount.TimeStep,
					false
				)
			end
		end
	end
end

function KillConfirmed:LogOut(Exiting)
	-- Player lef the game.
	print("Player left the game")
	if gamemode.GetRoundStage() == "PreRoundWait" or
	gamemode.GetRoundStage() == "InProgress" then
		timer.Set(
			self.Timers.CheckBluForCount.Name,
			self,
			self.CheckBluForCountTimer,
			self.Timers.CheckBluForCount.TimeStep,
			false
		)
	end
end

--#endregion

--#region Player Status

function KillConfirmed:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	if InsertionPoint == nil then
		-- Player unchecked insertion point.
		timer.Set(
			self.Timers.CheckReadyDown.Name,
			self,
			self.CheckReadyDownTimer,
			self.Timers.CheckReadyDown.TimeStep,
			false
		)
	else
		-- Player checked insertion point.
		timer.Set(
			self.Timers.CheckReadyUp.Name,
			self,
			self.CheckReadyUpTimer,
			self.Timers.CheckReadyUp.TimeStep,
			false
		)
	end
end

function KillConfirmed:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	if ReadyStatus ~= "DeclaredReady" then
		-- Player declared ready.
		timer.Set(
			self.Timers.CheckReadyDown.Name,
			self,
			self.CheckReadyDownTimer,
			self.Timers.CheckReadyDown.TimeStep,
			false
		)
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

function KillConfirmed:SetUpHvtObjectiveMarkers()
	print("Setting up HVT objective markers " .. #self.HVT.SpawnsShuffled)
	for i, v in ipairs(self.HVT.SpawnsShuffled) do
		local spawnTag = StrOps.GetSuffixFromActorTag(v, "ObjectiveMarker")
		local bActive = i <= self.Settings.HVTCount.Value
		print("Setting HVT marker " .. spawnTag .. " to " .. tostring(bActive))
		actor.SetActive(self.HVT.SpawnMarkers[spawnTag], bActive)
	end
end

function KillConfirmed:ShuffleExtractionAndSetUpObjectiveMarkers()
	print("Setting up Extraction objective markers")
	self.ExtractionPointIndex = math.random(#self.Extraction.AllPoints)
	self.Extraction.ActivePoint = self.Extraction.AllPoints[self.ExtractionPointIndex]
	for i = 1, #self.Extraction.AllPoints do
		local bActive = (i == self.ExtractionPointIndex)
		print("Setting Exfil marker " .. i .. " to " .. tostring(bActive))
		actor.SetActive(self.Extraction.AllPoints[i], bActive)
		actor.SetActive(self.Extraction.AllMarkers[i], bActive)
	end
end

--#endregion

--#region Ai

function KillConfirmed:SetUpOpForHvtSpawns()
	self.HVT.SpawnsShuffled = {}
	self.HVT.SpawnsShuffled = TabOps.ShuffleTable(
		self.HVT.Spawns
	)
	print("Shuffled HVT spawns")
end

function KillConfirmed:SetUpOpForStandardSpawns()
	local maxAiCount = math.min(
		self.OpFor.TotalSpawnsWithGroup,
		ai.GetMaxCount() - self.Settings.HVTCount.Value
	)
	self.OpFor.CalculatedAiCount = Spawns.CalculateAiCount(
		5,
		maxAiCount,
		gamemode.GetPlayerCount(true),
		5,
		self.Settings.OpForPreset.Value,
		5,
		0.1
	)
	if self.Settings.SpawnMethod.Value == 0 then
		self:SetUpOpForSpawnsByGroups()
	elseif self.Settings.SpawnMethod.Value == 1 then
		self:SetUpOpForSpawnsByPriorities()
	elseif self.Settings.SpawnMethod.Value == 2 then
		self:SetUpOpForSpawnsByPureRandomness()
	else
		print("Unknown spawn method selected, using default.")
		self:SetUpOpForSpawnsByGroups()
	end
end

function KillConfirmed:SetUpOpForSpawnsByGroups()
	print("Shuffling AI spawn points by groups")
	local remainingGroups =	{table.unpack(self.OpFor.SpawnsByGroup)}
	local selectedSpawns = {}
	local reserveSpawns = {}
	local missingAiCount = self.OpFor.CalculatedAiCount
	-- Select groups guarding the HVTs and add their spawn points to spawn list
	local aiCountPerHvtGroup = Spawns.CalculateBaseAiCountPerGroup(
		2,
		gamemode.GetPlayerCount(true),
		2,
		self.Settings.OpForPreset.Value,
		2
	)
	local maxAiCountPerHvtGroup = math.floor(
		missingAiCount / self.Settings.HVTCount.Value
	)
	aiCountPerHvtGroup = math.min(aiCountPerHvtGroup, maxAiCountPerHvtGroup)
	print("Adding group spawns closest to HVTs")
	for i = 1, self.Settings.HVTCount.Value do
		local hvtLocation = actor.GetLocation(self.HVT.SpawnsShuffled[i])
		Spawns.AddSpawnsFromClosestGroupWithinDistance(
			remainingGroups,
			selectedSpawns,
			reserveSpawns,
			aiCountPerHvtGroup,
			hvtLocation,
			self.HVT.MaxDistanceForGroupConsideration
		)
		missingAiCount = self.OpFor.CalculatedAiCount - #selectedSpawns
	end
	-- Select random groups and add their spawn points to spawn list
	local baseAiCountPerStandardGroup = Spawns.CalculateBaseAiCountPerGroup(
		2,
		gamemode.GetPlayerCount(true),
		1,
		self.Settings.OpForPreset.Value,
		1
	)
	local minAiCountPerStandardGroup = math.max(2, baseAiCountPerStandardGroup / 2)
	print("Adding random group spawns")
	while missingAiCount > 0 do
		if #reserveSpawns >= missingAiCount and
		minAiCountPerStandardGroup > missingAiCount then
			print("Remaining AI count is not enough to fill group")
			break
		end
		local aiCountPerStandardGroup =
			baseAiCountPerStandardGroup + math.random(-1,1)
		Spawns.AddSpawnsFromRandomGroup(
			remainingGroups,
			selectedSpawns,
			reserveSpawns,
			aiCountPerStandardGroup
		)
		missingAiCount = self.OpFor.CalculatedAiCount - #selectedSpawns
	end
	-- Select random spawns from reserve
	print("Adding random spawns from reserve")
	while missingAiCount > 0 and #reserveSpawns > 0 do
		local randIndex = math.random(#reserveSpawns)
		table.insert(selectedSpawns, reserveSpawns[randIndex])
		table.remove(reserveSpawns, randIndex)
		missingAiCount = self.OpFor.CalculatedAiCount - #selectedSpawns
	end
	self.OpFor.RoundSpawnList = selectedSpawns
end

function KillConfirmed:SetUpOpForSpawnsByPriorities()
	print("Setting up AI spawns by priority")
	local tableWithShuffledSpawns = TabOps.ShuffleTables(
		self.OpFor.SpawnsByPriority
	)
	self.OpFor.RoundSpawnList = TabOps.GetTableFromTables(
		tableWithShuffledSpawns
	)
end

function KillConfirmed:SetUpOpForSpawnsByPureRandomness()
	print("Setting up AI spawns by pure randomness")
	self.OpFor.RoundSpawnList = TabOps.GetTableFromTables(
		self.OpFor.SpawnsByPriority
	)
	self.OpFor.RoundSpawnList = TabOps.ShuffleTable(self.OpFor.RoundSpawnList)
end

function KillConfirmed:SpawnOpFor()
	ai.CreateOverDuration(
		self.Timers.SpawnOpFor.TimeStep - 0.1,
		self.Settings.HVTCount.Value,
		self.HVT.SpawnsShuffled,
		self.HVT.Tag
	)
	print("Spawned " .. self.Settings.HVTCount.Value .. " OpFor HVT.")
	timer.Set(
		self.Timers.SpawnOpFor.Name,
		self,
		self.SpawnStandardOpForTimer,
		self.Timers.SpawnOpFor.TimeStep,
		false
	)
end

function KillConfirmed:SpawnStandardOpForTimer()
	ai.CreateOverDuration(
		4.0 - self.Timers.SpawnOpFor.TimeStep,
		self.OpFor.CalculatedAiCount,
		self.OpFor.RoundSpawnList,
		self.OpFor.Tag
	)
	print("Spawned " .. self.OpFor.CalculatedAiCount .. " OpFor standard.")
end

--#endregion

--#region Game Messages and World Prompts

function KillConfirmed:ShowHvtEliminated()
	for _, playerInstance in ipairs(self.Players.WithLives) do
		player.ShowGameMessage(
			playerInstance,
			"HVTEliminated",
			"Upper",
			self.UI.PlayerShowGameMessageTime
		)
	end
end

function KillConfirmed:ShowKillConfirmed()
	for _, playerInstance in ipairs(self.Players.WithLives) do
		player.ShowGameMessage(
			playerInstance,
			"HVTConfirmed",
			"Upper",
			self.UI.PlayerShowGameMessageTime
		)
	end
end

function KillConfirmed:ShowAllKillConfirmed()
	for _, playerInstance in ipairs(self.Players.WithLives) do
		player.ShowGameMessage(
			playerInstance,
			"HVTConfirmedAll",
			"Upper",
			self.UI.PlayerShowGameMessageTime
		)
	end
end

function KillConfirmed:GuideToExtractionTimer()
	local ExtractionLocation = actor.GetLocation(self.Extraction.ActivePoint)
	for _, playerInstance in ipairs(self.Players.WithLives) do
		player.ShowWorldPrompt(
			playerInstance,
			ExtractionLocation,
			"Extraction",
			self.UI.WorldPromptShowTime
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
				self.UI.WorldPromptShowTime
			)
		end
	end
end

--#endregion

--#region Objective: Kill confirmed

function KillConfirmed:CheckIfKillConfirmedTimer()
	local LowestDist = self.Timers.KillConfirm.TimeStep.Max * 1000.0
	for index, LeaderLocation in ipairs(self.HVT.EliminatedNotConfirmed) do
		for _, PlayerController in ipairs(self.Players.WithLives) do
			local PlayerLocation = actor.GetLocation(
				player.GetCharacter(PlayerController)
			)
			local DistVector = PlayerLocation - LeaderLocation
			local Dist = vector.Size(DistVector)
			LowestDist = math.min(LowestDist, Dist)
			if Dist <= 250 and math.abs(DistVector.z) < 110 then
				self:ConfirmKill(index)
			end
		end
	end
	if #self.HVT.EliminatedNotConfirmed > 0 then
		self.Timers.KillConfirm.TimeStep.Value = math.max(
			math.min(
				LowestDist/1000,
				self.Timers.KillConfirm.TimeStep.Max
			),
			self.Timers.KillConfirm.TimeStep.Min
		)
		timer.Set(
			self.Timers.KillConfirm.Name,
			self,
			self.CheckIfKillConfirmedTimer,
			self.Timers.KillConfirm.TimeStep.Value,
			false
		)
	end
end

function KillConfirmed:ConfirmKill(index)
	self.HVT.EliminatedAndConfirmed = self.HVT.EliminatedAndConfirmed + 1
	table.remove(self.HVT.EliminatedNotConfirmed, index)
	if self.HVT.EliminatedAndConfirmed >= self.Settings.HVTCount.Value then
		print("All HVT kills confirmed")
		self:ShowAllKillConfirmed()
		timer.Set(
			self.Timers.GuideToObjective.Name,
			self,
			self.GuideToExtractionTimer,
			self.UI.WorldPromptDelay,
			true
		)
		if self.Extraction.PlayersIn > 0 then
			timer.Set(
				self.Timers.Exfiltration.Name,
				self,
				self.CheckBluForExfilTimer,
				0.1,
				false
			)
		end
	else
		print("HVT kill confirmed")
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
			self:PlayerEnteredExfiltration()
		end
	end
end

function KillConfirmed:PlayerEnteredExfiltration()
	local total = math.min(self.Extraction.PlayersIn + 1, #self.Players.WithLives)
	self.Extraction.PlayersIn = total
	if self.HVT.EliminatedAndConfirmed >= self.Settings.HVTCount.Value then
		timer.Set(
			self.Timers.Exfiltration.Name,
			self,
			self.CheckBluForExfilTimer,
			0.1,
			false
		)
	end
end

function KillConfirmed:OnGameTriggerEndOverlap(GameTrigger, Player)
	local playerCharacter = player.GetCharacter(Player)
	if playerCharacter ~= nil then
		local teamId = actor.GetTeamId(playerCharacter)
		if teamId == self.PlayerTeams.BluFor.TeamId and
		GameTrigger == self.Extraction.ActivePoint then
			self:PlayerLeftExfiltration()
		end
	end
end

function KillConfirmed:PlayerLeftExfiltration()
	local total = math.max(self.Extraction.PlayersIn - 1, 0)
	self.Extraction.PlayersIn = total
end

function KillConfirmed:CheckBluForExfilTimer()
	if self.Extraction.PlayersIn >= #self.Players.WithLives then
		self.Timers.Exfiltration.CurrentTime =
			self.Timers.Exfiltration.CurrentTime -
			self.Timers.Exfiltration.TimeStep
		for _, playerInstance in ipairs(self.Players.WithLives) do
			player.ShowGameMessage(
				playerInstance,
				"ExfilInProgress_"..math.floor(self.Timers.Exfiltration.CurrentTime),
				"Upper",
				self.Timers.Exfiltration.TimeStep-0.1
			)
		end
	elseif self.Extraction.PlayersIn > 0 then
		for _, playerInstance in ipairs(self.Players.WithLives) do
			player.ShowGameMessage(
				playerInstance,
				"ExfilPaused",
				"Upper",
				self.Timers.Exfiltration.TimeStep
			)
		end
	else
		self.Timers.Exfiltration.CurrentTime = self.Timers.Exfiltration.DefaultTime
		for _, playerInstance in ipairs(self.Players.WithLives) do
			player.ShowGameMessage(
				playerInstance,
				"ExfilCancelled",
				"Upper",
				self.Timers.Exfiltration.TimeStep*2
			)
		end
		timer.Clear(self, self.Timers.Exfiltration.Name)
		return
	end
	if self.Timers.Exfiltration.CurrentTime > 0 then
		timer.Set(
			self.Timers.Exfiltration.Name,
			self,
			self.CheckBluForExfilTimer,
			self.Timers.Exfiltration.TimeStep,
			false
		)
	else
		self:Exfiltrate()
		timer.Clear(self, self.Timers.Exfiltration.Name)
		self.Timers.Exfiltration.CurrentTime = self.Timers.Exfiltration.DefaultTime
	end
end

function KillConfirmed:Exfiltrate()
	if gamemode.GetRoundStage() ~= "InProgress" then
		return
	end
	gamemode.AddGameStat("Result=Team1")
	gamemode.AddGameStat("Summary=HVTsConfirmed")
	gamemode.AddGameStat(
		"CompleteObjectives=NeutralizeHVTs,ConfirmEliminatedHVTs," ..
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
				"CompleteObjectives=NeutralizeHVTs,LastKnownLocation"
			)
		elseif self.HVT.EliminatedAndConfirmed >=
		self.Settings.HVTCount.Value then
			gamemode.AddGameStat("Summary=BluForExfilFailed")
			gamemode.AddGameStat(
				"CompleteObjectives=NeutralizeHVTs," ..
				"ConfirmEliminatedHVTs,LastKnownLocation"
			)
		else
			gamemode.AddGameStat("Summary=BluForEliminated")
		end
		gamemode.SetRoundStage("PostRoundWait")
	end
end

--#endregion

--#region Helpers

function KillConfirmed:PreRoundCleanUp()
	ai.CleanUp(self.HVT.Tag)
	ai.CleanUp(self.OpFor.Tag)
	self.Players.WithLives = {}
	self.HVT.EliminatedNotConfirmed = {}
	self.HVT.EliminatedAndConfirmed = 0
	self.Extraction.PlayersIn = 0
end

function KillConfirmed:CheckIfSettingsChanged()
	if self.SettingTrackers.LastHVTCount ~= self.Settings.HVTCount.Value then
		print("Leader count changed, reshuffling spawns & updating objective markers.")
		self:SetUpOpForHvtSpawns()
		self:SetUpHvtObjectiveMarkers()
		self.SettingTrackers.LastHVTCount = self.Settings.HVTCount.Value
	end
end

--#endregion

return KillConfirmed
