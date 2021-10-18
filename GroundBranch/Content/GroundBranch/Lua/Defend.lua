--[[
	Defend
	PvE Ground Branch game mode by Jakub 'eelSkillz' Baranowski
	More details @ https://github.com/JakBaranowski/ground-branch-game-modes/wiki/game-mode-kill-confirmed
]]--

local Tables          = require('Common.Tables')
local Actors          = require('Common.Actors')
local ModTeams 		  = require('Players.Teams')
local ModSpawnsGroups = require('Spawns.Groups')

local Defend = {
	UseReadyRoom = true,
	UseRounds = true,
	StringTables = {'Defend'},
	Settings = {
		RoundTime = {
			Min = 10,
			Max = 60,
			Value = 60,
		},
		PrepTime = {
			Min = 0.0,
			Max = 60.0,
			Value = 30.0,
		},
		Waves = {
			Min = 1,
			Max = 10,
			Value = 5,
		},
		FirstWaveEnemyCount = {
			Min = 1,
			Max = 50,
			Value = 10,
		},
		LastWaveEnemyCount = {
			Min = 1,
			Max = 50,
			Value = 30,
		},
		StartingZoneControl = {
			Min = 1.0,
			Max = 1000.0,
			Value = 300.0,
		},
		ZoneBalanceSwayPerPerson = {
			Min = 1.0,
			Max = 10.0,
			Value = 1.0,
		},
		ZoneBalanceMax = {
			Min = 0.0,
			Max = 10.0,
			Value = 1.0,
		},
		ZoneBalanceMin = {
			Min = 0.0,
			Max = 10.0,
			Value = 1.0,
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
		Blue = {
			TeamId = 1,
			Loadout = 'NoTeam',
			Script = nil,
		},
	},
	AiTeams = {
		OpFor = {
			TeamId = 100,
			Tag = 'OpFor',
			Script = nil,
			Spawns = {},
			Active = 0,
			CurrentIndex = 0,
			MaxIndexForWave = 0,
			Neutralized = {}
		},
	},
	Waves = {
		Current = 0,
		Duration = 300.0,
		GroupsInWave = 1,
		EnemiesInGroup = 5,
	},
	Zone = {
		Control = {
			Current = 300.0,
		},
		Balance = {
			Current = 0.0,
		},
		Triggers = {}
	},
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
		CheckSpawnedAi ={
			Name = 'CheckSpawnedAi',
			TimeStep = 4.1
		}
	}
}

--#region Initialization

---Method called right after the mission is loaded.
function Defend:PreInit()
	print('PreInit')
	print('Initializing Defend')
	-- Teams
	self.PlayerTeams.Blue.Script = ModTeams:Create(
		1,
		false
	)
	-- Spawns
	self.AiTeams.OpFor.Script = ModSpawnsGroups:Create()
	-- Zones
	self.Zone.Triggers = gameplaystatics.GetAllActorsOfClassWithTag('GroundBranch.GBGameTrigger', 'Zone')
	print('Found ' .. #self.Zone.Triggers .. ' triggers')
	for i, zone in ipairs(self.Zone.Triggers) do
		print('activating trigger ' .. i)
		actor.SetActive(zone, true)
	end
	-- MinMaxing
	self.Settings.LastWaveEnemyCount.Max = math.min(
		ai.GetMaxCount(),
		self.AiTeams.OpFor.Script:GetTotalSpawnPointsCount()
	)
	self.Settings.LastWaveEnemyCount.Value = math.min(
		self.Settings.LastWaveEnemyCount.Value,
		self.Settings.LastWaveEnemyCount.Max
	)
end

---Method called just before player gets control.
function Defend:PostInit()
	print('PostInit')
	gamemode.AddGameObjective(self.PlayerTeams.Blue.TeamId, 'DefendPosition', 1)
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
function Defend:OnRoundStageSet(RoundStage)
	print('OnRoundStageSet ' .. RoundStage)
	timer.ClearAll()
	if RoundStage == 'WaitingForReady' then
		self:PreRoundCleanUp()
	elseif RoundStage == 'InProgress' then
		self:StartRound()
	end
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
function Defend:OnRoundStageTimeElapsed(RoundStage)
	print('OnRoundStageTimeElapsed ' .. RoundStage)
end

---Triggered whenever any character dies (player or bot).
---@param Character any Character that died.
---@param CharacterController any Controller of the character that died.
---@param KillerController any Controller of the character that killed the character.
function Defend:OnCharacterDied(Character, CharacterController, KillerController)
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
			if actor.GetTeamId(Character) == 100 then
				print('OpFor standard eliminated')
				if killerTeam == self.PlayerTeams.Blue.TeamId then
					self.PlayerTeams.Blue.Script:ChangeScore(KillerController, 'Enemy_Kill', 100)
				end
				self.AiTeams.OpFor.Active = self.AiTeams.OpFor.Active - 1
				if self.AiTeams.OpFor.Active <= 0 then
					timer.Clear(self, 'WaveTimer')
					self:SpawnWave()
				end
				local tag = Actors.GetTagStartingWith(CharacterController, self.AiTeams.OpFor.Tag)
				print('Found tag ' .. tag)
				table.insert(
					self.AiTeams.OpFor.Neutralized,
					tag
				)
			else
				print('BluFor eliminated')
				if CharacterController == KillerController then
					self.PlayerTeams.Blue.Script:ChangeScore(CharacterController, 'Accident', -50)
				elseif killerTeam == killedTeam then
					self.PlayerTeams.Blue.Script:ChangeScore(KillerController, 'Team_Kill', -100)
				end
				self.PlayerTeams.Blue.Script:PlayerDied(CharacterController, Character)
				if self.PlayerTeams.Blue.Script:IsWipedOut() then
					self:EndRound(false)
				end
			end
		end
	end
end

---Triggered whenever any actor ovelaps a trigger. Note: Extraction points act as
---triggers as well.
---@param gameTrigger any
---@param character any
function Defend:OnGameTriggerBeginOverlap(gameTrigger, character)
	print('OnGameTriggerBeginOverlap')
end

---Triggered whenever any actor ovelaps a trigger. Note: Extraction points act as
---triggers as well.
---@param gameTrigger any
---@param character any
function Defend:OnGameTriggerEndOverlap(gameTrigger, character)
	print('OnGameTriggerEndOverlap')
end

--#endregion

--#region Player actions

---Method called when a player changes the selected insertion point.
---@param PlayerState any
---@param InsertionPoint any
function Defend:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
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
---| 'NotReady'
---| 'WaitingToReadyUp'
---| 'DeclaredReady'
function Defend:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
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

---Called by the game to check if the player should be allowed to enter play area.
---@param PlayerState any
---@return boolean PlayerCanEnterPlayArea whether or not should we allow users to enter
---play area.
function Defend:PlayerCanEnterPlayArea(PlayerState)
	print('PlayerCanEnterPlayArea')
	if
		gamemode.GetRoundStage() == 'InProgress' or
		player.GetInsertionPoint(PlayerState) ~= nil
	then
		return true
	end
	return false
end

---Called when any player enters the play area.
---@param PlayerState any
function Defend:PlayerEnteredPlayArea(PlayerState)
	print('PlayerEnteredPlayArea')
	player.SetInsertionPoint(PlayerState, nil)
end

---
---@param PlayerState any
---@param Request string
---| 'join'
function Defend:PlayerGameModeRequest(PlayerState, Request)
	print('PlayerGameModeRequest ' .. Request)
end

---Called when a player tries to enter play area in order to get a spawn point for
---the player. Has to return a spawn point in which the user will be spawned.
---@param PlayerState any
---@return any SpawnPoint the spawn point we want the user to spawn in.
function Defend:GetSpawnInfo(PlayerState)
	print('GetSpawnInfo')
	if gamemode.GetRoundStage() == 'InProgress' then
		self.PlayerTeams.Blue.Script:RespawnCleanUp(PlayerState)
	end
end

---Triggered whenever a player leaves the game.
---@param Exiting any
function Defend:LogOut(Exiting)
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

--#region Misc

---Whether or not we should check for team kills at this point.
---@return boolean ShouldCheckForTeamKills should we check for team kills.
function Defend:ShouldCheckForTeamKills()
	print('ShouldCheckForTeamKills')
	if gamemode.GetRoundStage() == 'InProgress' then
		return true
	end
	return false
end

--#endregion

--#region From Devs

function Defend:CheckReadyUpTimer()
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

function Defend:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == 'ReadyCountdown' then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		if ReadyPlayerTeamCounts[self.PlayerTeams.Blue.TeamId] < 1 then
			gamemode.SetRoundStage('WaitingForReady')
		end
	end
end

--#endregion

--#region Helpers

function Defend:PreRoundCleanUp()
	ai.CleanUp(self.AiTeams.OpFor.Tag)
end

function Defend:GetPlayerTeamScript()
	return self.PlayerTeams.Blue.Script
end

--#endregion

--#region Defend specific

function Defend:StartRound()
	self.PlayerTeams.Blue.Script:RoundStart(
		self.Settings.RespawnCost.Value,
		self.Settings.DisplayScoreMessage.Value == 1,
		self.Settings.DisplayScoreMilestones.Value == 1,
		self.Settings.DisplayObjectiveMessages.Value == 1,
		self.Settings.DisplayObjectivePrompts.Value == 1
	)
	self.Zone.Control.Current = self.Settings.StartingZoneControl.Value
	self.Zone.Balance.Current = 0.0
	self.Waves.Current = 0.0
	self.Waves.Duration =
		(self.Settings.RoundTime.Value * 60.0 - self.Settings.PrepTime.Value) /
		self.Settings.Waves.Value
	self.AiTeams.OpFor.CurrentIndex = 0
	self.AiTeams.OpFor.MaxIndexForWave = 0
	self.AiTeams.OpFor.Spawns = {}
	self.AiTeams.OpFor.Neutralized = {}
	if self.Settings.PrepTime.Value > 0 then
		self.PlayerTeams.Blue.Script:DisplayMessageToAlivePlayers(
			'Prep',
			'Upper',
			self.Settings.PrepTime.Value,
			'ObjectiveMessage'
		)
		timer.Set(
			'WaveTimer',
			self,
			self.SpawnWave,
			self.Settings.PrepTime.Value,
			false
		)
	else
		self:SpawnWave()
	end
	timer.Set(
		'ControlTimer',
		self,
		self.UpdateControl,
		1.0,
		true
	)
	timer.Set(
		'RoundTimer',
		self,
		self.EndRound,
		self.Settings.RoundTime.Value * 60.0 - 1.0,
		false
	)
end

function Defend:SpawnWave()
	if self.Waves.Current >= self.Settings.Waves.Value then
		self:EndRound(true)
	end
	self:CleanUpAi()
	self.Waves.Current = self.Waves.Current + 1
	print('Spawning wave ' .. self.Waves.Current)
	self.PlayerTeams.Blue.Script:DisplayMessageToAlivePlayers(
		'Wave' .. self.Waves.Current,
		'Upper',
		5.0,
		'ObjectiveMessage'
	)
	local totalEnemiesInWave = math.floor(
		self.Settings.FirstWaveEnemyCount.Value +
		(self.Waves.Current - 1) / self.Settings.Waves.Value *
		(self.Settings.LastWaveEnemyCount.Value - self.Settings.FirstWaveEnemyCount.Value)
	)
	totalEnemiesInWave = math.min(
		totalEnemiesInWave,
		self.AiTeams.OpFor.Script:GetTotalSpawnPointsCount()
	)
	self.Waves.GroupsInWave = math.max(
		math.ceil(totalEnemiesInWave / 10),
		self.Waves.Current
	)
	self.Waves.GroupsInWave = math.min(
		self.Waves.Current,
		self.AiTeams.OpFor.Script:GetTotalGroupsCount()
	)
	self.Waves.EnemiesInGroup = math.min(
		math.floor(totalEnemiesInWave / self.Waves.GroupsInWave),
		10
	)
	for _ = 1, self.Waves.GroupsInWave do
		self.AiTeams.OpFor.Script:AddSpawnsFromRandomGroup(self.Waves.EnemiesInGroup)
	end
	self:SpawnAiWithUniqueTags(totalEnemiesInWave)
	timer.Set(
		'WaveTimer',
		self,
		self.SpawnWave,
		self.Waves.Duration,
		false
	)
end

function Defend:SpawnAiWithUniqueTags(amount)
	self.AiTeams.OpFor.Spawns = Tables.ConcatenateTables(
		self.AiTeams.OpFor.Spawns,
		self.AiTeams.OpFor.Script:PopSelectedSpawnPoints()
	)
	self.AiTeams.OpFor.MaxIndexForWave = self.AiTeams.OpFor.CurrentIndex + amount
	self:SpawnAiWithUniqueTag()
end

function Defend:SpawnAiWithUniqueTag()
	if self.AiTeams.OpFor.CurrentIndex > self.AiTeams.OpFor.MaxIndexForWave then
		print('Active AI count ' .. self.AiTeams.OpFor.Active)
		return
	end
	self.AiTeams.OpFor.CurrentIndex = self.AiTeams.OpFor.CurrentIndex + 1
	local spawn = self.AiTeams.OpFor.Spawns[self.AiTeams.OpFor.CurrentIndex]
	if spawn == nil then
		print('Active AI count ' .. self.AiTeams.OpFor.Active)
		return
	end
	ai.Create(
		spawn,
		self.AiTeams.OpFor.Tag .. self.AiTeams.OpFor.CurrentIndex,
		0.09
	)
	self.AiTeams.OpFor.Active = self.AiTeams.OpFor.Active + 1
	timer.Set(
		'SpawnAiWithUniqueTag',
		self,
		self.SpawnAiWithUniqueTag,
		0.1,
		false
	)
end

function Defend:CleanUpAi()
	print('Cleaning up ' .. #self.AiTeams.OpFor.Neutralized .. ' neutralized AI')
	for _, uniqueAiTag in ipairs(self.AiTeams.OpFor.Neutralized) do
		print('Cleaning up tag ' .. uniqueAiTag)
		ai.CleanUp(uniqueAiTag)
	end
	self.AiTeams.OpFor.Neutralized = {}
end

function Defend:UpdateBalance()
	self.Zone.Balance.Current = 0.0
	local allOverlapingActors = {}
	for _, gameTrigger in ipairs(self.Zone.Triggers) do
		allOverlapingActors = Tables.ConcatenateTables(
			allOverlapingActors,
			actor.GetOverlaps(gameTrigger, 'GroundBranch.GBCharacter')
		)
	end

	for _, overlapingActor in ipairs(allOverlapingActors) do
		if not actor.HasTag(overlapingActor, 'Done') then
			actor.AddTag(overlapingActor, 'Done')
			if actor.GetTeamId(overlapingActor) == 1 then
				self.Zone.Balance.Current = self.Zone.Balance.Current +
					self.Settings.ZoneBalanceSwayPerPerson.Value
			else
				self.Zone.Balance.Current = self.Zone.Balance.Current -
					self.Settings.ZoneBalanceSwayPerPerson.Value
			end
		end
	end

	for _, overlapingActor in ipairs(allOverlapingActors) do
		actor.RemoveTag(overlapingActor, 'Done')
	end

	self.Zone.Balance.Current = math.max(
		math.min(
			self.Zone.Balance.Current,
			self.Settings.ZoneBalanceMax.Value
		),
		-self.Settings.ZoneBalanceMin.Value
	)

end

function Defend:UpdateControl()
	self:UpdateBalance()
	local prevControl = self.Zone.Control.Current
	self.Zone.Control.Current = math.min(
		self.Zone.Control.Current + self.Zone.Balance.Current,
		self.Settings.StartingZoneControl.Value
	)
	print('Current zone control ' .. self.Zone.Control.Current .. ' balance ' .. self.Zone.Balance.Current)
	if self.Zone.Control.Current <= 0 then
		self:EndRound(false)
	end
	if prevControl ~= self.Zone.Control.Current then
		if self.Zone.Balance.Current < 0 then
			self.PlayerTeams.Blue.Script:DisplayMessageToAlivePlayers(
				'Loosing_control,_current_' .. self.Zone.Control.Current,
				'Upper',
				0.99,
				'ObjectiveMessage'
			)
		elseif self.Zone.Balance.Current > 0 then
			self.PlayerTeams.Blue.Script:DisplayMessageToAlivePlayers(
				'Gaining_control,_current_' .. self.Zone.Control.Current,
				'Upper',
				0.99,
				'ObjectiveMessage'
			)
		end
	end
end

function Defend:EndRound(Success)
	if Success == nil then
		Success = true
	end
	if gamemode.GetRoundStage() ~= 'InProgress' then
		return
	end
	if Success then
		gamemode.AddGameStat('Result=Team1')
		gamemode.AddGameStat('Summary=PostionSecured')
		gamemode.AddGameStat('CompleteObjectives=DefendPosition')
	else
		gamemode.AddGameStat('Result=None')
		gamemode.AddGameStat('Summary=PostionLost')
	end
	gamemode.SetRoundStage('PostRoundWait')
end

--#endregion

return Defend
