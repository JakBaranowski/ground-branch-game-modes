local uplink = {
	BlueTeamId = 1,
	BlueTeamTag = "Blue",
	BlueTeamLoadoutName = "Blue",
	RedTeamId = 2,
	RedTeamTag = "Red",
	RedTeamLoadoutName = "Red",
	RoundResult = "",
	DefenderInsertionPoints = {},
	DefenderIndex = 0,
	AttackerInsertionPoints = {},
	bFixedInsertionPoints = false,
	GroupedLaptops = {},
	DefenderSetupTime = 30,
	MinDefenderSetupTime = 10,
	MaxDefenderSetupTime = 120,
	CaptureTime = 10,
	MinCaptureTime = 1,
	MaxCaptureTime = 60,
	DefendingTeamId = 2,
	AttackingTeamId = 1,
	RandomLaptop = nil,
	SpawnProtectionVolumes = {},
	AutoSwap = true,
	AutoSwapCount = 0,
}

function uplink:PostRun()
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
	
	local AllLaptops = gameplaystatics.GetAllActorsOfClass('/Game/GroundBranch/Props/Electronics/MilitaryLaptop/BP_Laptop_Usable.BP_Laptop_Usable_C')
		
	for i, DefenderInsertionPointName in ipairs(DefenderInsertionPointNames) do
		self.GroupedLaptops[DefenderInsertionPointName] = {}
		for j, Laptop in ipairs(AllLaptops) do
			if actor.HasTag(Laptop, DefenderInsertionPointName) then
				table.insert(self.GroupedLaptops[DefenderInsertionPointName], Laptop)
			end
		end
	end	
	
	if gamemode.HasGameOption("defendersetuptime") then
		self.DefenderSetupTime = math.max(tonumber(gamemode.GetGameOption("defendersetuptime")), self.MinDefenderSetupTime)
		self.DefenderSetupTime = math.min(self.DefenderSetupTime, self.MaxDefenderSetupTime)
	end

	if gamemode.HasGameOption("capturetime") then
		self.CaptureTime = math.max(tonumber(gamemode.GetGameOption("capturetime")), self.MinCaptureTime)
		self.CaptureTime = math.min(self.CaptureTime, self.MaxCaptureTime)
	end

	if gamemode.HasGameOption("autoswap") then
		self.AutoSwap = (tonumber(gamemode.GetGameOption("autoswap")) == 1)
	end

	-- SetupRound() will swap these the first time.
	-- To ensure that we get the right teams intially, set them to the opposite here.
	if self.AutoSwap then
		DefendingTeamId = 1
		AttackingTeamId = 2
	end
	
	gamemode.AddStringTable("Uplink")
	gamemode.AddGameRule("UseReadyRoom")
	gamemode.AddGameRule("UseRounds")
	gamemode.AddPlayerTeam(self.BlueTeamId, self.BlueTeamTag, self.BlueTeamLoadoutName);
	gamemode.AddPlayerTeam(self.RedTeamId, self.RedTeamTag, self.RedTeamLoadoutName);
	gamemode.AddGameSetting("roundtime", 5, 30, 5, 10);
	gamemode.AddGameSetting("defendersetuptime", self.MinDefenderSetupTime, self.MaxDefenderSetupTime, 10, self.DefenderSetupTime);

	gamemode.SetRoundStage("WaitingForReady")
end

function uplink:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	if InsertionPoint == nil then
		timer.Set(self, "CheckReadyDownTimer", 0.1, false);
	else
		timer.Set(self, "CheckReadyUpTimer", 0.25, false);
	end
end

function uplink:PlayerWantsToEnterPlayChanged(PlayerState, WantsToEnterPlay)
	if not WantsToEnterPlay then
		timer.Set(self, "CheckReadyDownTimer", 0.1, false);
	elseif gamemode.GetRoundStage() == "PreRoundWait" then
		if actor.GetTeamId(PlayerState) == self.DefendingTeamId then
			if self.DefenderIndex ~= 0 then
				player.SetInsertionPoint(PlayerState, self.DefenderInsertionPoints[self.DefenderIndex])
				gamemode.EnterPlayArea(PlayerState)
			end
		elseif gamemode.PrepLatecomer(PlayerState) then
			gamemode.EnterPlayArea(PlayerState)
		end
	end
end

function uplink:CheckReadyUpTimer()
	if gamemode.GetRoundStage() == "WaitingForReady" or gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(false)
		local DefendersReady = ReadyPlayerTeamCounts[self.DefendingTeamId]
		local AttackersReady = ReadyPlayerTeamCounts[self.AttackingTeamId]
		if DefendersReady > 0 and AttackersReady > 0 then
			if DefendersReady + AttackersReady >= gamemode.GetPlayerCount(true) then
				gamemode.SetRoundStage("PreRoundWait")
			else
				gamemode.SetRoundStage("ReadyCountdown")
			end
		end
	end
end

function uplink:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		local BlueReady = ReadyPlayerTeamCounts[self.DefendingTeamId]
		local RedReady = ReadyPlayerTeamCounts[self.AttackingTeamId]
		if BlueReady < 1 or RedReady < 1 then
			gamemode.SetRoundStage("WaitingForReady")
		end
	end
end

function uplink:OnRoundStageSet(RoundStage)
	if RoundStage == "WaitingForReady" then
		self:SetupRound()
	elseif RoundStage == "BlueDefenderSetup" or RoundStage == "RedDefenderSetup" then
		gamemode.SetRoundStageTime(self.DefenderSetupTime)
	elseif RoundStage == "InProgress" then
		timer.Set(self, "DisableSpawnProtection", 5.0, false);
	end
end

function uplink:OnCharacterDied(Character, CharacterController, KillerController)
	if gamemode.GetRoundStage() == "PreRoundWait" 
	or gamemode.GetRoundStage() == "InProgress"
	or gamemode.GetRoundStage() == "BlueDefenderSetup"
	or gamemode.GetRoundStage() == "RedDefenderSetup" then
		if CharacterController ~= nil then
			player.SetLives(CharacterController, player.GetLives(CharacterController) - 1)
			timer.Set(self, "CheckEndRoundTimer", 1.0, false);
		end
	end
end

function uplink:CheckEndRoundTimer()
	local BluePlayers = gamemode.GetPlayerList("Lives", self.BlueTeamId, true, 1, false)
	local RedPlayers = gamemode.GetPlayerList("Lives", self.RedTeamId, true, 1, false)
	
	if #BluePlayers > 0 and #RedPlayers == 0 then
		if self.DefendingTeamId == self.BlueTeamId then
			gamemode.AddGameStat("Result=Team1")
			gamemode.AddGameStat("Summary=RedEliminated")
			gamemode.AddGameStat("CompleteObjectives=DefendObjective")
			gamemode.SetRoundStage("PostRoundWait")
		end
	elseif #BluePlayers == 0 and #RedPlayers > 0 then
		if self.DefendingTeamId == self.RedTeamId then
			gamemode.AddGameStat("Result=Team2")
			gamemode.AddGameStat("Summary=BlueEliminated")
			gamemode.AddGameStat("CompleteObjectives=DefendObjective")
			gamemode.SetRoundStage("PostRoundWait")
		end
	elseif #BluePlayers == 0 and #RedPlayers == 0 then
		gamemode.AddGameStat("Result=None")
		gamemode.AddGameStat("Summary=BothEliminated")
		gamemode.SetRoundStage("PostRoundWait")
	end
end

function uplink:SetupRound()
	if self.AutoSwap then
		local PrevDefendingTeam = self.DefendingTeamId
		local PrevAttackingTeam = self.AttackingTeamId
		self.DefendingTeamId = PrevAttackingTeam
		self.AttackingTeamId = PrevDefendingTeam
		self.AutoSwapCount = self.AutoSwapCount + 1
		
		if self.AutoSwapCount > 1 then
			local BlueMessage = ""
			local RedMessage = ""
			
			if self.AttackingTeamId == self.BlueTeamId then
				BlueMessage = "SwapAttacking"
				RedMessage = "SwapDefending"
			else
				BlueMessage = "SwapDefending"
				RedMessage = "SwapAttacking"
			end
					
			local BluePlayers = gamemode.GetPlayerList("", self.BlueTeamId, false, 0, false)
			for i = 1, #BluePlayers do
				player.ShowGameMessage(BluePlayers[i], BlueMessage, 10.0)
			end
			
			local RedPlayers = gamemode.GetPlayerList("", self.RedTeamId, false, 0, false)
			for i = 1, #RedPlayers do
				player.ShowGameMessage(RedPlayers[i], BlueMessage, 10.0)
			end
		end
	end
	
	for i, SpawnProtectionVolume in ipairs(self.SpawnProtectionVolumes) do
		actor.SetTeamId(SpawnProtectionVolume, self.AttackingTeamId)
		actor.SetActive(SpawnProtectionVolume, true)
	end

	gamemode.ClearGameObjectives()

	gamemode.AddGameObjective(self.DefendingTeamId, "DefendObjective", 1)
	gamemode.AddGameObjective(self.AttackingTeamId, "CaptureObjective", 1)

	for i, InsertionPoint in ipairs(self.AttackerInsertionPoints) do
		actor.SetActive(InsertionPoint, true)
		actor.SetTeamId(InsertionPoint, self.AttackingTeamId)
	end

	if #self.DefenderInsertionPoints > 1 then
		local NewDefenderIndex = self.DefenderIndex

		while (NewDefenderIndex == self.DefenderIndex) do
			NewDefenderIndex = umath.random(#self.DefenderInsertionPoints)
		end
		
		self.DefenderIndex = NewDefenderIndex
	else
		self.DefenderIndex = 1
	end
	
	for i, InsertionPoint in ipairs(self.DefenderInsertionPoints) do
		actor.SetActive(InsertionPoint, i == self.DefenderIndex)
		actor.SetTeamId(InsertionPoint, self.DefendingTeamId)
	end

	local InsertionPointName = gamemode.GetInsertionPointName(self.DefenderInsertionPoints[self.DefenderIndex])
	local PossibleLaptops = self.GroupedLaptops[InsertionPointName]
	self.RandomLaptop = PossibleLaptops[umath.random(#PossibleLaptops)]

	for Group, Laptops in pairs(self.GroupedLaptops) do
		for j, Laptop in ipairs(Laptops) do
			local bActive = (Laptop == self.RandomLaptop)
			actor.SetActive(Laptop, bActive)
		end
	end
end

function uplink:ShouldCheckForTeamKills()
	if gamemode.GetRoundStage() == "InProgress" 
	or gamemode.GetRoundStage() == "BlueDefenderSetup"
	or gamemode.GetRoundStage() == "RedDefenderSetup" then
		return true
	end
	return false
end

function uplink:PlayerCanEnterPlayArea(PlayerState)
	if player.GetInsertionPoint(PlayerState) ~= nil then
		return true
	end
	return false
end

function uplink:OnRoundStageTimeElapsed(RoundStage)
	if RoundStage == "PreRoundWait" then
		if self.DefendingTeamId == self.BlueTeamId then
			gamemode.SetRoundStage("BlueDefenderSetup")
		else
			gamemode.SetRoundStage("RedDefenderSetup")
		end
		return true
	elseif RoundStage == "BlueDefenderSetup"
		or RoundStage == "RedDefenderSetup" then
		gamemode.SetRoundStage("InProgress")
		return true
	end
	return false
end

function uplink:OnProcessCommand(Command, Params)
	if Command == "defendersetuptime" then
		if Params ~= nil then
			self.DefenderSetupTime = math.max(tonumber(Params), self.MinDefenderSetupTime)
			self.DefenderSetupTime = math.min(self.DefenderSetupTime, self.MaxDefenderSetupTime)
		end
	elseif Command == "capturetime" then
		self.CaptureTime = math.max(tonumber(Params), self.MinCaptureTime)
		self.CaptureTime = math.min(self.CaptureTime, self.MaxCaptureTime)
	elseif Command == "autoswap" then
		if Params ~= nil then
			self.AutoSwap = (tonumber(Params) == 1)
		end
	end
end

function uplink:TargetCaptured()
	gamemode.AddGameStat("Summary=CaptureObjective")
	gamemode.AddGameStat("CompleteObjectives=CaptureObjective")
	if self.AttackingTeamId == self.RedTeamId then
		gamemode.AddGameStat("Result=Team2")
	else
		gamemode.AddGameStat("Result=Team1")
	end
	gamemode.SetRoundStage("PostRoundWait")
end

function uplink:PlayerEnteredPlayArea(PlayerState)
	if actor.GetTeamId(PlayerState) == self.AttackingTeamId then
		local FreezeTime = self.DefenderSetupTime + gamemode.GetRoundStageTime()
		player.FreezePlayer(PlayerState, FreezeTime)
	elseif actor.GetTeamId(PlayerState) == self.DefendingTeamId then
		local LaptopLocation = actor.GetLocation(self.RandomLaptop)
		player.ShowWorldPrompt(PlayerState, LaptopLocation, "DefendTarget", self.DefenderSetupTime - 2)
	end
end

function uplink:DisableSpawnProtection()
	if gamemode.GetRoundStage() == "InProgress" then
		for i, SpawnProtectionVolume in ipairs(self.SpawnProtectionVolumes) do
			actor.SetActive(SpawnProtectionVolume, false)
		end
	end
end

function uplink:LogOut(Exiting)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		timer.Set(self, "CheckEndRoundTimer", 1.0, false);
	end
end

return uplink