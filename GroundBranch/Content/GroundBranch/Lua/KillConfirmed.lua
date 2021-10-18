--[[
	Kill Confirmed
	PvE Ground Branch game mode by Jakub 'eelSkillz' Baranowski
	More details @ https://github.com/JakBaranowski/ground-branch-game-modes/wiki/game-mode-kill-confirmed
]]--

local ModTeams = require('Players.Teams')
local ModSpawnsGroups = require('Spawns.Groups')
local ModSpawnsCommon = require('Spawns.Common')
local ModObjectiveExfiltrate = require('Objectives.Exfiltrate')
local ModObjectiveConfirmKill = require('Objectives.ConfirmKill')

--#region Properties

local KillConfirmed = {
	UseReadyRoom = true,
	UseRounds = true,
	StringTables = {'KillConfirmed'},
	Settings = {
		HVTCount = {
			Min = 1,
			Max = 5,
			Value = 1,
			Last = 1
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
		RespawnCost = {
			Min = 0,
			Max = 10000,
			Value = 1000
		},
		DisplayScoreMessage = {
			Min = 0,
			Max = 1,
			Value = 0
		},
		DisplayScoreMilestones = {
			Min = 0,
			Max = 1,
			Value = 1
		},
		DisplayObjectiveMessages = {
			Min = 0,
			Max = 1,
			Value = 1
		},
		DisplayObjectivePrompts = {
			Min = 0,
			Max = 1,
			Value = 1
		},
	},
	PlayerTeams = {
		BluFor = {
			TeamId = 1,
			Loadout = 'NoTeam',
			Script = nil
		},
	},
	AiTeams = {
		OpFor = {
			Tag = 'OpFor',
			CalculatedAiCount = 0,
			Spawns = nil
		},
	},
	Objectives = {
		ConfirmKill = nil,
		Exfiltrate = nil,
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
	},
}

--#endregion

--#region Preparation

function KillConfirmed:PreInit()
	print('Pre initialization')
	print('Initializing Kill Confirmed')
	self.PlayerTeams.BluFor.Script = ModTeams:Create(
		1,
		false
	)
	-- Gathers all OpFor spawn points by groups
	self.AiTeams.OpFor.Spawns = ModSpawnsGroups:Create()
	-- Gathers all HVT spawn points
	self.Objectives.ConfirmKill = ModObjectiveConfirmKill:Create(
		self,
		self.OnAllKillsConfirmed,
		self.PlayerTeams.BluFor.Script,
		self.HVT.Tag,
		self.Settings.HVTCount.Value
	)
	-- Gathers all extraction points placed in the mission
	self.Objectives.Exfiltrate = ModObjectiveExfiltrate:Create(
		self,
		self.OnExfiltrated,
		self.PlayerTeams.BluFor.Script,
		5.0,
		1.0
	)
	-- Set maximum HVT count and ensure that HVT value is within limit
	self.Settings.HVTCount.Max = math.min(
		ai.GetMaxCount(),
		self.Objectives.ConfirmKill:GetAllSpawnPointsCount()
	)
	self.Settings.HVTCount.Value = math.min(
		self.Settings.HVTCount.Value,
		self.Settings.HVTCount.Max
	)
	-- Set last HVT count for tracking if the setting has changed.
	-- This is neccessary for adding objective markers on map.
	self.Settings.HVTCount.Last = self.Settings.HVTCount.Value
end

function KillConfirmed:PostInit()
	print('Post initialization')
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
		self.Objectives.Exfiltrate:SelectPoint(false)
		self.Objectives.ConfirmKill:ShuffleSpawns()
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
		self.PlayerTeams.BluFor.Script:RoundStart(
			self.Settings.RespawnCost.Value,
			self.Settings.DisplayScoreMessage.Value == 1,
			self.Settings.DisplayScoreMilestones.Value == 1,
			self.Settings.DisplayObjectiveMessages.Value == 1,
			self.Settings.DisplayObjectivePrompts.Value == 1
		)
	end
end

function KillConfirmed:OnCharacterDied(Character, CharacterController, KillerController)
	print('OnCharacterDied')
	if
		gamemode.GetRoundStage() == 'PreRoundWait' or
		gamemode.GetRoundStage() == 'InProgress'
	then
		if CharacterController ~= nil then
			local killedTeam = actor.GetTeamId(CharacterController)
			local killerTeam = nil
			if KillerController ~= nil then
				killerTeam = actor.GetTeamId(KillerController)
			end
			if actor.HasTag(CharacterController, self.HVT.Tag) then
				self.Objectives.ConfirmKill:Neutralized(Character, KillerController)
			elseif actor.HasTag(CharacterController, self.AiTeams.OpFor.Tag) then
				print('OpFor standard eliminated')
				if killerTeam == self.PlayerTeams.BluFor.TeamId then
					self.PlayerTeams.BluFor.Script:ChangeScore(KillerController, 'Enemy_Kill', 100)
				end
			else
				print('BluFor eliminated')
				if CharacterController == KillerController then
					self.PlayerTeams.BluFor.Script:ChangeScore(CharacterController, 'Accident', -50)
				elseif killerTeam == killedTeam then
					self.PlayerTeams.BluFor.Script:ChangeScore(KillerController, 'Team_Kill', -100)
				end
				self.PlayerTeams.BluFor.Script:PlayerDied(CharacterController, Character)
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
	print('PlayerInsertionPointChanged')
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
	print('PlayerReadyStatusChanged ' .. ReadyStatus)
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
	print('ShouldCheckForTeamKills')
	if gamemode.GetRoundStage() == 'InProgress' then
		return true
	end
	return false
end

function KillConfirmed:PlayerCanEnterPlayArea(PlayerState)
	print('PlayerCanEnterPlayArea')
	if
		gamemode.GetRoundStage() == 'InProgress' or
		player.GetInsertionPoint(PlayerState) ~= nil
	then
		return true
	end
	return false
end

function KillConfirmed:GetSpawnInfo(PlayerState)
	print('GetSpawnInfo')
	if gamemode.GetRoundStage() == 'InProgress' then
		self.PlayerTeams.BluFor.Script:RespawnCleanUp(PlayerState)
	end
end

function KillConfirmed:PlayerEnteredPlayArea(PlayerState)
	print('PlayerEnteredPlayArea')
	player.SetInsertionPoint(PlayerState, nil)
end

function KillConfirmed:LogOut(Exiting)
	print('Player left the game ')
	print(Exiting)
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
		self.AiTeams.OpFor.Spawns.Total,
		ai.GetMaxCount() - self.Settings.HVTCount.Value
	)
	self.AiTeams.OpFor.CalculatedAiCount = ModSpawnsCommon.GetAiCountWithDeviationPercent(
		5,
		maxAiCount,
		gamemode.GetPlayerCount(true),
		5,
		self.Settings.OpForPreset.Value,
		5,
		0.1
	)
	local missingAiCount = self.AiTeams.OpFor.CalculatedAiCount
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
	for i = 1, self.Objectives.ConfirmKill:GetHvtCount() do
		local hvtLocation = actor.GetLocation(
			self.Objectives.ConfirmKill:GetShuffledSpawnPoint(i)
		)
		self.AiTeams.OpFor.Spawns:AddSpawnsFromClosestGroup(aiCountPerHvtGroup, hvtLocation)
	end
	missingAiCount = self.AiTeams.OpFor.CalculatedAiCount -
		self.AiTeams.OpFor.Spawns:GetSelectedSpawnPointsCount()
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
		self.AiTeams.OpFor.Spawns:AddSpawnsFromRandomGroup(aiCountPerGroup)
		missingAiCount = self.AiTeams.OpFor.CalculatedAiCount -
			self.AiTeams.OpFor.Spawns:GetSelectedSpawnPointsCount()
	end
	-- Select random spawns
	self.AiTeams.OpFor.Spawns:AddRandomSpawns()
	self.AiTeams.OpFor.Spawns:AddRandomSpawnsFromReserve()
end

function KillConfirmed:SpawnOpFor()
	self.Objectives.ConfirmKill:Spawn(0.4)
	timer.Set(
		self.Timers.SpawnOpFor.Name,
		self,
		self.SpawnStandardOpForTimer,
		self.Timers.SpawnOpFor.TimeStep,
		false
	)
end

function KillConfirmed:SpawnStandardOpForTimer()
	self.AiTeams.OpFor.Spawns:Spawn(3.5, self.AiTeams.OpFor.CalculatedAiCount, self.AiTeams.OpFor.Tag)
end

--#endregion

--#region Objective: Kill confirmed

function KillConfirmed:OnAllKillsConfirmed()
	self.Objectives.Exfiltrate:SelectedPointSetActive(true)
end

--#endregion

--#region Objective: Extraction

function KillConfirmed:OnGameTriggerBeginOverlap(GameTrigger, Player)
	print('OnGameTriggerBeginOverlap')
	if self.Objectives.Exfiltrate:CheckTriggerAndPlayer(GameTrigger, Player) then
		self.Objectives.Exfiltrate:PlayerEnteredExfiltration(
			self.Objectives.ConfirmKill:AreAllConfirmed()
		)
	end
end

function KillConfirmed:OnGameTriggerEndOverlap(GameTrigger, Player)
	print('OnGameTriggerEndOverlap')
	if self.Objectives.Exfiltrate:CheckTriggerAndPlayer(GameTrigger, Player) then
		self.Objectives.Exfiltrate:PlayerLeftExfiltration()
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
	if gamemode.GetRoundStage() ~= 'InProgress' then
		return
	end
	if self.PlayerTeams.BluFor.Script:IsWipedOut() then
		gamemode.AddGameStat('Result=None')
		if self.Objectives.ConfirmKill:AreAllNeutralized() then
			gamemode.AddGameStat('Summary=BluForExfilFailed')
			gamemode.AddGameStat('CompleteObjectives=NeutralizeHVTs')
		elseif self.Objectives.ConfirmKill:AreAllConfirmed() then
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
	ai.CleanUp(self.AiTeams.OpFor.Tag)
	self.Objectives.ConfirmKill:Reset()
	self.Objectives.Exfiltrate:Reset()
end

function KillConfirmed:CheckIfSettingsChanged()
	if self.Settings.HVTCount.Last ~= self.Settings.HVTCount.Value then
		print('Leader count changed, reshuffling spawns & updating objective markers.')
		self.Objectives.ConfirmKill:SetHvtCount(self.Settings.HVTCount.Value)
		self.Objectives.ConfirmKill:ShuffleSpawns()
		self.Settings.HVTCount.Last = self.Settings.HVTCount.Value
	end
end

function KillConfirmed:GetPlayerTeamScript()
	return self.PlayerTeams.BluFor.Script
end

--#endregion

return KillConfirmed
