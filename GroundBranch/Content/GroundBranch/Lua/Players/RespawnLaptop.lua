local RespawnLaptop = {
	CurrentTime = 0.0,
}

function RespawnLaptop:ServerUseTimer(User, DeltaTime)
	local UseTime = 2.0
	local Result = {}

	self.CurrentTime = self.CurrentTime + DeltaTime
	self.CurrentTime = math.max(self.CurrentTime, 0)
	self.CurrentTime = math.min(self.CurrentTime, UseTime)

	Result.Equip = false
	Result.Percentage = self.CurrentTime / UseTime
	if Result.Percentage >= 1.0 then
		gamemode.GetScript():GetPlayerTeamScript():RespawnFromReadyRoom(User)
		Result.Message = 'Use to respawn'
		Result.Percentage = 0.0
		self.CurrentTime = 0.0
	elseif Result.Percentage == 0.0 then
		Result.Message = 'Use to respawn'
	else
		Result.Message = 'Respawning'
	end

	return Result
end

function RespawnLaptop:OnReset()
	self.CurrentTime = 0.0
end

return RespawnLaptop