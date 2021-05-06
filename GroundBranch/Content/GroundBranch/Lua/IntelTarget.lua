local laptop = {
	CurrentTime = 0,
}

function laptop:ServerUseTimer(User, DeltaTime)
	self.CurrentTime = self.CurrentTime + DeltaTime
	local SearchTime = gamemode.GetScript().SearchTime
	self.CurrentTime = math.max(self.CurrentTime, 0)
	self.CurrentTime = math.min(self.CurrentTime, SearchTime)

	local Result = {}
	Result.Message = "IntelSearch"
	Result.Equip = false
	Result.Percentage = self.CurrentTime / SearchTime
	if Result.Percentage == 1.0 then
		if actor.HasTag(self.Object, gamemode.GetScript().LaptopTag) then
			Result.Equip = true
		else
			Result.Message = "IntelNotFound"
		end
	end
	return Result
end

function laptop:OnReset()
	self.CurrentTime = 0
end

function laptop:CarriedLaptopDestroyed()
	if actor.HasTag(self.Object, gamemode.GetScript().LaptopTag) then
		if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
			gamemode.BroadcastGameMessage("LaptopDestroyed", 10.0)
		end
	end
end

return laptop