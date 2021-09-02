local Exfiltrate = {
    PlayersRequiredForExfil = 1,
    PlayersIn = 0,
    OnObjectiveCompleteFuncOwner = nil,
    OnObjectiveCompleteFunc = nil,
    Team = 1,
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

---Creates a new object of type Objectives Exfiltrate. This prototype can be
---used for setting up and tracking an exifltration objective for a specific team.
---If messageBroker is provided will display objective related messages to players.
---If promptBroker is provided will display objective prompts to players.
---@param onObjectiveCompleteFuncOwner table The object owning function to be run when the objective is completed.
---@param onObjectiveCompleteFunc function Function to be run when the objective is completed.
---@param team table the team object of the eligible team.
---@param playerCountRequiredForExtraction integer How many players have to be in extraction zone for exfiltration to start.
---@param timeToExfil number How long the exfiltration should take.
---@param timeStep number How much time should pass between each exfiltration check.
---@return table Exfiltrate The newly created Exfiltrate object.
function Exfiltrate:Create(
    onObjectiveCompleteFuncOwner,
    onObjectiveCompleteFunc,
    team,
	playerCountRequiredForExtraction,
    timeToExfil,
    timeStep
)
    local exfiltration = {}
    setmetatable(exfiltration, self)
    self.__index = self
    self.OnObjectiveCompleteFuncOwner = onObjectiveCompleteFuncOwner
    self.OnObjectiveCompleteFunc = onObjectiveCompleteFunc
    self.Team = team
	self.PlayersRequiredForExfil = playerCountRequiredForExtraction or 1
	self.PlayersIn = 0
    self.ExfilTimer.CurrentTime = timeToExfil or Exfiltrate.ExfilTimer.CurrentTime
    self.ExfilTimer.DefaultTime = timeToExfil or Exfiltrate.ExfilTimer.DefaultTime
    self.ExfilTimer.TimeStep = timeStep or Exfiltrate.ExfilTimer.TimeStep
    self.Points.All = gameplaystatics.GetAllActorsOfClass(
		'/Game/GroundBranch/Props/GameMode/BP_ExtractionPoint.BP_ExtractionPoint_C'
	)
    print('Found ' .. #self.Points.All .. ' extraction points')
    for i = 1, #self.Points.All do
		local Location = actor.GetLocation(self.Points.All[i])
		self.Points.AllMarkers[i] = gamemode.AddObjectiveMarker(
			Location,
			self.Team:GetId(),
			'Extraction',
			false
		)
	end
	print('Added inactive objective markers for extraction points')
	print('Initialized Objective Exfiltrate ' .. tostring(exfiltration))
    return exfiltration
end

---Resets the object attributes to default values. Should be called before every round.
function Exfiltrate:Reset()
	self.PlayersRequiredForExfil = 1
	self.PlayersIn = 0
end

---Sets the amount of players that need to be in extraction zone for the the
---exfiltration to start.
---@param playersRequiredForExfil integer How many players have to be in extraction zone for exfiltration to start.
function Exfiltrate:SetPlayersRequiredForExfil(playersRequiredForExfil)
	self.PlayersRequiredForExfil = playersRequiredForExfil
end

---Randomly selects the extraction point that should be active in the given round.
---If activeFromStart parameter is set to false, the extration point will not be
---active, and Exfiltrate:SelectedPointSetActive should be called to activate it
---when needed.
---@param activeFromStart boolean Should the selected extraction point be active from round start.
function Exfiltrate:SelectPoint(activeFromStart)
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

---Sets the selected point active state.
---@param active boolean should the point be active.
function Exfiltrate:SelectedPointSetActive(active)
	actor.SetActive(self.Points.Active, active)
	timer.Set(
		self.PromptTimer.Name,
		self,
		self.GuideToExtractionTimer,
		self.PromptTimer.DelayTime,
		true
	)
end

---Returns the selected extraction point.
---@return userdata ExtractionPoint the selected extraction point.
function Exfiltrate:GetSelectedPoint()
	return self.Points.Active
end

---Displays a world prompt at the extraction zone.
function Exfiltrate:GuideToExtractionTimer()
	self.Team:DisplayPrompt(
		'Extraction',
		self.PromptTimer.ShowTime,
		actor.GetLocation(self.Points.Active)
	)
end

---Checks if the trigger is the selected extraction zone, and that the player
---is part of the team assigned to this extraction point.
---@param trigger userdata the game trigger that the player entered.
---@param playerIn userdata the player that entered the game trigger.
---@return boolean enteredOwnZone true if player entered theirs extraction zone, false otherwise.
function Exfiltrate:CheckTriggerAndPlayer(trigger, playerIn)
    if trigger == self.Points.Active then
        local playerCharacter = player.GetCharacter(playerIn)
        if playerCharacter ~= nil then
            return true
        end
    end
    return false
end

---Updates the player in extraction zone count when player enters extraction zone
---and, if the exfilCondition is true, starts the exfiltration check timer.
---@param exfilCondition boolean whether or not exfiltration should be possible at the moment.
function Exfiltrate:PlayerEnteredExfiltration(exfilCondition)
	self.PlayersIn = self.PlayersIn + 1
	if exfilCondition then
		self:CheckExfilTimer()
	end
end

---Updates the player in extraction zone count when player leaves extraction zone.
function Exfiltrate:PlayerLeftExfiltration()
	local total = math.max(self.PlayersIn - 1, 0)
	self.PlayersIn = total
end

---Checks how many players are in the extraction zone and based on the result:
---* if players in zone count is equal or bigger then required count
---will count down time to exfiltration,
---* if playres in zone count is bigger than 0 but lower then required count
---pauses the timer, or
---* if there are no players in the extraction zone
---cancels the exfiltration.
------
---If GameMessageBroker was provided for the object this method will display 
---messages informng the players on exfiltration status.
function Exfiltrate:CheckExfilTimer()
	if self.ExfilTimer.CurrentTime <= 0 then
		self.OnObjectiveCompleteFunc(self.OnObjectiveCompleteFuncOwner)
		timer.Clear(self, self.ExfilTimer.Name)
		self.ExfilTimer.CurrentTime = self.ExfilTimer.DefaultTime
		return
	end
	if self.PlayersIn <= 0 then
		self.Team:DisplayMessage('ExfilCancelled', self.ExfilTimer.TimeStep*2, 'Upper')
		self.ExfilTimer.CurrentTime = self.ExfilTimer.DefaultTime
		return
	elseif self.PlayersIn < self.PlayersRequiredForExfil then
		self.Team:DisplayMessage('ExfilPaused', self.ExfilTimer.TimeStep-0.05, 'Upper')
	else
		self.Team:DisplayMessage(
			'ExfilInProgress_'..math.floor(self.ExfilTimer.CurrentTime),
			self.ExfilTimer.TimeStep-0.05,
			'Upper'
		)
		self.ExfilTimer.CurrentTime = self.ExfilTimer.CurrentTime - self.ExfilTimer.TimeStep
	end
	timer.Set(
		self.ExfilTimer.Name,
		self,
		self.CheckExfilTimer,
		self.ExfilTimer.TimeStep,
		false
	)
end

return Exfiltrate
