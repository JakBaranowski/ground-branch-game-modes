--[[
	Break Out
	PvE Ground Branch game mode by Jakub 'eelSkillz' Baranowski
	More details @ https://github.com/JakBaranowski/ground-branch-game-modes/wiki/game-mode-break-out
]]--

local ModTeams = require('Common.Teams')
local ModSpawnsGroups = require('Spawns.Groups')
local ModSpawnsCommon = require('Spawns.Common')
local ModObjectiveExfiltrate = require('Objectives.Exfiltrate')

--#region Properties

local BreakOut = {
	UseReadyRoom = true,
	UseRounds = true,
	StringTables = {'BreakOut'},
	PlayerTeams = {
		BluFor = {
			TeamId = 1,
			Loadout = 'Captive',
		},
	},
	Settings = {
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
			Max = 2,
			Value = 0
		},
		RespawnCost = {
			Min = 1,
			Max = 2000,
			Value = 1000
		},
		DisplayScore = {
			Min = 0,
			Max = 1,
			Value = 0
		}
	},
	SettingTrackers = {
		HVTCount = 0,
		DisplayScore = 0,
		AllowRespawns = 0,
		RespawnCost = 1000
	},
	OpFor = {
		Tag = 'OpFor',
		CalculatedAiCount = 0,
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
		CheckSpawnedAi ={
			Name = 'CheckSpawnedAi',
			TimeStep = 4.1
		}
	}
}

--#endregion

--#region Spawns

local TeamBlue
local Spawns
local Exfiltrate

--#endregion

--#region Preparation

function BreakOut:PreInit()
	print('Initializing Break Out')
	-- Initalize game message broker
	TeamBlue = ModTeams:Create(
		self.PlayerTeams.BluFor.TeamId,
		false,
		self.Settings.DisplayScore.Value == 1
	)
	-- Gathers all OpFor spawn points by groups
	Spawns = ModSpawnsGroups:Create()
	-- Initialize Exfiltration objective
	Exfiltrate = ModObjectiveExfiltrate:Create(
		self,
		self.Exfiltrate,
		TeamBlue,
		1,
		5.0,
		1.0
	)
	self.SettingTrackers.DisplayScore = self.Settings.DisplayScore.Value
	self.SettingTrackers.AllowRespawns = self.Settings.AllowRespawns.Value
	self.SettingTrackers.RespawnCost = self.Settings.RespawnCost.Value
end

function BreakOut:PostInit()
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'ExfiltrateBluFor', 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'ExfiltrateAll', 2)
	print('Added game mode objectives')
end

--#endregion

--#region Common

function BreakOut:OnRoundStageSet(RoundStage)
	print('Started round stage ' .. RoundStage)
	timer.ClearAll()
	if RoundStage == 'WaitingForReady' then
		self:PreRoundCleanUp()
		Exfiltrate:SelectPoint(true)
		timer.Set(
			self.Timers.SettingsChanged.Name,
			self,
			self.CheckIfSettingsChanged,
			self.Timers.SettingsChanged.TimeStep,
			true
		)
	elseif RoundStage == 'PreRoundWait' then
		self:SetUpOpForSpawns()
		self:SpawnOpFor()
	elseif RoundStage == 'InProgress' then
		TeamBlue:UpdatePlayers()
		TeamBlue:UpdateAlivePlayers(1)
		Exfiltrate:SetPlayersRequiredForExfil(TeamBlue:GetAlivePlayersCount())
	end
end

function BreakOut:OnCharacterDied(Character, CharacterController, KillerController)
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
			if actor.HasTag(CharacterController, self.OpFor.Tag) then
				print('OpFor eliminated. Killer team ' .. killerTeam .. ' killed team ' .. killedTeam)
				if killerTeam ~= killedTeam then
					TeamBlue:IncreaseScore(100, 'Enemy_Kill')
				end
			else
				print('BluFor eliminated')
				if killerTeam == nil then
					TeamBlue:IncreaseScore(-50, 'Accident')
				elseif killerTeam == killedTeam then
					TeamBlue:IncreaseScore(-100, 'Team_Kill')
				end
				if self.Settings.AllowRespawns.Value == 0 then
					player.SetLives(
						CharacterController,
						player.GetLives(CharacterController) - 1
					)
					TeamBlue:UpdateAlivePlayers(1)
				end
				Exfiltrate:SetPlayersRequiredForExfil(TeamBlue:GetAlivePlayersCount())
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
	if ReadyStatus == 'WaitingToReadyUp' then
		player.ShowGameMessage(
			PlayerState,
			'Sidearm_+_1_Sidearm_Ammo_Pouch',
			'Engine',
			5.0
		)
		player.ShowGameMessage(
			PlayerState,
			'Recommended_Loadout:',
			'Engine',
			5.0
		)
	end
	if ReadyStatus ~= 'DeclaredReady' then
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
		gamemode.EnterPlayArea(PlayerState)
	end
end

function BreakOut:CheckReadyUpTimer()
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

function BreakOut:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == 'ReadyCountdown' then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		if ReadyPlayerTeamCounts[self.PlayerTeams.BluFor.TeamId] < 1 then
			gamemode.SetRoundStage('WaitingForReady')
		end
	end
end

function BreakOut:ShouldCheckForTeamKills()
	if gamemode.GetRoundStage() == 'InProgress' then
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

function BreakOut:PlayerEnteredPlayArea(PlayerState)
	player.SetAllowedToRestart(PlayerState, self.Settings.AllowRespawns.Value == 1)
end

function BreakOut:LogOut(Exiting)
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

function BreakOut:SetUpOpForSpawns()
	print('Setting up AI spawns by groups')
	local maxAiCount = math.min(
		Spawns:GetTotalSpawnPointsCount(),
		ai.GetMaxCount()
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
	-- Select groups guarding extraction and add their spawn points to spawn list
	print('Adding group closest to exfil')
	local aiCountPerExfilGroup = ModSpawnsCommon.GetAiCountWithDeviationNumber(
		3,
		10,
		gamemode.GetPlayerCount(true),
		1,
		self.Settings.OpForPreset.Value,
		1,
		0
	)
	local exfilLocation = actor.GetLocation(Exfiltrate:GetSelectedPoint())
	Spawns:AddSpawnsFromClosestGroup(aiCountPerExfilGroup, exfilLocation)
	print('Adding random spawns from remaining')
	Spawns:AddRandomSpawns()
	print('Adding random spawns from reserve')
	Spawns:AddRandomSpawnsFromReserve()
end

function BreakOut:SpawnOpFor()
	Spawns:Spawn(4.0, self.OpFor.CalculatedAiCount, self.OpFor.Tag)
	timer.Set(
		self.Timers.CheckSpawnedAi.Name,
		self,
		self.CheckSpawnedAiTimer,
		self.Timers.CheckSpawnedAi.TimeStep,
		false
	)
end

function BreakOut:CheckSpawnedAiTimer()
	local aiControllers = ai.GetControllers(
		'GroundBranch.GBAIController',
		self.OpFor.Tag,
		255,
		255
	)
	print('Spawned ' .. #aiControllers .. ' AI')
end

--#endregion

--#region Objective: Extraction

function BreakOut:OnGameTriggerBeginOverlap(GameTrigger, Player)
	if Exfiltrate:CheckTriggerAndPlayer(GameTrigger, Player) then
		Exfiltrate:PlayerEnteredExfiltration(true)
	end
end

function BreakOut:OnGameTriggerEndOverlap(GameTrigger, Player)
	if Exfiltrate:CheckTriggerAndPlayer(GameTrigger, Player) then
		Exfiltrate:PlayerLeftExfiltration()
	end
end

function BreakOut:Exfiltrate()
	if gamemode.GetRoundStage() ~= 'InProgress' then
		return
	end
	gamemode.AddGameStat('Result=Team1')
	if TeamBlue:GetAlivePlayersCount() >= TeamBlue:GetPlayersCount() then
		gamemode.AddGameStat('CompleteObjectives=ExfiltrateBluFor,ExfiltrateAll')
		gamemode.AddGameStat('Summary=BluForExfilSuccess')
	else
		gamemode.AddGameStat('CompleteObjectives=ExfiltrateBluFor')
		gamemode.AddGameStat('Summary=BluForExfilPartialSuccess')
	end
	gamemode.SetRoundStage('PostRoundWait')
end

--#endregion

--#region Fail condition

function BreakOut:CheckBluForCountTimer()
	if gamemode.GetRoundStage() ~= 'InProgress' then
		return
	end
	if TeamBlue:GetAlivePlayersCount() == 0 then
		timer.Clear(self, 'CheckBluForExfil')
		gamemode.AddGameStat('Result=None')
		gamemode.AddGameStat('Summary=BluForEliminated')
		gamemode.SetRoundStage('PostRoundWait')
	end
end

--#endregion

--region Helpers

function BreakOut:PreRoundCleanUp()
	ai.CleanUp(self.OpFor.Tag)
	TeamBlue:Reset()
	Exfiltrate:Reset()
end

function BreakOut:CheckIfSettingsChanged()
	if self.SettingTrackers.DisplayScore ~= self.Settings.DisplayScore.Value then
		print('Display score setting changed from ' .. self.SettingTrackers.DisplayScore .. ' to ' .. self.Settings.DisplayScore.Value)
		TeamBlue:SetDisplayScore(self.Settings.DisplayScore.Value == 1)
		self.SettingTrackers.DisplayScore = self.Settings.DisplayScore.Value
	end
	if self.SettingTrackers.AllowRespawns ~= self.Settings.AllowRespawns.Value then
		print('Allow respawns setting changed from ' .. self.SettingTrackers.AllowRespawns .. ' to ' .. self.Settings.AllowRespawns.Value)
		TeamBlue:SetRespawnType(self.Settings.AllowRespawns.Value)
		self.SettingTrackers.AllowRespawns = self.Settings.AllowRespawns.Value
	end
	if self.SettingTrackers.RespawnCost ~= self.Settings.RespawnCost.Value then
		print('Respawn cost setting changed from ' .. self.SettingTrackers.RespawnCost .. ' to ' .. self.Settings.RespawnCost.Value)
		TeamBlue:SetRespawnCost(self.Settings.RespawnCost.Value)
		self.SettingTrackers.RespawnCost = self.Settings.RespawnCost.Value
	end
end

--#endregion

return BreakOut
