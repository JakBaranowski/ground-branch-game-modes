local Test = {
	UseReadyRoom = true,	-- * Should this game mode use ready room.
	UseRounds = true, 		-- * Should this game mode use rounds.
	StringTables = {}, 		-- * Name of the `.csv` localization file (w/o extension).
	PlayerTeams = { 		-- * Player team settings.
		Blue = {			--     * Afaik this name can be anything.
			TeamId = 1,		--         * ID assigned to the team.
			Loadout = '',	--         * Name of the `.kit` loadout to be used by
		},					--           the team (w/o extension)
	},
	Settings = {			-- * Game mode settings changeable by players on opsboard.
		RoundTime = { 		--     * The time one round will last. Only needed if
			Min = 5,		--       using rounds.
			Max = 30,
			Value = 10,
		},
	},
	OpFor = {
		Tag = 'OpFor',
		Spawns = {},
		Controllers = {},
	},
	Players = {
		Alive = {},
	}
}

Test.__index = Test

function Test:new()
	local test = {}
	setmetatable(self, Test)
	return test
end

--#region Initialization

---Method called right after the mission is loaded.
function Test:PreInit()
	print('PreInit')
	self.OpFor.Spawns = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAISpawnPoint')
	for _, value in pairs(self.OpFor.Spawns) do
		print(value)
	end
end

---Method called just before player gets control.
function Test:PostInit()
	print('PostInit')
end

---Method called just after player gets control.
function Test:PostRun()
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
function Test:OnRoundStageSet(RoundStage)
	print('OnRoundStageSet ' .. RoundStage)
	if RoundStage == 'ReadyCountdown' then
		local readyPlayers = gamemode.GetReadyPlayerTeamCounts(true)
		if readyPlayers[self.PlayerTeams.Blue.TeamId] >= gamemode.GetPlayerCount(true) then
			gamemode.SetRoundStage('PreRoundWait')
		end
	end
	if RoundStage == 'PreRoundWait' then
		print('Spawning AI')
		ai.CreateOverDuration(
			4.0,
			1,
			self.OpFor.Spawns,
			self.OpFor.Tag
		)
	elseif RoundStage == 'InProgress' then
		timer.Set(
			'Test1',
			self,
			self.Test1Timer,
			4.5,
			false
		)
	end
end

function Test:Test1Timer()
	self.OpFor.Controllers = ai.GetControllers(
		'GroundBranch.GBAIController',
		self.OpFor.Tag,
		255,
		255
	)
	self.Players.Alive = gamemode.GetPlayerListByLives(
		self.PlayerTeams.Blue.TeamId,
		1,
		false
	)
	timer.Set(
		'Test2',
		self,
		self.Test2Timer,
		1,
		true
	)
end

function Test:Test2Timer()
	for _, ctrl in ipairs(self.OpFor.Controllers) do
		local ctrlLocation = actor.GetLocation(ctrl)
		-- local charLocation = actor.GetLocation(ai.GetCharacter(ctrlLocation))
		for _, p in ipairs(self.Players.Alive) do
			-- player.ShowWorldPrompt(
			-- 	p,
			-- 	charLocation,
			-- 	'Character',
			-- 	1
			-- )
			player.ShowWorldPrompt(
				p,
				ctrlLocation,
				'Controller',
				1
			)
		end
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

---Triggered whenever any actor ovelaps a trigger. Note: Extraction points act as 
---triggers as well.
---@param GameTrigger any
---@param Player any
function Test:OnGameTriggerBeginOverlap(GameTrigger, Player)
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
---| 'WaitingToReadyUp'
---| 'DeclaredReady'
function Test:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	print('PlayerReadyStatusChanged ' .. ReadyStatus)
	if ReadyStatus == 'DeclaredReady' then
		gamemode.SetRoundStage('ReadyCountdown')
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
-- function Test:GetSpawnInfo(PlayerState)
-- 	print('GetSpawnInfo')
-- 	return SpawnPoint
-- end

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
