--[[
	Kill Confirmed
	PvE Ground Branch game mode by Jakub 'eelSkillz' Baranowski
	More details @ https://github.com/JakBaranowski/ground-branch-game-modes/wiki/game-mode-kill-confirmed
]]--

local ModSpawnsGroups = require('Spawns.Groups')
local ModSpawnsCommon = require('Spawns.Common')
local ModObjectiveExfiltrate = require('Objectives.Exfiltrate')
local ModObjectiveConfirmKill = require('Objectives.ConfirmKill')
local ModUiGameMessageBroker = require('UI.GameMessageBroker')
local ModUiWorldPromptBroker = require('UI.WorldPromptBroker')

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
		AllowRespawns = {
			Min = 0,
			Max = 1,
			Value = 0
		}
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
	}
}

--#endregion

--#region Spawns

local Spawns
local Exfiltrate
local ConfirmKill
local MessagesObjective
local PromptsObjective

--#endregion

--#region Preparation

function KillConfirmed:PreInit()
	print('Initializing Kill Confirmed')
	-- Setting up message broker
	MessagesObjective = ModUiGameMessageBroker:Create(self.Players.WithLives, 'Upper')
	PromptsObjective = ModUiWorldPromptBroker:Create(self.Players.WithLives)
	-- Gathers all OpFor spawn points by groups
	Spawns = ModSpawnsGroups:Create()
	-- Gathers all HVT spawn points
	ConfirmKill = ModObjectiveConfirmKill:Create(
		MessagesObjective,
		PromptsObjective,
		self,
		self.OnAllKillsConfirmed,
		self.PlayerTeams.BluFor.TeamId,
		self.Players.WithLives,
		self.HVT.Tag,
		self.Settings.HVTCount.Value
	)
	-- Gathers all extraction points placed in the mission
	Exfiltrate = ModObjectiveExfiltrate:Create(
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
	self.Settings.HVTCount.Max = math.min(
		ai.GetMaxCount(),
		ConfirmKill:GetAllSpawnPointsCount()
	)
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
		Exfiltrate:SelectPoint(false)
		ConfirmKill:ShuffleSpawns()
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
		ConfirmKill:SetPlayersWithLives(self.Players.WithLives)
		Exfiltrate:SetPlayersRequiredForExfil(#self.Players.WithLives)
	end
end

function KillConfirmed:OnCharacterDied(Character, CharacterController, KillerController)
	if
		gamemode.GetRoundStage() == 'PreRoundWait' or
		gamemode.GetRoundStage() == 'InProgress'
	then
		if CharacterController ~= nil then
			if actor.HasTag(CharacterController, self.HVT.Tag) then
				ConfirmKill:Neutralized(Character)
			elseif actor.HasTag(CharacterController, self.OpFor.Tag) then
				print('OpFor standard eliminated')
			else
				print('BluFor eliminated')
				if self.Settings.AllowRespawns.Value == 0 then
					player.SetLives(
						CharacterController,
						player.GetLives(CharacterController) - 1
					)
				end
				self.Players.WithLives = gamemode.GetPlayerListByLives(
					self.PlayerTeams.BluFor.TeamId,
					1,
					false
				)
				MessagesObjective:SetRecipients(self.Players.WithLives)
				PromptsObjective:SetRecipients(self.Players.WithLives)
				Exfiltrate:SetPlayersRequiredForExfil(#self.Players.WithLives)
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

function KillConfirmed:PlayerEnteredPlayArea(PlayerState)
	player.SetAllowedToRestart(PlayerState, self.Settings.AllowRespawns.Value == 1)
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
		Spawns.Total,
		ai.GetMaxCount() - self.Settings.HVTCount.Value
	)
	self.OpFor.CalculatedAiCount = ModSpawnsCommon.GetAiCountWithDeviationPercent(
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
	local aiCountPerHvtGroup = ModSpawnsCommon.GetAiCountWithDeviationNumber(
		3,
		maxAiCountPerHvtGroup,
		gamemode.GetPlayerCount(true),
		1,
		self.Settings.OpForPreset.Value,
		1,
		0
	)
	print('Adding group spawns closest to HVTs')
	for i = 1, ConfirmKill:GetHvtCount() do
		local hvtLocation = actor.GetLocation(
			ConfirmKill:GetShuffledSpawnPoint(i)
		)
		Spawns:AddSpawnsFromClosestGroup(aiCountPerHvtGroup, hvtLocation)
	end
	missingAiCount = self.OpFor.CalculatedAiCount -
		Spawns:GetSelectedSpawnPointsCount()
	-- Select random groups and add their spawn points to spawn list
	print('Adding random group spawns')
	while missingAiCount > 0 do
		local aiCountPerGroup = ModSpawnsCommon.GetAiCountWithDeviationNumber(
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
		Spawns:AddSpawnsFromRandomGroup(aiCountPerGroup)
		missingAiCount = self.OpFor.CalculatedAiCount -
			Spawns:GetSelectedSpawnPointsCount()
	end
	-- Select random spawns
	Spawns:AddRandomSpawns()
	Spawns:AddRandomSpawnsFromReserve()
end

function KillConfirmed:SpawnOpFor()
	ConfirmKill:Spawn(0.4)
	timer.Set(
		self.Timers.SpawnOpFor.Name,
		self,
		self.SpawnStandardOpForTimer,
		self.Timers.SpawnOpFor.TimeStep,
		false
	)
end

function KillConfirmed:SpawnStandardOpForTimer()
	Spawns:Spawn(3.5, self.OpFor.CalculatedAiCount, self.OpFor.Tag)
end

--#endregion

--#region Objective: Kill confirmed

function KillConfirmed:OnAllKillsConfirmed()
	Exfiltrate:SelectedPointSetActive(true)
end

--#endregion

--#region Objective: Extraction

function KillConfirmed:OnGameTriggerBeginOverlap(GameTrigger, Player)
	if Exfiltrate:CheckTriggerAndPlayer(GameTrigger, Player) then
		Exfiltrate:PlayerEnteredExfiltration(
			ConfirmKill:AreAllConfirmed()
		)
	end
end

function KillConfirmed:OnGameTriggerEndOverlap(GameTrigger, Player)
	if Exfiltrate:CheckTriggerAndPlayer(GameTrigger, Player) then
		Exfiltrate:PlayerLeftExfiltration()
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
		if ConfirmKill:AreAllNeutralized() then
			gamemode.AddGameStat('Summary=BluForExfilFailed')
			gamemode.AddGameStat('CompleteObjectives=NeutralizeHVTs')
		elseif ConfirmKill:AreAllConfirmed() then
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
	ConfirmKill:SetPlayersWithLives(self.Players.WithLives)
	ConfirmKill:Reset()
	Exfiltrate:Reset()
end

function KillConfirmed:CheckIfSettingsChanged()
	if self.SettingTrackers.LastHVTCount ~= self.Settings.HVTCount.Value then
		print('Leader count changed, reshuffling spawns & updating objective markers.')
		ConfirmKill:SetHvtCount(self.Settings.HVTCount.Value)
		ConfirmKill:ShuffleSpawns()
		self.SettingTrackers.LastHVTCount = self.Settings.HVTCount.Value
	end
end

--#endregion

return KillConfirmed
