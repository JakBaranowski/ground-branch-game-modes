local flag = {
}

function flag:ServerUse(User)
	GetLuaComp(self.actor).PickUp(User)
end

function flag:OnReset()
end

return flag