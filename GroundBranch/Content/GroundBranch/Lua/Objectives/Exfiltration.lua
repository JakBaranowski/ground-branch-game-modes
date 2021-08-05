local Exfiltration = {
	MessageBroker = nil,
	PromptBroker = nil,
    PlayersRequiredForExfil = 1,
    PlayersIn = 0,
    OnObjectiveCompleteFuncOwner = nil,
    OnObjectiveCompleteFunc = nil,
    TeamId = 1,
    ExfilTimer = {
        Name = 'ExfilTimer',
        DefaultTime = 5.0,
        CurrentTime = 5.0,
        TimeStep = 1.0,
    },
	PromptTimer = {
		Name = 'ExfilPromptTimer',
		ShowTime = 5.0,
		DelayTime = 15.0,
	},
    Points = {
        All = {},
        Active = nil,
        AllMarkers = {}
    },
}

Exfiltration.__index = Exfiltration

---comment
---@param messageBroker any
---@param promptBroker any
---@param onObjectiveCompleteFuncOwner any
---@param onObjectiveCompleteFunc any
---@param teamId any
---@param playerCountRequiredForExtraction any
---@param timeToExfil any
---@param timeStep any
---@return table Exfiltration
function Exfiltration:Create(
	messageBroker,
	promptBroker,
    onObjectiveCompleteFuncOwner,
    onObjectiveCompleteFunc,
    teamId,
	playerCountRequiredForExtraction,
    timeToExfil,
    timeStep
)
    local exfil = {}
    setmetatable(exfil, self)
    self.__index = self
	print('Initializing Objective Exfiltration ' .. tostring(exfil))
	self.MessageBroker = messageBroker
	self.PromptBroker = promptBroker
    self.OnObjectiveCompleteFuncOwner = onObjectiveCompleteFuncOwner
    self.OnObjectiveCompleteFunc = onObjectiveCompleteFunc
    self.TeamId = teamId or Exfiltration.TeamId
	self.PlayersRequiredForExfil = playerCountRequiredForExtraction or 1
	self.PlayersIn = 0
    self.ExfilTimer.CurrentTime = timeToExfil or Exfiltration.ExfilTimer.CurrentTime
    self.ExfilTimer.DefaultTime = timeToExfil or Exfiltration.ExfilTimer.DefaultTime
    self.ExfilTimer.TimeStep = timeStep or Exfiltration.ExfilTimer.TimeStep
    self.Points.All = gameplaystatics.GetAllActorsOfClass(
		'/Game/GroundBranch/Props/GameMode/BP_ExtractionPoint.BP_ExtractionPoint_C'
	)
    print('Found ' .. #self.Points.All .. ' extraction points')
    for i = 1, #self.Points.All do
		local Location = actor.GetLocation(self.Points.All[i])
		self.Points.AllMarkers[i] = gamemode.AddObjectiveMarker(
			Location,
			self.TeamId,
			'Extraction',
			false
		)
	end
	print('Added inactive objective markers for extraction points')
    return exfil
end

function Exfiltration:Reset()
	self.PlayersRequiredForExfil = 1
	self.PlayersIn = 0
end

function Exfiltration:SetPlayersRequiredForExfil(playersRequiredForExfil)
	self.PlayersRequiredForExfil = playersRequiredForExfil
end

function Exfiltration:SelectPoint(activeFromStart)
    local activeIndex = math.random(#self.Points.All)
    self.Points.Active = self.Points.All[activeIndex]
    for i = 1, #self.Points.All do
		local bActive = (i == activeIndex)
		print('Setting Exfil marker ' .. i .. ' to ' .. tostring(bActive))
		actor.SetActive(self.Points.All[i], false)
		actor.SetActive(self.Points.AllMarkers[i], bActive)
	end
    if activeFromStart then
        actor.SetActive(self.Points.Active, true)
    end
end

function Exfiltration:SelectedPointSetActive(active)
	actor.SetActive(self.Points.Active, active)
	print(self.PromptBroker)
	if self.PromptBroker ~= nil then
		timer.Set(
			self.PromptTimer.Name,
			self,
			self.GuideToExtractionTimer,
			self.PromptTimer.DelayTime,
			true
		)
	end
end

function Exfiltration:GetActivePoint()
	return self.Points.Active
end

function Exfiltration:GuideToExtractionTimer()
	self.PromptBroker:Display(
		'Extraction',
		self.PromptTimer.ShowTime,
		actor.GetLocation(self.Points.Active)
	)
end

function Exfiltration:CheckTriggerAndPlayer(trigger, playerIn)
    if trigger == self.Points.Active then
        local playerCharacter = player.GetCharacter(playerIn)
        if playerCharacter ~= nil then
            local teamId = actor.GetTeamId(playerCharacter)
            if teamId == self.TeamId then
                return true
            end
        end
    end
    return false
end

function Exfiltration:PlayerEnteredExfiltration(exfilCondition)
	self.PlayersIn = self.PlayersIn + 1
	if exfilCondition then
		self:CheckBluForExfilTimer()
	end
end

function Exfiltration:PlayerLeftExfiltration()
	local total = math.max(self.PlayersIn - 1, 0)
	self.PlayersIn = total
end

function Exfiltration:CheckBluForExfilTimer()
	if self.ExfilTimer.CurrentTime <= 0 then
		self.OnObjectiveCompleteFunc(self.OnObjectiveCompleteFuncOwner)
		timer.Clear(self, self.ExfilTimer.Name)
		self.ExfilTimer.CurrentTime = self.ExfilTimer.DefaultTime
		return
	end
	if self.PlayersIn <= 0 then
		if self.MessageBroker then
			self.MessageBroker:Display('ExfilCancelled', self.ExfilTimer.TimeStep*2)
		end
		self.ExfilTimer.CurrentTime = self.ExfilTimer.DefaultTime
		return
	elseif self.PlayersIn < self.PlayersRequiredForExfil then
		if self.MessageBroker then
			self.MessageBroker:Display('ExfilPaused', self.ExfilTimer.TimeStep-0.05)
		end
	else
		if self.MessageBroker then
			self.MessageBroker:Display(
				'ExfilInProgress_'..math.floor(self.ExfilTimer.CurrentTime),
				self.ExfilTimer.TimeStep-0.05
			)
		end
		self.ExfilTimer.CurrentTime = self.ExfilTimer.CurrentTime - self.ExfilTimer.TimeStep
	end
	timer.Set(
		self.ExfilTimer.Name,
		self,
		self.CheckBluForExfilTimer,
		self.ExfilTimer.TimeStep,
		false
	)
end

return Exfiltration
