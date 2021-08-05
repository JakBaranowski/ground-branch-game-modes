local Groups = require('Spawns.Groups')
local Spawns = require('Spawns.Common')
local Exfiltration = require('Objectives.Exfiltration')
local KillConfirmation = require('Objectives.KillConfirmation')
local GameMessageBroker = require('UI.GameMessageBroker')
local WorldPromptBroker = require('UI.WorldPromptBroker')

--#region Properties

local KillConfirmed = {
	UseReadyRoom = true,
	UseRounds = true,
	StringTables = {'KillConfirmed'},
	PlayerTeams = {
		BluFor = {
			TeamId = 1,
			Loadout = 'NoTeam',
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
		Tag = 'OpFor',
		CalculatedAiCount = 0,
	},
	HVT = {
		Tag = 'HVT',
	},
	Timers = {
		-- Repeating timers with constant delay
		SettingsChanged = {
			Name = 'SettingsChanged',
			TimeStep = 1.0,
		},
		-- Delays
		CheckBluForCount = {
			Name = 'CheckBluForCount',
			TimeStep = 1.0,
		},
		CheckReadyUp = {
			Name = 'CheckReadyUp',
			TimeStep = 0.25,
		},
		CheckReadyDown = {
			Name = 'CheckReadyDown',
			TimeStep = 0.1,
		},
		SpawnOpFor = {
			Name = 'SpawnOpFor',
			TimeStep = 0.5,
		},
		CheckSpawnedAi = {
			Name = 'CheckeSpawnedAi',
			TimeStep = 4.1
		}
	}
}

--#endregion

--#region Spawns

local SpawnsOpForGroups
local ObjectiveExfil
local ObjectiveKillConfirmed
local MessagesObjective
local PromptsObjective

--#endregion

--#region Preparation

function KillConfirmed:PreInit()
	print('Initializing Kill Confirmed')
	-- Setting up message broker
	MessagesObjective = GameMessageBroker:Create(self.Players.WithLives, 'Upper')
	PromptsObjective = WorldPromptBroker:Create(self.Players.WithLives)
	-- Gathers all OpFor spawn points by groups
	SpawnsOpForGroups = Groups:Create()
	-- Gathers all HVT spawn points
	ObjectiveKillConfirmed = KillConfirmation:Create(
		MessagesObjective,
		PromptsObjective,
		self,
		self.OnAllKillsConfirmed,
		self.Players.WithLives,
		self.HVT.Tag,
		self.PlayerTeams.BluFor.TeamId,
		self.Settings.HVTCount.Value
	)
	-- Gathers all extraction points placed in the mission
	ObjectiveExfil = Exfiltration:Create(
		MessagesObjective,
		PromptsObjective,
		self,
		self.OnExfiltrated,
		self.PlayerTeams.BluFor.TeamId,
		#self.Players.WithLives,
		5.0,
		1.0
	)
	-- Set maximum HVT count and ensure that HVT value is within limit
	self.Settings.HVTCount.Max = math.min(ai.GetMaxCount(), ObjectiveKillConfirmed:GetSpawnsCount())
	self.Settings.HVTCount.Value = math.min(
		self.Settings.HVTCount.Value,
		self.Settings.HVTCount.Max
	)
	-- Set last HVT count for tracking if the setting has changed.
	-- This is neccessary for adding objective markers on map.
	self.SettingTrackers.LastHVTCount = self.Settings.HVTCount.Value
end

function KillConfirmed:PostInit()
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'NeutralizeHVTs', 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'ConfirmEliminatedHVTs', 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'LastKnownLocation', 2)
    print('Added Kill Confirmation objectives')
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'ExfiltrateBluFor', 1)
	print('Added exfiltration objective')
end

--#endregion

--#region Common

function KillConfirmed:OnRoundStageSet(RoundStage)
	print('Started round stage ' .. RoundStage)
	timer.ClearAll()
	if RoundStage == 'WaitingForReady' then
		self:PreRoundCleanUp()
		ObjectiveExfil:SelectPoint(false)
		ObjectiveKillConfirmed:ShuffleSpawns()
		timer.Set(
			self.Timers.SettingsChanged.Name,
			self,
			self.CheckIfSettingsChanged,
			self.Timers.SettingsChanged.TimeStep,
			true
		)
	elseif RoundStage == 'PreRoundWait' then
		self:SetUpOpForStandardSpawns()
		self:SpawnOpFor()
	elseif RoundStage == 'InProgress' then
		self.Players.WithLives = gamemode.GetPlayerListByLives(
			self.PlayerTeams.BluFor.TeamId,
			1,
			false
		)
		MessagesObjective:SetRecipients(self.Players.WithLives)
		PromptsObjective:SetRecipients(self.Players.WithLives)
		ObjectiveKillConfirmed:SetPlayersWithLives(self.Players.WithLives)
		ObjectiveExfil:SetPlayersRequiredForExfil(#self.Players.WithLives)
	end
end

function KillConfirmed:OnCharacterDied(Character, CharacterController, KillerController)
	if
		gamemode.GetRoundStage() == 'PreRoundWait' or
		gamemode.GetRoundStage() == 'InProgress'
	then
		if CharacterController ~= nil then
			if actor.HasTag(CharacterController, self.HVT.Tag) then
				ObjectiveKillConfirmed:Neutralized(Character)
			elseif actor.HasTag(CharacterController, self.OpFor.Tag) then
				print('OpFor standard eliminated')
			else
				print('BluFor eliminated')
				player.SetLives(
					CharacterController,
					player.GetLives(CharacterController) - 1
				)
				self.Players.WithLives = gamemode.GetPlayerListByLives(
					self.PlayerTeams.BluFor.TeamId,
					1,
					false
				)
				MessagesObjective:SetRecipients(self.Players.WithLives)
				PromptsObjective:SetRecipients(self.Players.WithLives)
				ObjectiveExfil:SetPlayersRequiredForExfil(#self.Players.WithLives)
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
		timer.Set(self.Timers.CheckReadyUp.Name,
			self,
			self.CheckReadyUpTimer,
			self.Timers.CheckReadyUp.TimeStep,
			false
		)
	end
end

function KillConfirmed:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	if ReadyStatus ~= 'DeclaredReady' then
		-- Player declared ready.
		timer.Set(
			self.Timers.CheckReadyDown.Name,
			self,
			self.CheckReadyDownTimer,
			self.Timers.CheckReadyDown.TimeStep,
			false
		)
	elseif
		gamemode.GetRoundStage() == 'PreRoundWait' and
		gamemode.PrepLatecomer(PlayerState)
	then
		-- Player did not declare ready, but the timer run out.
		gamemode.EnterPlayArea(PlayerState)
	end
end

function KillConfirmed:CheckReadyUpTimer()
	if
		gamemode.GetRoundStage() == 'WaitingForReady' or
		gamemode.GetRoundStage() == 'ReadyCountdown'
	then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		local BluForReady = ReadyPlayerTeamCounts[self.PlayerTeams.BluFor.TeamId]
		if BluForReady >= gamemode.GetPlayerCount(true) then
			gamemode.SetRoundStage('PreRoundWait')
		elseif BluForReady > 0 then
			gamemode.SetRoundStage('ReadyCountdown')
		end
	end
end

function KillConfirmed:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == 'ReadyCountdown' then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		if ReadyPlayerTeamCounts[self.PlayerTeams.BluFor.TeamId] < 1 then
			gamemode.SetRoundStage('WaitingForReady')
		end
	end
end

function KillConfirmed:ShouldCheckForTeamKills()
	if gamemode.GetRoundStage() == 'InProgress' then
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

function KillConfirmed:LogOut(Exiting)
	print('Player left the game')
	if
		gamemode.GetRoundStage() == 'PreRoundWait' or
		gamemode.GetRoundStage() == 'InProgress'
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

--#region Spawns

function KillConfirmed:SetUpOpForStandardSpawns()
	print('Setting up AI spawn points by groups')
	local maxAiCount = math.min(
		SpawnsOpForGroups.Total,
		ai.GetMaxCount() - self.Settings.HVTCount.Value
	)
	self.OpFor.CalculatedAiCount = Spawns.GetAiCountWithDeviationPercent(
		5,
		maxAiCount,
		gamemode.GetPlayerCount(true),
		5,
		self.Settings.OpForPreset.Value,
		5,
		0.1
	)
	local missingAiCount = self.OpFor.CalculatedAiCount
	-- Select groups guarding the HVTs and add their spawn points to spawn list
	local maxAiCountPerHvtGroup = math.floor(
		missingAiCount / self.Settings.HVTCount.Value
	)
	local aiCountPerHvtGroup = Spawns.GetAiCountWithDeviationNumber(
		3,
		maxAiCountPerHvtGroup,
		gamemode.GetPlayerCount(true),
		1,
		self.Settings.OpForPreset.Value,
		1,
		0
	)
	print('Adding group spawns closest to HVTs')
	for i = 1, ObjectiveKillConfirmed:GetHvtCount() do
		local hvtLocation = actor.GetLocation(
			ObjectiveKillConfirmed:GetSelectedSpawnPoint(i)
		)
		SpawnsOpForGroups:AddSpawnsFromClosestGroup(aiCountPerHvtGroup, hvtLocation)
	end
	missingAiCount = self.OpFor.CalculatedAiCount -
		SpawnsOpForGroups:GetSelectedSpawnPointsCount()
	-- Select random groups and add their spawn points to spawn list
	print('Adding random group spawns')
	while missingAiCount > 0 do
		local aiCountPerGroup = Spawns.GetAiCountWithDeviationNumber(
			2,
			10,
			gamemode.GetPlayerCount(true),
			0.5,
			self.Settings.OpForPreset.Value,
			1,
			1
		)
		if aiCountPerGroup > missingAiCount	then
			print('Remaining AI count is not enough to fill group')
			break
		end
		SpawnsOpForGroups:AddSpawnsFromRandomGroup(aiCountPerGroup)
		missingAiCount = self.OpFor.CalculatedAiCount -
			SpawnsOpForGroups:GetSelectedSpawnPointsCount()
	end
	-- Select random spawns
	SpawnsOpForGroups:AddRandomSpawns()
	SpawnsOpForGroups:AddRandomSpawnsFromReserve()
end

function KillConfirmed:SpawnOpFor()
	ObjectiveKillConfirmed:Spawn(0.4)
	timer.Set(
		self.Timers.SpawnOpFor.Name,
		self,
		self.SpawnStandardOpForTimer,
		0.5,
		false
	)
end

function KillConfirmed:SpawnStandardOpForTimer()
	SpawnsOpForGroups:Spawn(3.5, self.OpFor.CalculatedAiCount, self.OpFor.Tag)
	timer.Set(
		self.Timers.CheckSpawnedAi.Name,
		self,
		self.CheckSpawnedAiTimer,
		self.Timers.CheckSpawnedAi.TimeStep,
		false
	)
end

function KillConfirmed:CheckSpawnedAiTimer()
	local hvtControllers = ai.GetControllers(
		'GroundBranch.GBAIController',
		self.HVT.Tag,
		255,
		255
	)
	print('Spawned ' .. #hvtControllers .. ' HVT AI')
	if self.Settings.HVTCount.Value ~= #hvtControllers then
		print('Failed to spawn all HVTs, correcting values.')
		self.Settings.HVTCount.Value = #hvtControllers
	end
	local standardControllers = ai.GetControllers(
		'GroundBranch.GBAIController',
		self.OpFor.Tag,
		255,
		255
	)
	print('Spawned ' .. #standardControllers .. ' standard AI')
end

--#endregion

--#region Objective: Kill confirmed

function KillConfirmed:OnAllKillsConfirmed()
	ObjectiveExfil:SelectedPointSetActive(true)
end

--#endregion

--#region Objective: Extraction

function KillConfirmed:OnGameTriggerBeginOverlap(GameTrigger, Player)
	if ObjectiveExfil:CheckTriggerAndPlayer(GameTrigger, Player) then
		ObjectiveExfil:PlayerEnteredExfiltration(
			ObjectiveKillConfirmed:GetAllConfirmed()
		)
	end
end

function KillConfirmed:OnGameTriggerEndOverlap(GameTrigger, Player)
	if ObjectiveExfil:CheckTriggerAndPlayer(GameTrigger, Player) then
		ObjectiveExfil:PlayerLeftExfiltration()
	end
end

function KillConfirmed:OnExfiltrated()
	if gamemode.GetRoundStage() ~= 'InProgress' then
		return
	end
	gamemode.AddGameStat('Result=Team1')
	gamemode.AddGameStat('Summary=HVTsConfirmed')
	gamemode.AddGameStat(
		'CompleteObjectives=NeutralizeHVTs,ConfirmEliminatedHVTs,ExfiltrateBluFor'
	)
	gamemode.SetRoundStage('PostRoundWait')
end

--#endregion

--#region Fail Condition

function KillConfirmed:CheckBluForCountTimer()
	if #self.Players.WithLives == 0 then
		gamemode.AddGameStat('Result=None')
		if ObjectiveKillConfirmed:GetAllNeutralized() then
			gamemode.AddGameStat('Summary=BluForExfilFailed')
			gamemode.AddGameStat('CompleteObjectives=NeutralizeHVTs')
		elseif ObjectiveKillConfirmed:GetAllConfirmed() then
			gamemode.AddGameStat('Summary=BluForExfilFailed')
			gamemode.AddGameStat(
				'CompleteObjectives=NeutralizeHVTs,ConfirmEliminatedHVTs'
			)
		else
			gamemode.AddGameStat('Summary=BluForEliminated')
		end
		gamemode.SetRoundStage('PostRoundWait')
	end
end

--#endregion

--#region Helpers

function KillConfirmed:PreRoundCleanUp()
	ai.CleanUp(self.HVT.Tag)
	ai.CleanUp(self.OpFor.Tag)
	self.Players.WithLives = {}
	MessagesObjective:SetRecipients(self.Players.WithLives)
	PromptsObjective:SetRecipients(self.Players.WithLives)
	ObjectiveKillConfirmed:SetPlayersWithLives(self.Players.WithLives)
	ObjectiveKillConfirmed:Reset()
	ObjectiveExfil:Reset()
end

function KillConfirmed:CheckIfSettingsChanged()
	if self.SettingTrackers.LastHVTCount ~= self.Settings.HVTCount.Value then
		print('Leader count changed, reshuffling spawns & updating objective markers.')
		ObjectiveKillConfirmed:SetHvtCount(self.Settings.HVTCount.Value)
		ObjectiveKillConfirmed:ShuffleSpawns()
		self.SettingTrackers.LastHVTCount = self.Settings.HVTCount.Value
	end
end

--#endregion

return KillConfirmed
