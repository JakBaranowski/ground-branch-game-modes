local uplinktarget = {
	CurrentTime = 0,
}

function uplinktarget:ServerUseTimer(User, DeltaTime)
	local UserTeamId = actor.GetTeamId(User)
	local Result = {}
	if UserTeamId == gamemode.script.DefendingTeam.TeamId then
		if self.CurrentTime == 0 then
			Result.Message = "DataSecured"
			Result.Percentage = 0.0
			return Result
		end
		Result.Message = "SecuringData"
		self.CurrentTime = self.CurrentTime - DeltaTime
	else 
		Result.Message = "RetrievingData"
		self.CurrentTime = self.CurrentTime + DeltaTime
	end

	local CaptureTime = gamemode.script.Settings.CaptureTime.Value
	self.CurrentTime = math.max(self.CurrentTime, 0)
	self.CurrentTime = math.min(self.CurrentTime, CaptureTime)

	Result.Equip = false
	Result.Percentage = self.CurrentTime / CaptureTime
	if Result.Percentage == 1.0 then
		gamemode.script:TargetCaptured()
		Result.Message = "DataRetrieved"
	end
	return Result
end

function uplinktarget:OnReset()
	self.CurrentTime = 0.0
end

return uplinktarget