local bomb = {
	CurrentTime = 0.0,
}

function bomb:ServerUseTimer(User, DeltaTime)
	if actor.GetTeamId(User) == gamemode.script.AttackingTeam.TeamId then
		self.CurrentTime = self.CurrentTime + DeltaTime
		
		local DefuseTime = gamemode.script.Settings.DefuseTime.Value
		self.CurrentTime = math.max(self.CurrentTime, 0.0)
		self.CurrentTime = math.min(self.CurrentTime, DefuseTime)

		local Percentage = self.CurrentTime / DefuseTime

		GetLuaComp(self.actor).SetPercentage(Percentage)

		if Percentage == 1.0 then
			-- actor != owner
			-- FIXME - this is shit.
			-- We should use the LuaComponent all the time!
			GetLuaComp(self.actor).SetDefused(true)
			gamemode.script:BombDefused(self.actor)
		end
	end
end

function bomb:ServerUseEnd()
	self.CurrentTime = 0.0
	GetLuaComp(self.actor).SetPercentage(0.0)
end

function bomb:OnReset()
	self.CurrentTime = 0.0
end

return bomb