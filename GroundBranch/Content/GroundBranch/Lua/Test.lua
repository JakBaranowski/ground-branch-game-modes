local Tables = require('Common.Tables')
local ModSpawns = require('Spawns.Priority')

local Test = {
	UseReadyRoom = true,
	UseRounds = true,
	StringTables = {},
	PlayerTeams = {
		Blue = {
			TeamId = 1,
			Loadout = 'NoTeam',
		},
	},
	Settings = {
		RoundTime = {
			Min = 5,
			Max = 30,
			Value = 10,
		},
	},
	AiSpawns = nil,
	Players = {}
}

Test.__index = Test

function Test:new()
	local test = {}
	setmetatable(self, test)
	return test
end

--#region Initialization

---Method called right after the mission is loaded.
function Test:PreInit()
	print('PreInit')
	self.AiSpawns = ModSpawns:Create()
end

---Method called just before player gets control.
function Test:PostInit()
	print('PostInit')
	timer.Set(
		'TestTimer1',
		self,
		self.TestTimer1,
		10.0,
		false
	)
end

function Test:TestTimer1()
	print('TestTimer1')
	local players = gamemode.GetPlayerList(
		1,
		0,
		false,
		0,
		true
	)
	print('Found ' .. #players .. ' players')
	player.ShowGameMessage(
		players[1],
		'TestMessage1',
		'Lower',
		60.0
	)
	timer.Set(
		'TestTimer2',
		self,
		self.TestTimer2,
		5.0,
		false
	)
end

function Test:TestTimer2()
	print('TestTimer2')
	print('Clearing message')
	timer.Clear(self, 'TestMessage1')
end

--#endregion

--#region Triggers

---Triggered when a round stage is set. Round stage can be anything set by the user
---using the gamemode.SetRoundStage(stage) function. However there are some predefined
---round stages.
---@param RoundStage string named of the set round stage
---| 'WaitingForReady'
---| 'ReadyCountdown'
---| 'PreRoundWait'
---| 'InProgress'
---| 'PostRoundWait'
function Test:OnRoundStageSet(RoundStage)
	print('OnRoundStageSet ' .. RoundStage)
	if RoundStage == 'PreRoundWait' then
		self.AiSpawns:SelectSpawnPoints()
		print('Stage time ' .. gamemode.GetRoundStageTime())
		self.AiSpawns:Spawn(
			4.0,
			nil,
			'OpFor'
		)
	elseif RoundStage == 'PostRoundWait' then
		ai.CleanUp(self.AiTeams.OpFor.Tag)
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
function Test:OnRoundStageTimeElapsed(RoundStage)
	print('OnRoundStageTimeElapsed ' .. RoundStage)
end

---Triggered whenever any character dies (player or bot).
---@param Character any Character that died.
---@param CharacterController any Controller of the character that died.
---@param KillerController any Controller of the character that killed the character.
function Test:OnCharacterDied(Character, CharacterController, KillerController)
	print('OnCharacterDied')
end

---Triggered whenever any actor overlaps a trigger. Note: Extraction points act as
---triggers as well.
---@param GameTrigger any
---@param Player any
function Test:OnGameTriggerBeginOverlap(GameTrigger, Player)
	print('OnGameTriggerBeginOverlap')
end

---Triggered whenever any actor overlaps a trigger. Note: Extraction points act as
---triggers as well.
---@param GameTrigger any
---@param Player any
function Test:OnGameTriggerEndOverlap(GameTrigger, Player)
	print('OnGameTriggerBeginOverlap')
end

--#endregion

--#region Player actions

---Method called when a player changes the selected insertion point.
---@param PlayerState any
---@param InsertionPoint any
function Test:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	print('PlayerInsertionPointChanged')
end

---Method called when a player changes their ready status. If mission provides insertion
---points this is called at more or less the same time as PlayerInsertionPointChanged.
---@param PlayerState any
---@param ReadyStatus string
---| 'NotReady'
---| 'WaitingToReadyUp'
---| 'DeclaredReady'
function Test:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	print('PlayerReadyStatusChanged ' .. ReadyStatus)

	if ReadyStatus == 'WaitingToReadyUp' then
		if not Tables.Index(self.Players, PlayerState) then
			table.insert(self.Players, PlayerState)
		end
	elseif ReadyStatus == 'NotReady' then
		local index = Tables.Index(self.Players, PlayerState)
		if index then
			table.remove(self.Players, index)
		end
	end

	local RoundStage = gamemode.GetRoundStage()
	if RoundStage ~= 'WaitingForReady' and RoundStage ~= 'ReadyCountdown' then
		return
	end

	local readyPlayersCount = 0
	local allPlayersCount = gamemode.GetPlayerCount(true)
	for _, team in ipairs(gamemode.GetReadyPlayerTeamCounts(true)) do
		readyPlayersCount = readyPlayersCount + team
	end

	print('readyPlayersCount ' .. readyPlayersCount .. ' allPlayersCount ' .. allPlayersCount)

	if readyPlayersCount >= allPlayersCount then
		gamemode.SetRoundStage('PreRoundWait')
	elseif readyPlayersCount >= 1 and RoundStage == 'WaitingForReady' then
		gamemode.SetRoundStage('ReadyCountdown')
	elseif readyPlayersCount < 1 and RoundStage == 'ReadyCountdown' then
		gamemode.SetRoundStage('WaitingForReady')
	end
end

---Called by the game to check if the player should be allowed to enter play area.
---@param PlayerState any
---@return boolean PlayerCanEnterPlayArea whether or not should we allow users to enter
---play area.
function Test:PlayerCanEnterPlayArea(PlayerState)
	print('PlayerCanEnterPlayArea')
	return true
end

---Called when any player enters the play area.
---@param PlayerState any
function Test:PlayerEnteredPlayArea(PlayerState)
	print('PlayerEnteredPlayArea')

end

---
---@param PlayerState any
---@param Request string
---| 'join'
function Test:PlayerGameModeRequest(PlayerState, Request)
	print('PlayerGameModeRequest ' .. Request)
end

---Called when a player tries to enter play area in order to get a spawn point for
---the player. Has to return a spawn point in which the user will be spawned.
---@param PlayerState any
---@return any SpawnPoint the spawn point we want the user to spawn in.
function Test:GetSpawnInfo(PlayerState)
	print('GetSpawnInfo')
	return nil
end

---Triggered whenever a player leaves the game.
---@param Exiting any
function Test:LogOut(Exiting)
	print('LogOut')
end

--#endregion

--#region Misc

---Whether or not we should check for team kills at this point.
---@return boolean ShouldCheckForTeamKills should we check for team kills.
function Test:ShouldCheckForTeamKills()
	print('ShouldCheckForTeamKills')
	return true
end

--#endregion

return Test
