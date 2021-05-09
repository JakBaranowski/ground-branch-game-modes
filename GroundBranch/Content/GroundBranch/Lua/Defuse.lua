local defuse = {
	UseReadyRoom = true,
	UseRounds = true,
	StringTables = { "Defuse" },
	PlayerTeams = {
		Blue = {
			TeamId = 1,
			Loadout = "Blue",
		},
		Red = {
			TeamId = 2,
			Loadout = "Red",
		},
	},
	Settings = {
		RoundTime = {
			Min = 5,
			Max = 30,
			Value = 10,
		},
		DefenderSetupTime = {
			Min = 10,
			Max = 120,
			Value = 30,
		},
		DefuseTime = {
			Min = 1,
			Max = 60,
			Value = 10,
		},
		BombCount = {
			Min = 1,
			Max = 10,
			Value = 2,
		},
		AutoSwap = {
			Min = 0,
			Max = 1,
			Value = 1,
		},
	},
	DefenderInsertionPoints = {},
	RandomDefenderInsertionPoint = nil,
	AttackerInsertionPoints = {},
	GroupedBombs = {},
	DefendingTeam = {},
	AttackingTeam = {},
	ActiveBombs = {},
	SpawnProtectionVolumes = {},
	ShowAutoSwapMessage = false,
}

function defuse:PreInit()
	self.SpawnProtectionVolumes = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBSpawnProtectionVolume')
	
	local AllInsertionPoints = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBInsertionPoint')
	local DefenderInsertionPointNames = {}

	for i, InsertionPoint in ipairs(AllInsertionPoints) do
		if actor.HasTag(InsertionPoint, "Defenders") then
			table.insert(self.DefenderInsertionPoints, InsertionPoint)
			table.insert(DefenderInsertionPointNames, gamemode.GetInsertionPointName(InsertionPoint))
		elseif actor.HasTag(InsertionPoint, "Attackers") then
			table.insert(self.AttackerInsertionPoints, InsertionPoint)
		end
	end

	local AllBombs = gameplaystatics.GetAllActorsOfClass('/Game/GroundBranch/Props/GameMode/BP_BigBomb.BP_BigBomb_C')
	local NumGroups = 0

	-- Group bombs by actor tag 1.
	for i, Bomb in ipairs(AllBombs) do
		local GroupTag = actor.GetTag(Bomb, 1)
		if GroupTag ~= nil then
			if self.GroupedBombs[GroupTag] == nil then
				NumGroups = NumGroups + 1
				self.GroupedBombs[GroupTag] = {}
			end
			table.insert(self.GroupedBombs[GroupTag], Bomb)
		end
	end

	-- Treat each bomb as its own group if no tags were found.
	if NumGroups < 1 then
		NumGroups = #AllBombs
		for i, Bomb in ipairs(AllBombs) do
			self.GroupedBombs[i] = {}
			table.insert(self.GroupedBombs[i], Bomb)
		end
	end

	self.Settings.BombCount.Max = NumGroups
	self.Settings.BombCount.Value = math.min(self.Settings.BombCount.Value, NumGroups)
end

function defuse:PostInit()
	-- Set initial defending & attacking teams.
	self.DefendingTeam = self.PlayerTeams.Red
	self.AttackingTeam = self.PlayerTeams.Blue
end

function defuse:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	if InsertionPoint == nil then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false);
	else
		timer.Set("CheckReadyUp", self, self.CheckReadyUpTimer, 0.25, false);
	end
end

function defuse:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	if ReadyStatus ~= "DeclaredReady" then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false);
	elseif gamemode.GetRoundStage() == "PreRoundWait" then
		if actor.GetTeamId(PlayerState) == self.DefendingTeam.TeamId then
			if self.RandomDefenderInsertionPoint ~= nil then
				player.SetInsertionPoint(PlayerState, self.RandomDefenderInsertionPoint)
				gamemode.EnterPlayArea(PlayerState)
			end
		elseif gamemode.PrepLatecomer(PlayerState) then
			gamemode.EnterPlayArea(PlayerState)
		end
	end
end

function defuse:CheckReadyUpTimer()
	if gamemode.GetRoundStage() == "WaitingForReady" or gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		local DefendersReady = ReadyPlayerTeamCounts[self.DefendingTeam.TeamId]
		local AttackersReady = ReadyPlayerTeamCounts[self.AttackingTeam.TeamId]
		if DefendersReady > 0 and AttackersReady > 0 then
			if DefendersReady + AttackersReady >= gamemode.GetPlayerCount(true) then
				gamemode.SetRoundStage("PreRoundWait")
			else
				gamemode.SetRoundStage("ReadyCountdown")
			end
		end
	end
end

function defuse:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		local DefendersReady = ReadyPlayerTeamCounts[self.DefendingTeam.TeamId]
		local AttackersReady = ReadyPlayerTeamCounts[self.AttackingTeam.TeamId]
		if DefendersReady < 1 or AttackersReady < 1 then
			gamemode.SetRoundStage("WaitingForReady")
		end
	end
end

function defuse:OnRoundStageSet(RoundStage)
	if RoundStage == "WaitingForReady" then
		self:SetupRound()
	elseif RoundStage == "PreRoundWait" then
		self:ActivateBombs()
	elseif RoundStage == "BlueDefenderSetup" or RoundStage == "RedDefenderSetup" then
		gamemode.SetRoundStageTime(self.Settings.DefenderSetupTime.Value)

		-- Adjust the detonation time based on the defender setup time.
		local DetonationTime = GetTimeSeconds() + (self.Settings.RoundTime.Value * 60.0) + self.Settings.DefenderSetupTime.Value
		for i = 1, #self.ActiveBombs do
			-- FIXME - this is shit.
			-- We should use the LuaComponent all the time!
			GetLuaComp(self.ActiveBombs[i]).SetDetonationTime(DetonationTime)
		end
	elseif RoundStage == "InProgress" then
		timer.Set("DisableSpawnProtection", self, self.DisableSpawnProtectionTimer, 5.0, false);
	elseif RoundStage == "PostRoundWait" then
		timer.Clear("ShowRemaining")
		local bExploded = false

		for i = 1, #self.ActiveBombs do
			GetLuaComp(self.ActiveBombs[i]).Explode()
			bExploded = true
		end
		
		if bExploded then
			gamemode.AddGameStat("Result=Team" .. tostring(self.DefendingTeam.TeamId))
			gamemode.AddGameStat("Summary=BombsDetonated")
			gamemode.AddGameStat("CompleteObjectives=DefendObjective")
		end
	end
end

function defuse:OnCharacterDied(Character, CharacterController, KillerController)
	if gamemode.GetRoundStage() == "PreRoundWait" 
	or gamemode.GetRoundStage() == "InProgress"
	or gamemode.GetRoundStage() == "BlueDefenderSetup"
	or gamemode.GetRoundStage() == "RedDefenderSetup" then
		if CharacterController ~= nil then
			player.SetLives(CharacterController, player.GetLives(CharacterController) - 1)
			timer.Set("CheckEndRound", self, self.CheckEndRoundTimer, 1.0, false);
		end
	end
end

function defuse:CheckEndRoundTimer()
	local AttackersWithLives = gamemode.GetPlayerListByLives(self.AttackingTeam.TeamId, 1, false)
	
	if #AttackersWithLives == 0 then
		-- ActiveBombs must be cleared to prevent end of round explosion.
		self.ActiveBombs = nil
		self.ActiveBombs = {}
		local DefendersWithLives = gamemode.GetPlayerListByLives(self.DefendingTeam.TeamId, 1, false)
		if #DefendersWithLives > 0 then
			gamemode.AddGameStat("Result=Team" .. tostring(self.DefendingTeam.TeamId))
			if self.DefendingTeam == self.PlayerTeams.Blue then
				gamemode.AddGameStat("Summary=RedEliminated")
			else
				gamemode.AddGameStat("Summary=BlueEliminated")
			end
			gamemode.AddGameStat("CompleteObjectives=DefendBombs")
			gamemode.SetRoundStage("PostRoundWait")
		else
			gamemode.AddGameStat("Result=None")
			gamemode.AddGameStat("Summary=BothEliminated")
			gamemode.SetRoundStage("PostRoundWait")
		end
	end
end

function defuse:SetupRound()
	if self.ShowAutoSwapMessage == true then
		self.ShowAutoSwapMessage = false
		
		local Attackers = gamemode.GetPlayerList(self.AttackingTeam.TeamId, false)
		for i = 1, #Attackers do
			player.ShowGameMessage(Attackers[i], "SwapAttacking", "Center", 10.0)
		end
		
		local Defenders = gamemode.GetPlayerList(self.DefendingTeam.TeamId, false)
		for i = 1, #Defenders do
			player.ShowGameMessage(Defenders[i], "SwapDefending", "Center", 10.0)
		end
	end
	
	for i, SpawnProtectionVolume in ipairs(self.SpawnProtectionVolumes) do
		actor.SetTeamId(SpawnProtectionVolume, self.AttackingTeam.TeamId)
		actor.SetActive(SpawnProtectionVolume, true)
	end

	gamemode.ClearGameObjectives()

	gamemode.AddGameObjective(self.DefendingTeam.TeamId, "DefendBombs", 1)
	gamemode.AddGameObjective(self.AttackingTeam.TeamId, "DefuseBombs", 1)

	for i, InsertionPoint in ipairs(self.AttackerInsertionPoints) do
		actor.SetActive(InsertionPoint, true)
		actor.SetTeamId(InsertionPoint, self.AttackingTeam.TeamId)
	end

	if #self.DefenderInsertionPoints > 1 then
		local NewRandomDefenderInsertionPoint = self.RandomDefenderInsertionPoint

		while (NewRandomDefenderInsertionPoint == self.RandomDefenderInsertionPoint) do
			NewRandomDefenderInsertionPoint = self.DefenderInsertionPoints[umath.random(#self.DefenderInsertionPoints)]
		end
		
		self.RandomDefenderInsertionPoint = NewRandomDefenderInsertionPoint
	else
		self.RandomDefenderInsertionPoint = self.DefenderInsertionPoints[1]
	end
	
	for i, InsertionPoint in ipairs(self.DefenderInsertionPoints) do
		if InsertionPoint == self.RandomDefenderInsertionPoint then
			actor.SetActive(InsertionPoint, true)
			actor.SetTeamId(InsertionPoint, self.DefendingTeam.TeamId)
		else
			actor.SetActive(InsertionPoint, false)
			actor.SetTeamId(InsertionPoint, 255)
		end
	end
end

function defuse:ActivateBombs()
	-- Shuffle the group names to prevent picking from the same group(s) each round.
	local ShuffledGroupNames = {}

	for Group, Bombs in pairs(self.GroupedBombs) do
		ShuffledGroupNames[#ShuffledGroupNames + 1] = Group
	end
	
	for i = #ShuffledGroupNames, 1, -1 do
		local j = umath.random(i)
		ShuffledGroupNames[i], ShuffledGroupNames[j] = ShuffledGroupNames[j], ShuffledGroupNames[i]
	end
	
	self.ActiveBombs = nil
	self.ActiveBombs = {}

	for i, GroupName in ipairs(ShuffledGroupNames) do
		local ActiveIndex = -1
		
		-- Only require an active index for the number of bombs we want active.
		if i <= self.Settings.BombCount.Value then
			ActiveIndex = umath.random(#self.GroupedBombs[GroupName])
		end
		
		for j = 1, #self.GroupedBombs[GroupName] do
			local Bomb = self.GroupedBombs[GroupName][j]
			if (j == ActiveIndex) then
				table.insert(self.ActiveBombs, Bomb)
				actor.SetActive(Bomb, true)
				-- FIXME - this is shit.
				-- We should use the LuaComponent all the time!
				GetLuaComp(Bomb).SetTeam(self.AttackingTeam.TeamId)
			else
				actor.SetActive(Bomb, false)
			end
		end
	end
end

function defuse:SwapTeams()
	if self.DefendingTeam == self.PlayerTeams.Blue then
		self.DefendingTeam = self.PlayerTeams.Red
		self.AttackingTeam = self.PlayerTeams.Blue
	else
		self.DefendingTeam = self.PlayerTeams.Blue
		self.AttackingTeam = self.PlayerTeams.Red
	end
	
	self.ShowAutoSwapMessage = true
end

function defuse:ShouldCheckForTeamKills()
	if gamemode.GetRoundStage() == "InProgress" 
	or gamemode.GetRoundStage() == "BlueDefenderSetup"
	or gamemode.GetRoundStage() == "RedDefenderSetup" then
		return true
	end
	return false
end

function defuse:PlayerCanEnterPlayArea(PlayerState)
	if player.GetInsertionPoint(PlayerState) ~= nil then
		return true
	end
	return false
end

function defuse:OnRoundStageTimeElapsed(RoundStage)
	if RoundStage == "PreRoundWait" then
		if self.DefendingTeam == self.PlayerTeams.Blue then
			gamemode.SetRoundStage("BlueDefenderSetup")
		else
			gamemode.SetRoundStage("RedDefenderSetup")
		end
		return true
	elseif RoundStage == "BlueDefenderSetup"
		or RoundStage == "RedDefenderSetup" then
		timer.Set("ShowRemaining", self, self.ShowRemainingTimer, 2, false)
		gamemode.SetRoundStage("InProgress")
		return true
	elseif RoundStage == "PostRoundWait" then
		if self.Settings.AutoSwap.Value ~= 0 then
			self:SwapTeams()
		end
	end
	return false
end

function defuse:BombDefused(Bomb)
	for i = #self.ActiveBombs, 1, -1 do
		if self.ActiveBombs[i] == Bomb then
			table.remove(self.ActiveBombs, i)
		end
	end

	if #self.ActiveBombs < 1 then
		timer.Clear("ShowRemaining")
		gamemode.AddGameStat("Summary=DefusedBombs")
		gamemode.AddGameStat("CompleteObjectives=DefuseBombs")
		gamemode.AddGameStat("Result=Team" .. tostring(self.AttackingTeam.TeamId))
		gamemode.SetRoundStage("PostRoundWait")
	else
		timer.Set("ShowRemaining", self, self.ShowRemainingTimer, 2, false)
	end
end

function defuse:ShowRemainingTimer()
	local Message = "BombsRemaining" .. tostring(#self.ActiveBombs)
	gamemode.BroadcastGameMessage(Message, "Engine", 2.0)
end

function defuse:PlayerEnteredPlayArea(PlayerState)
	if actor.GetTeamId(PlayerState) == self.AttackingTeam.TeamId then
		local FreezeTime = self.Settings.DefenderSetupTime.Value + gamemode.GetRoundStageTime()
		player.FreezePlayer(PlayerState, FreezeTime)
	elseif actor.GetTeamId(PlayerState) == self.DefendingTeam.TeamId then
		local Offset = vector:new(0,0,100)
		for i = 1, #self.ActiveBombs do
			local BombLocation = actor.GetLocation(self.ActiveBombs[i]) + Offset
			player.ShowWorldPrompt(PlayerState, BombLocation, "DefendBomb", self.Settings.DefenderSetupTime.Value - 2)
		end
	end
end

function defuse:DisableSpawnProtectionTimer()
	if gamemode.GetRoundStage() == "InProgress" then
		for i, SpawnProtectionVolume in ipairs(self.SpawnProtectionVolumes) do
			actor.SetActive(SpawnProtectionVolume, false)
		end
	end
end

function defuse:LogOut(Exiting)
	if gamemode.GetRoundStage() == "PreRoundWait" 
	or gamemode.GetRoundStage() == "InProgress"
	or gamemode.GetRoundStage() == "BlueDefenderSetup"
	or gamemode.GetRoundStage() == "RedDefenderSetup" then
		timer.Set("CheckEndRound", self, self.CheckEndRoundTimer, 1.0, false);
	end
end

return defuse