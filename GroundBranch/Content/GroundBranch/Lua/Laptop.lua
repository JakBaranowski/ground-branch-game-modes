local laptop = {
	CurrentTime = 0,
}

function laptop:ServerUseTimer(User, DeltaTime)
	self.CurrentTime = self.CurrentTime + DeltaTime
	--local SearchTime = gamemode.script.Settings.SearchTime.Value
	local SearchTime = 10.0
	self.CurrentTime = math.max(self.CurrentTime, 0)
	self.CurrentTime = math.min(self.CurrentTime, SearchTime)

	local Result = {}
	Result.Message = "Hello World"
	Result.Equip = false
	Result.Percentage = self.CurrentTime / SearchTime
	if Result.Percentage == 1.0 then
		Result.Message = "100 percent"
	elseif Result.Percentage == 0.0 then
		Result.Message = "0 percent"
		--[[	
		if actor.HasTag(self.Object, gamemode.script.LaptopTag) then
			Result.Message = "IntelFound"
			Result.Equip = true
		else
			Result.Message = "IntelNotFound"
		end
		]]
	end
	return Result
end

function laptop:OnReset()
	self.CurrentTime = 0
end

function laptop:CarriedLaptopDestroyed()
	--[[
	if actor.HasTag(self.Object, gamemode.script.LaptopTag) then
		if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
			gamemode.BroadcastGameMessage("LaptopDestroyed", "Center", 10.0)
		end
	end
	]]
end

return laptop