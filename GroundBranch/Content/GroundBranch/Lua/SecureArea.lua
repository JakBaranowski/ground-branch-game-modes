--[[
	Secure Area
	PvE Ground Branch game mode by Jakub 'eelSkillz' Baranowski
	More details @ https://github.com/JakBaranowski/ground-branch-game-modes
	Work in progress!
]]--

local ModUiGameMessageBroker = require('UI.GameMessageBroker')
local ModSpawnsCommon = require('Spawns.Common')
local ModSpawnsGroups = require('Spawns.Groups')
local ModCodenames = require('Common.Codenames')

local SecureArea = {
	UseReadyRoom = true,
	UseRounds = true,
	StringTables = {'SecureArea'},
	Settings = {
		RoundTime = {
			Min = 5,
			Max = 30,
			Value = 10
		},
		OpForPreset = {
			Min = 0,
			Max = 4,
			Value = 2
		},
		AllowRespawns = {
			Min = 0,
			Max = 1,
			Value = 0
		}
	},
	PlayerTeams = {
		Blue = {
			TeamId = 1,
			Loadout = 'NoTeam',
			WithLives = {},
		},
	},
	AiTeams = {
		OpFor = {
			Tag = 'OpFor',
			Count = 0,
		}
	},
	Zones = {},
	Laptops = {},
	Timers = {
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
	}
}

local Spawns
local MessagesObjective

--#region Initialization

---Method called right after the mission is loaded.
function SecureArea:PreInit()
	print('PreInit')
	print('Initializing Secure Area')
	MessagesObjective = ModUiGameMessageBroker:Create(self.PlayerTeams.Blue.WithLives, 'Upper')
	Spawns = ModSpawnsGroups:Create()
	for i = 1, 12 do
		local triggers = gameplaystatics.GetAllActorsOfClassWithTag(
			'GroundBranch.GBGameTrigger',
			ModCodenames.GetPrefixedCodename('Zone', i)
		)
		if triggers ~= nil and #triggers >= 1 then
			table.insert(self.Zones, triggers)
		end
		local laptops = gameplaystatics.GetAllActorsOfClassWithTag(
			'GroundBranch.GBGameTrigger',
			ModCodenames.GetPrefixedCodename('Zone', i)
		)
		if laptops ~= nil and #laptops >= 1 then
			table.insert(self.Laptops, laptops)
		end
	end
end

---Method called just before player gets control.
function SecureArea:PostInit()
	print('PostInit')
	gamemode.AddGameObjective(self.PlayerTeams.Blue.TeamId, 'SecureZones')
	print('Added secure zones objective')
end

---Method called just after player gets control.
function SecureArea:PostRun()
	print('PostRun')
end

--#endregion

--#region Triggers

---Triggered when a round stage is set. Round stage can be anything set by the user
---using the gamemode.SetRoundStage(stage) function. Howver there are some predefined
---round stages.
---@param RoundStage string named of the set round stage
---| 'WaitingForReady'
---| 'ReadyCountdown'
---| 'PreRoundWait'
---| 'InProgress'
---| 'PostRoundWait'
function SecureArea:OnRoundStageSet(RoundStage)
	print('OnRoundStageSet ' .. RoundStage)
	if RoundStage == 'WaitingForReady' then
		self:PreRoundCleanUp()
	elseif RoundStage == 'PreRoundWait' then
		--Spawn Ai
	elseif RoundStage == 'InProgress' then
		self.PlayerTeams.Blue.WithLives = gamemode.GetPlayerListByLives(
			self.PlayerTeams.Blue.TeamId,
			1,
			false
		)
		MessagesObjective:SetRecipients(self.PlayerTeams.Blue.WithLives)
	end
end

function SecureArea:SetUpOpForSpawns()
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
end

---Triggered when a round stage time elapse. Round stage can be anything set by
---the user using the gamemode.SetRoundStage(stage) function. However there are some
---predefined round stages.
---@param RoundStage string Name of the elapsed round stage
---| 'WaitingForReady'
---| 'ReadyCountdown'
---| 'PreRoundWait'
---| 'InProgress'
---| 'PostRoundWait'
function SecureArea:OnRoundStageTimeElapsed(RoundStage)
	print('OnRoundStageTimeElapsed ' .. RoundStage)
end

---Triggered whenever any character dies (player or bot).
---@param Character any Character that died.
---@param CharacterController any Controller of the character that died.
---@param KillerController any Controller of the character that killed the character.
function SecureArea:OnCharacterDied(Character, CharacterController, KillerController)
	print('OnCharacterDied')
end

---Triggered whenever any actor ovelaps a trigger. Note: Extraction points act as 
---triggers as well.
---@param GameTrigger any
---@param Player any
function SecureArea:OnGameTriggerBeginOverlap(GameTrigger, Player)
	print('OnGameTriggerBeginOverlap')
end

--#endregion

--#region Player actions

---Method called when a player changes the selected insertion point.
---@param PlayerState any
---@param InsertionPoint any
function SecureArea:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
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

---Method called when a player changes their ready status. If mission provides insertion
---points this is called at more or less the same time as PlayerInsertionPointChanged.
---@param PlayerState any
---@param ReadyStatus string
---| 'WaitingToReadyUp'
---| 'DeclaredReady'
function SecureArea:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
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

function SecureArea:CheckReadyUpTimer()
	if
		gamemode.GetRoundStage() == 'WaitingForReady' or
		gamemode.GetRoundStage() == 'ReadyCountdown'
	then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		local BluForReady = ReadyPlayerTeamCounts[self.PlayerTeams.Blue.TeamId]
		if BluForReady >= gamemode.GetPlayerCount(true) then
			gamemode.SetRoundStage('PreRoundWait')
		elseif BluForReady > 0 then
			gamemode.SetRoundStage('ReadyCountdown')
		end
	end
end

function SecureArea:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == 'ReadyCountdown' then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		if ReadyPlayerTeamCounts[self.PlayerTeams.Blue.TeamId] < 1 then
			gamemode.SetRoundStage('WaitingForReady')
		end
	end
end

---Called by the game to check if the player should be allowed to enter play area.
---@param PlayerState any
---@return boolean PlayerCanEnterPlayArea whether or not should we allow users to enter
---play area.
function SecureArea:PlayerCanEnterPlayArea(PlayerState)
	print('PlayerCanEnterPlayArea')
	if player.GetInsertionPoint(PlayerState) ~= nil then
		return true
	end
	return false
end

---Called when any player enters the play area.
---@param PlayerState any
function SecureArea:PlayerEnteredPlayArea(PlayerState)
	print('PlayerEnteredPlayArea')
	player.SetAllowedToRestart(PlayerState, self.Settings.AllowRespawns.Value == 1)
end

---
---@param PlayerState any
---@param Request string
---| 'join'
function SecureArea:PlayerGameModeRequest(PlayerState, Request)
	print('PlayerGameModeRequest ' .. Request)
end

---Called when a player tries to enter play area in order to get a spawn point for
---the player. Has to return a spawn point in which the user will be spawned.
---@param PlayerState any
---@return any SpawnPoint the spawn point we want the user to spawn in.
function SecureArea:GetSpawnInfo(PlayerState)
	print('GetSpawnInfo')
	return SpawnPoint
end

---Triggered whenever a player leaves the game.
---@param Exiting any
function SecureArea:LogOut(Exiting)
	print('LogOut')
end

--#endregion

--#region Misc

---Whether or not we should check for team kills at this point.
---@return boolean ShouldCheckForTeamKills should we check for team kills.
function SecureArea:ShouldCheckForTeamKills()
	print('ShouldCheckForTeamKills')
	return true
end

--#endregion

function SecureArea:PreRoundCleanUp()
	ai.CleanUp(self.AiTeams.OpFor.Tag)
	self.PlayerTeams.Blue.WithLives = {}
	MessagesObjective:SetRecipients(self.PlayerTeams.Blue.WithLives)
end

return SecureArea
