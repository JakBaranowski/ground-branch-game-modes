local MyGameMode = {
}

MyGameMode.__index = MyGameMode

function MyGameMode:new()
	local self = {}
	setmetatable(self, MyGameMode)
	return self
end

function MyGameMode:PostRun()
	local AllPlayerStarts = GS.GetAllActorsOfClass('GroundBranch.GBPlayerStart')
	
	SetGameRule("UseReadyRoom", "true")
	SetGameRule("UseRounds", "false")
end

function MyGameMode:PlayerGameModeRequest(PlayerState, Request)
	if PlayerState ~= nil then
		if Command == "join"  then
			EnterPlayArea(PlayerState)
		end
	end
end

return MyGameMode
