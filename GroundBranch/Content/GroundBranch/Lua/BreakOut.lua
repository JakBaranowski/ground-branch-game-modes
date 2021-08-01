local tables = require("Common.Tables")
local spawns = require("Common.Spawns")
local navStr = require("Navigation.Straight")
local navCom = require("Navigation.Common")
local navAdv = require("Navigation.Advanced")

--#region Properties

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
		OpForPreset = {
			Min = 0,
			Max = 4,
			Value = 2,
		},
		SpawnMethod = {
			Min = 0,
			Max = 2,
			Value = 2,
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
		WithLives = {}
	},
	OpFor = {
		Tag = "OpFor",
		PriorityTags = {
			"AISpawn_1", "AISpawn_2", "AISpawn_3", "AISpawn_4", "AISpawn_5",
			"AISpawn_6_10", "AISpawn_11_20", "AISpawn_21_30", "AISpawn_31_40",
			"AISpawn_41_50"
		},
		AllSpawnsByPriority = {},
		TotalSpawnsWithPriority = 0,
		AllSpawnsByGroup = {},
		TotalSpawnsWithGroup = 0,
		RoundSpawnList = {},
		CalculatedAiCount = 0,
	},
	Extraction = {
		AllPoints = {},
		ActivePoint = nil,
		AllMarkers = {},
		PlayersIn = 0,
		MaxDistanceForGroupConsideration = 25000,
	},
	Timers = {
		-- Count down timer with pause and reset
		Exfiltration = {
			Name = "ExfilTimer",
			DefaultTime = 5.0,
			CurrentTime = 5.0,
			TimeStep = 1.0,
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
		}
	}
}

--#endregion

--#region Preparation

function BreakOut:PreInit()
	print("Initializing Break Out")
	-- Gathers all OpFor spawn points by priority
	local priorityIndex = 1
	for _, priorityTag in ipairs(self.OpFor.PriorityTags) do
		local spawnsWithTag = gameplaystatics.GetAllActorsOfClassWithTag(
			'GroundBranch.GBAISpawnPoint',
			priorityTag
		)
		if #spawnsWithTag > 0 then
			self.OpFor.AllSpawnsByPriority[priorityIndex] = spawnsWithTag
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
			self.OpFor.AllSpawnsByGroup[groupIndex] = spawnsWithGroupTag
			self.OpFor.TotalSpawnsWithGroup =
				self.OpFor.TotalSpawnsWithGroup + #spawnsWithGroupTag
			groupIndex = groupIndex + 1
		end
	end
	print(
		"Found " .. #self.OpFor.AllSpawnsByGroup ..
		" groups and a total of " .. self.OpFor.TotalSpawnsWithGroup ..
		" spawns"
	)
	-- Failsafe for missions that don't have AI spawn points with group assigned
	if self.OpFor.TotalSpawnsWithGroup <= 0 then
		self.Settings.SpawnMethod.Min = 1
		if self.Settings.SpawnMethod.Value < self.Settings.SpawnMethod.Min then
			self.Settings.SpawnMethod.Value = 1
		end
	end
	-- Gathers all extraction points placed in the mission
	self.Extraction.AllPoints = gameplaystatics.GetAllActorsOfClass(
		'/Game/GroundBranch/Props/GameMode/BP_ExtractionPoint.BP_ExtractionPoint_C'
	)
	print("Found " .. #self.Extraction.AllPoints .. " extraction points")
end

function BreakOut:PostInit()
	-- Adds objective markers for all possible extraction points
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
	-- Add game objectives
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "ExfiltrateBluFor", 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "ExfiltrateAll", 2)
	print("Added game mode objectives")
end

--#endregion

--#region Common

function BreakOut:OnRoundStageSet(RoundStage)
	print("Started round stage " .. RoundStage)
	timer.ClearAll()
	if RoundStage == "WaitingForReady" then
		self:PreRoundCleanUp()
		self:ShuffleExtractionAndSetUpObjectiveMarkers()
	elseif RoundStage == "PreRoundWait" then
		self:SetUpOpForSpawns()
		self:SpawnOpFor()
	elseif RoundStage == "InProgress" then
		self.Players.WithLives = gamemode.GetPlayerListByLives(
			self.PlayerTeams.BluFor.TeamId,
			1,
			false
		)
	end
end

function BreakOut:OnCharacterDied(Character, CharacterController, KillerController)
	if gamemode.GetRoundStage() == "PreRoundWait" or
	gamemode.GetRoundStage() == "InProgress" then
		if CharacterController ~= nil then
			if actor.HasTag(CharacterController, self.OpFor.Tag) then
				print("OpFor eliminated")
			else
				print("BluFor eliminated")
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

--#endregion

--#region Player Status

function BreakOut:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	if InsertionPoint == nil then
		timer.Set(
			self.Timers.CheckReadyDown.Name,
			self,
			self.CheckReadyDownTimer,
			self.Timers.CheckReadyDown.TimeStep,
			false
		)
	else
		timer.Set(
			self.Timers.CheckReadyUp.Name,
			self,
			self.CheckReadyUpTimer,
			self.Timers.CheckReadyUp.TimeStep,
			false
		)
	end
end

function BreakOut:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	if ReadyStatus ~= "DeclaredReady" then
		timer.Set(
			self.Timers.CheckReadyDown.Name,
			self,
			self.CheckReadyDownTimer,
			self.Timers.CheckReadyDown.TimeStep,
			false
		)
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

--#region Objective markers

function BreakOut:ShuffleExtractionAndSetUpObjectiveMarkers()
	self.ExtractionPointIndex = math.random(#self.Extraction.AllPoints)
	self.Extraction.ActivePoint = self.Extraction.AllPoints[self.ExtractionPointIndex]
	for i = 1, #self.Extraction.AllPoints do
		local bActive = (i == self.ExtractionPointIndex)
		actor.SetActive(self.Extraction.AllPoints[i], bActive)
		actor.SetActive(self.Extraction.AllMarkers[i], bActive)
	end
end

--#endregion

--#region Spawns

function BreakOut:SetUpOpForSpawns()
	if self.Settings.SpawnMethod.Value == 1 then
		self:SetUpOpForSpawnsByPriorities()
	elseif self.Settings.SpawnMethod.Value == 2 then
		self:SetUpOpForSpawnsByPureRandomness()
	else
		self:SetUpOpForSpawnsByGroups()
	end
end

function BreakOut:SetUpOpForSpawnsByGroups()
	print("Setting up AI spawns by groups")
	local maxAiCount = math.min(
		self.OpFor.TotalSpawnsWithGroup,
		ai.GetMaxCount()
	)
	self.OpFor.CalculatedAiCount = spawns.GetAiCountWithDeviationPercent(
		5,
		maxAiCount,
		gamemode.GetPlayerCount(true),
		5,
		self.Settings.OpForPreset.Value,
		5,
		0.1
	)
	local remainingGroups =	{table.unpack(self.OpFor.AllSpawnsByGroup)}
	local selectedSpawns = {}
	local reserveSpawns = {}
	-- Select groups guarding extraction and add their spawn points to spawn list
	print("Adding group closest to exfil")
	local aiCountPerExfilGroup = spawns.GetAiCountWithDeviationNumber(
		3,
		10,
		gamemode.GetPlayerCount(true),
		1,
		self.Settings.OpForPreset.Value,
		1,
		0
	)
	local exfilLocation = actor.GetLocation(self.Extraction.ActivePoint)
	spawns.AddSpawnsFromClosestGroup(
		remainingGroups,
		selectedSpawns,
		reserveSpawns,
		aiCountPerExfilGroup,
		exfilLocation,
		self.Extraction.MaxDistanceForGroupConsideration
	)
	-- Select random group spawns along route
	
	print("Grabbing player starts")
	local insertionPoint = gameplaystatics.GetAllActorsOfClass(
		"GroundBranch.GBInsertionPoint"
	)[1]
	local insertionPointLocation = actor.GetLocation(insertionPoint)
	--DEBUG START
	local navStraight = navAdv:Create(
		insertionPointLocation,
		exfilLocation,
		250.0,
		0.75
	)
	local routeStraight = navStraight:PlotRoute(
		0.0,
		512
	)
	routeStraight = navCom.CleanRouteSimple(routeStraight, 64)
	local navLeft = navAdv:Create(
		insertionPointLocation,
		exfilLocation,
		250.0,
		0.75
	)
	local routeLeft = navLeft:PlotRoute(
		-80.0,
		512
	)
	routeLeft = navCom.CleanRouteSimple(routeLeft, 64)
	local navRight = navAdv:Create(
		insertionPointLocation,
		exfilLocation,
		250.0,
		0.75
	)
	local routeRight = navRight:PlotRoute(
		80.0,
		512
	)
	routeRight = navCom.CleanRouteSimple(routeRight, 64)
	local allPlayersList = gamemode.GetPlayerList(
		1,
		self.PlayerTeams.BluFor.TeamId,
		false,
		0,
		true
	)
	for i, point in ipairs(routeStraight) do
		player.ShowWorldPrompt(
			allPlayersList[1],
			point,
			"S_" .. i,
			600.0
		)
	end
	for i, point in ipairs(routeLeft) do
		player.ShowWorldPrompt(
			allPlayersList[1],
			point,
			"L_" .. i,
			600.0
		)
	end
	for i, point in ipairs(routeRight) do
		player.ShowWorldPrompt(
			allPlayersList[1],
			point,
			"R_" .. i,
			600.0
		)
	end
	--DEBUG END
	local straightRoute = navStr.GetStraightRoutePoints(
		insertionPointLocation,
		exfilLocation,
		10
	)
	local randomPoints = navCom.GetRandomPointsAlongRoute(
		straightRoute,
		10000,
		2
	)
	randomPoints = tables.ShuffleTable(randomPoints)
	for _, randomPoint in ipairs(randomPoints) do
		print("Adding AI closest to " .. tostring(randomPoint))
		local aiCountPerGroup = spawns.GetAiCountWithDeviationNumber(
			2,
			10,
			gamemode.GetPlayerCount(true),
			0.5,
			self.Settings.OpForPreset.Value,
			1,
			1
		)
		if #selectedSpawns + aiCountPerGroup > self.OpFor.CalculatedAiCount	then
			print("Remaining AI count is not enough to fill group")
			break
		end
		spawns.AddSpawnsFromClosestGroup(
			remainingGroups,
			selectedSpawns,
			reserveSpawns,
			aiCountPerGroup,
			randomPoint,
			5000.0
		)
	end
	--Select random spawns from remaining groups
	if #remainingGroups > 0 then
		print("Adding random spawns")
		local randomSpawns = tables.GetTableFromTables(
			remainingGroups
		)
		randomSpawns = tables.ShuffleTable(randomSpawns)
		selectedSpawns = tables.ConcatenateTables(selectedSpawns, randomSpawns)
	elseif #reserveSpawns > 0 then
		print("Adding random spawns from reserve")
		while #reserveSpawns > 0 do
			local randIndex = math.random(#reserveSpawns)
			table.insert(selectedSpawns, reserveSpawns[randIndex])
			table.remove(reserveSpawns, randIndex)
		end
	end
	self.OpFor.RoundSpawnList = selectedSpawns
end


function BreakOut:SetUpOpForSpawnsByPriorities()
	print("Setting up AI spawns by priority")
	local maxAiCount = math.min(
		self.OpFor.TotalSpawnsWithPriority,
		ai.GetMaxCount()
	)
	self.OpFor.CalculatedAiCount = spawns.GetAiCountWithDeviationPercent(
		5,
		maxAiCount,
		gamemode.GetPlayerCount(true),
		5,
		self.Settings.OpForPreset.Value,
		5,
		0.1
	)
	local tableWithShuffledSpawns = tables.ShuffleTables(
		self.OpFor.AllSpawnsByPriority
	)
	self.OpFor.RoundSpawnList = tables.GetTableFromTables(
		tableWithShuffledSpawns
	)
end

function BreakOut:SetUpOpForSpawnsByPureRandomness()
	print("Setting up AI spawns by pure randomness")
	local maxAiCount = math.min(
		self.OpFor.TotalSpawnsWithPriority,
		ai.GetMaxCount()
	)
	self.OpFor.CalculatedAiCount = spawns.GetAiCountWithDeviationPercent(
		5,
		maxAiCount,
		gamemode.GetPlayerCount(true),
		5,
		self.Settings.OpForPreset.Value,
		5,
		0.1
	)
	self.OpFor.RoundSpawnList = tables.GetTableFromTables(
		self.OpFor.AllSpawnsByPriority
	)
	self.OpFor.RoundSpawnList = tables.ShuffleTable(self.OpFor.RoundSpawnList)
end

function BreakOut:SpawnOpFor()
	ai.CreateOverDuration(
		4.0,
		self.OpFor.CalculatedAiCount,
		self.OpFor.RoundSpawnList,
		self.OpFor.Tag
	)
	print("Spawned " .. self.OpFor.CalculatedAiCount .. " AI")
end

--#endregion

--#region Objective: Extraction

function BreakOut:OnGameTriggerBeginOverlap(GameTrigger, Player)
	local playerCharacter = player.GetCharacter(Player)
	if playerCharacter ~= nil then
		local teamId = actor.GetTeamId(playerCharacter)
		if teamId == self.PlayerTeams.BluFor.TeamId and
		GameTrigger == self.Extraction.ActivePoint then
			self:PlayerEnteredExfiltration()
		end
	end
end

function BreakOut:PlayerEnteredExfiltration()
	local total = math.min(self.Extraction.PlayersIn + 1, #self.Players.WithLives)
	self.Extraction.PlayersIn = total
	self:CheckBluForExfilTimer()
end

function BreakOut:OnGameTriggerEndOverlap(GameTrigger, Player)
	local playerCharacter = player.GetCharacter(Player)
	if playerCharacter ~= nil then
		local teamId = actor.GetTeamId(playerCharacter)
		if teamId == self.PlayerTeams.BluFor.TeamId and
		GameTrigger == self.Extraction.ActivePoint then
			self:PlayerLeftExfiltration()
		end
	end
end

function BreakOut:PlayerLeftExfiltration()
	local total = math.max(self.Extraction.PlayersIn - 1, 0)
	self.Extraction.PlayersIn = total
end

function BreakOut:CheckBluForExfilTimer()
	if self.Timers.Exfiltration.CurrentTime <= 0 then
		self:Exfiltrate()
		timer.Clear(self, self.Timers.Exfiltration.Name)
		self.Timers.Exfiltration.CurrentTime = self.Timers.Exfiltration.DefaultTime
		return
	end
	if self.Extraction.PlayersIn <= 0 then
		for _, playerInstance in ipairs(self.Players.WithLives) do
			player.ShowGameMessage(
				playerInstance,
				"ExfilCancelled",
				"Upper",
				self.Timers.Exfiltration.TimeStep*2
			)
		end
		self.Timers.Exfiltration.CurrentTime = self.Timers.Exfiltration.DefaultTime
		return
	elseif self.Extraction.PlayersIn < #self.Players.WithLives then
		for _, playerInstance in ipairs(self.Players.WithLives) do
			player.ShowGameMessage(
				playerInstance,
				"ExfilPaused",
				"Upper",
				self.Timers.Exfiltration.TimeStep-0.05
			)
		end
	else
		for _, playerInstance in ipairs(self.Players.WithLives) do
			player.ShowGameMessage(
				playerInstance,
				"ExfilInProgress_"..math.floor(self.Timers.Exfiltration.CurrentTime),
				"Upper",
				self.Timers.Exfiltration.TimeStep-0.05
			)
		end
		self.Timers.Exfiltration.CurrentTime =
			self.Timers.Exfiltration.CurrentTime -
			self.Timers.Exfiltration.TimeStep
	end
	timer.Set(
		self.Timers.Exfiltration.Name,
		self,
		self.CheckBluForExfilTimer,
		self.Timers.Exfiltration.TimeStep,
		false
	)
end

function BreakOut:Exfiltrate()
	if gamemode.GetRoundStage() ~= "InProgress" then
		return
	end
	gamemode.AddGameStat("Result=Team1")
	if #self.Players.WithLives >= gamemode.GetPlayerCount(true) then
		gamemode.AddGameStat("CompleteObjectives=ExfiltrateBluFor,ExfiltrateAll")
		gamemode.AddGameStat("Summary=BluForExfilSuccess")
	else
		gamemode.AddGameStat("CompleteObjectives=ExfiltrateBluFor")
		gamemode.AddGameStat("Summary=BluForExfilPartialSuccess")
	end
	gamemode.SetRoundStage("PostRoundWait")
end

--#endregion

--#region Fail condition

function BreakOut:CheckBluForCountTimer()
	if gamemode.GetRoundStage() ~= "InProgress" then
		return
	end
	if #self.Players.WithLives == 0 then
		timer.Clear(self, "CheckBluForExfil")
		gamemode.AddGameStat("Result=None")
		gamemode.AddGameStat("Summary=BluForEliminated")
		gamemode.SetRoundStage("PostRoundWait")
	end
end

--#endregion

--region Helpers

function BreakOut:PreRoundCleanUp()
	self.OpFor.RoundSpawnList = {}
	self.Players.WithLives = {}
	self.Extraction.PlayersIn = 0
	self.Extraction.ActivePoint = nil
	ai.CleanUp(self.OpFor.Tag)
end

--#endregion

return BreakOut
