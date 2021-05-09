local deathmatch = {
	UseReadyRoom = true,
	UseRounds = false,
	PlayerStarts = {},
	RecentlyUsedPlayerStarts = {},
	MaxRecentlyUsedPlayerStarts = 0,
	TooCloseSq = 1000000,
}

function deathmatch:PreInit()
	self.PlayerStarts = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBPlayerStart')
	self.MaxRecentlyUsedPlayerStarts = #self.PlayerStarts / 2
end

function deathmatch:PlayerGameModeRequest(PlayerState, Request)
	if PlayerState ~= nil then
		if Request == "join"  then
			gamemode.EnterPlayArea(PlayerState)
		end
	end
end

function deathmatch:WasRecentlyUsed(PlayerStart)
	for i = 1, #self.RecentlyUsedPlayerStarts do
		if self.RecentlyUsedPlayerStarts[i] == PlayerStart then
			return true
		end
	end
	return false
end

function deathmatch:RateStart(PlayerStart)
	local StartLocation = actor.GetLocation(PlayerStart)
	local PlayersWithLives = gamemode.GetPlayerListByLives(0, 1, false)
	local DistScalar = 5000
	local ClosestDistSq = DistScalar * DistScalar

	for i = 1, #PlayersWithLives do
		local PlayerCharacter = player.GetCharacter(PlayersWithLives[i])

		-- May have lives, but no character, alive or otherwise.
		if PlayerCharacter ~= nil then
			local PlayerLocation = actor.GetLocation(PlayerCharacter)
			local DistSq = vector.SizeSq(StartLocation - PlayerLocation)
			if DistSq < self.TooCloseSq then
				return -10.0
			end
			
			if DistSq < ClosestDistSq then
				ClosestDistSq = DistSq
			end
		end
	end
	
	return math.sqrt(ClosestDistSq) / DistScalar * umath.random(45.0, 55.0)
end

function deathmatch:GetSpawnInfo(PlayerState)
	local StartsToConsider = {}
	local BestStart = nil
	
	for i, PlayerStart in ipairs(self.PlayerStarts) do
		if not self:WasRecentlyUsed(PlayerStart) then
			table.insert(StartsToConsider, PlayerStart)
		end
	end
	
	local BestScore = 0
	
	for i = 1, #StartsToConsider do
		local Score = self:RateStart(StartsToConsider[i])
		if Score > BestScore then
			BestScore = Score
			BestStart = StartsToConsider[i]
		end
	end
	
	if BestStart == nil then
		BestStart = StartsToConsider[umath.random(#StartsToConsider)]
	end
	
	if BestStart ~= nil then
		table.insert(self.RecentlyUsedPlayerStarts, BestStart)
		if #self.RecentlyUsedPlayerStarts > self.MaxRecentlyUsedPlayerStarts then
			table.remove(self.RecentlyUsedPlayerStarts, 1)
		end
	end
	
	return BestStart
end

return deathmatch