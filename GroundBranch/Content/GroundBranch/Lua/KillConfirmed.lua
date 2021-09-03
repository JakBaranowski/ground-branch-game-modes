--[[
	Kill Confirmed
	PvE Ground Branch game mode by Jakub 'eelSkillz' Baranowski
	More details @ https://github.com/JakBaranowski/ground-branch-game-modes/wiki/game-mode-kill-confirmed
]]--

local ModTeams = require('Common.Teams')
local ModSpawnsGroups = require('Spawns.Groups')
local ModSpawnsCommon = require('Spawns.Common')
local ModObjectiveExfiltrate = require('Objectives.Exfiltrate')
local ModObjectiveConfirmKill = require('Objectives.ConfirmKill')

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
			Min = 1,
			Max = 2000,
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
	},
	InsertionPoints = {}
}

--#endregion

--#region Spawns

local TeamBlue
local Spawns
local Exfiltrate
local ConfirmKill

--#endregion

--#region Preparation

function KillConfirmed:PreInit()
	print('Pre initialization')
	print('Initializing Kill Confirmed')
	TeamBlue = ModTeams:Create(
		self.PlayerTeams.BluFor.TeamId,
		false
	)
	-- Gathers all OpFor spawn points by groups
	Spawns = ModSpawnsGroups:Create()
	-- Gathers all HVT spawn points
	ConfirmKill = ModObjectiveConfirmKill:Create(
		self,
		self.OnAllKillsConfirmed,
		TeamBlue,
		self.HVT.Tag,
		self.Settings.HVTCount.Value
	)
	-- Gathers all extraction points placed in the mission
	Exfiltrate = ModObjectiveExfiltrate:Create(
		self,
		self.OnExfiltrated,
		TeamBlue,
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
	self.Settings.HVTCount.Last = self.Settings.HVTCount.Value
	self.InsertionPoints = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBInsertionPoint')
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

function KillConfirmed:PostRun()
	print('Post Run')
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
		for _, insertionPoint in ipairs(self.InsertionPoints) do
			actor.SetActive(insertionPoint, false)
		end
		TeamBlue:RoundStart(
			self.Settings.RespawnCost.Value,
			self.Settings.DisplayScoreMessage.Value == 1,
			self.Settings.DisplayScoreMilestones.Value == 1,
			self.Settings.DisplayObjectiveMessages.Value == 1,
			self.Settings.DisplayObjectivePrompts.Value == 1
		)
	elseif RoundStage == 'PostRoundWait' then
		for _, insertionPoint in ipairs(self.InsertionPoints) do
			actor.SetActive(insertionPoint, true)
		end
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
				ConfirmKill:Neutralized(Character, KillerController)
			elseif actor.HasTag(CharacterController, self.OpFor.Tag) then
				print('OpFor standard eliminated')
				if killerTeam ~= killedTeam then
					TeamBlue:IncreaseScore(KillerController, 'EnemyKill', 100)
				end
			else
				print('BluFor eliminated')
				if killerTeam == nil then
					TeamBlue:IncreaseScore(CharacterController, 'Accident', -50)
				elseif killerTeam == killedTeam then
					TeamBlue:IncreaseScore(KillerController, 'TeamKill', -100)
				end
				TeamBlue:PlayerDied(CharacterController)
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

function KillConfirmed:PlayerGameModeRequest(PlayerState, Request)
	print('PlayerGameModeRequest ' .. Request)
	if PlayerState ~= nil then
		if Request == "join"  then
			gamemode.EnterPlayArea(PlayerState)
		end
	end
end

function KillConfirmed:GetSpawnInfo(PlayerState)
	print('GetSpawnInfo')
	TeamBlue:PlayerRespawned(PlayerState)
	local allPlayerStarts = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBPlayerStart')
	local randomNumber = math.random(1, #allPlayerStarts)
	return allPlayerStarts[randomNumber]
end

--#endregion

--#region Player Status

function KillConfirmed:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	print('PlayerInsertionPointChanged')
	print(InsertionPoint)
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
	if player.GetInsertionPoint(PlayerState) ~= nil then
		return true
	end
	return false
end

function KillConfirmed:PlayerEnteredPlayArea(PlayerState)
	print('PlayerEnteredPlayArea')
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
	print('OnGameTriggerBeginOverlap')
	if Exfiltrate:CheckTriggerAndPlayer(GameTrigger, Player) then
		Exfiltrate:PlayerEnteredExfiltration(
			ConfirmKill:AreAllConfirmed()
		)
	end
end

function KillConfirmed:OnGameTriggerEndOverlap(GameTrigger, Player)
	print('OnGameTriggerEndOverlap')
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
	if gamemode.GetRoundStage() ~= 'InProgress' then
		return
	end
	if TeamBlue:IsWipedOut() then
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
	ConfirmKill:Reset()
	Exfiltrate:Reset()
end

function KillConfirmed:CheckIfSettingsChanged()
	if self.Settings.HVTCount.Last ~= self.Settings.HVTCount.Value then
		print('Leader count changed, reshuffling spawns & updating objective markers.')
		ConfirmKill:SetHvtCount(self.Settings.HVTCount.Value)
		ConfirmKill:ShuffleSpawns()
		self.Settings.HVTCount.Last = self.Settings.HVTCount.Value
	end
end

--#endregion

return KillConfirmed
