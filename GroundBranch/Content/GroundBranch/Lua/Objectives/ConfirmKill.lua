local Actors = require('Common.Actors')
local Tables = require('Common.Tables')

local ConfirmKill = {
    OnObjectiveCompleteFuncOwner = nil,
    OnObjectiveCompleteFunc = nil,
    Team = {},
    HVT = {
        Count = 1,
        Tag = 'HVT',
        Spawns = {},
        Markers = {},
        SpawnsShuffled = {},
        EliminatedNotConfirmedLocations = {},
        EliminatedNotConfirmedCount = 0,
        EliminatedAndConfirmedCount = 0
    },
    ObjectiveTimer = {
        Name = 'KillConfirmTimer',
        TimeStep = {
            Max = 1.0,
            Min = 0.1,
            Value = 1.0
        }
    },
    PromptTimer = {
        Name = 'KillConfirmedPromptTimer',
        ShowTime = 5.0,
        DelayTime = 15.0
    }
}

---Creates a new object of type Objectives Kill Confirmation. This prototype can be
---used for setting up and tracking an Kill Confirmation objective for a specific team.
---Kill Confirmation requires players to kill selected targets (HVTs), and confirm
---the HVT kills by walking over HVTs bodies.
---If messageBroker is provided will display objective related messages to players.
---If promptBroker is provided will display objective prompts to players.
---@param onObjectiveCompleteFuncOwner table The object owning function to be run when the objective is completed.
---@param onObjectiveCompleteFunc function Function to be run when the objective is completed.
---@param team table the team object of the eligible team.
---@param hvtTag string Tag assigned to HVT spawn points in mission editor. Used to find HVT spawn points.
---@param hvtCount integer How many HVTs are in play.
---@return table ConfirmKill The newly created ConfirmKill object.
function ConfirmKill:Create(
    onObjectiveCompleteFuncOwner,
    onObjectiveCompleteFunc,
    team,
    hvtTag,
    hvtCount
)
    local killConfirmation = {}
    setmetatable(killConfirmation, self)
    self.__index = self
    self.OnObjectiveCompleteFuncOwner = onObjectiveCompleteFuncOwner
    self.OnObjectiveCompleteFunc = onObjectiveCompleteFunc
    self.Team = team
    self.HVT.Count = hvtCount or 1
    self.HVT.Tag = hvtTag or 'HVT'
    self.HVT.Spawns = gameplaystatics.GetAllActorsOfClassWithTag(
		'GroundBranch.GBAISpawnPoint',
		self.HVT.Tag
	)
	print('Found ' .. #self.HVT.Spawns .. ' ' .. self.HVT.Tag .. ' spawns')
    print('Adding inactive objective markers for ' .. self.HVT.Tag)
    for _, Spawn in ipairs(self.HVT.Spawns) do
		local description = self.HVT.Tag
		description = Actors.GetSuffixFromActorTag(Spawn, 'ObjectiveMarker')
		self.HVT.Markers[description] = gamemode.AddObjectiveMarker(
			actor.GetLocation(Spawn),
			self.Team:GetId(),
			description,
			false
		)
	end
    self.HVT.SpawnsShuffled = {}
    self.HVT.EliminatedNotConfirmedLocations = {}
    self.HVT.EliminatedNotConfirmedCount = 0
    self.HVT.EliminatedAndConfirmedCount = 0
    print('Intialized Objective Kill Confirmation ' .. tostring(killConfirmation))
    return killConfirmation
end

---Resets the object attributes to default values. Should be called before every round.
function ConfirmKill:Reset()
    self.HVT.EliminatedNotConfirmedLocations = {}
	self.HVT.EliminatedNotConfirmedCount = 0
	self.HVT.EliminatedAndConfirmedCount = 0
end

---Shuffle HVT spawn order. Should be called before every round.
function ConfirmKill:ShuffleSpawns()
    print('Shuffling ' .. self.HVT.Tag ..  ' spawns')
	self.HVT.SpawnsShuffled = Tables.ShuffleTable(
		self.HVT.Spawns
	)
    print('Setting up ' .. self.HVT.Tag .. ' objective markers ' ..self.HVT.Count)
	for index, spawn in ipairs(self.HVT.SpawnsShuffled) do
		local spawnTag = Actors.GetSuffixFromActorTag(spawn, 'ObjectiveMarker')
		local bActive = index <= self.HVT.Count
		print('Setting HVT marker ' .. spawnTag .. ' to ' .. tostring(bActive))
		actor.SetActive(self.HVT.Markers[spawnTag], bActive)
	end
end

---Spawns the specified amount of HVTs at the shuffled spawn points.
---@param duration number time over whch the ai should be spawned.
function ConfirmKill:Spawn(duration)
    print('Spawning ' .. self.HVT.Tag)
    ai.CreateOverDuration(
		duration,
		self.HVT.Count,
		self:PopShuffledSpawnPoints(),
		self.HVT.Tag
	)
    timer.Set('CheckSpawnsTimer', self, self.checkSpawnsTimer, duration + 0.1, false)
end

---Makes sure that the HVT count is equal to the HVT ai controllers count.
function ConfirmKill:checkSpawnsTimer()
    local hvtControllers = ai.GetControllers(
        'GroundBranch.GBAIController',
        self.HVT.Tag,
        255,
        255
    )
    if self.HVT.Count ~= #hvtControllers then
        print('HVT count is not equal to HVT ai controllers count, adjusting HVT count')
        self.HVT.Count = #hvtControllers
    end
end

---Updates objective tracking variables. If the GameMessageBroker was provided
---at object creation, displays a message to the players. If the WorldPromptBroker
---was provided at object creation, displays a message to the players. Should be
---called whenever an HVT is eliminated.
---@param hvt userdata Character of the neutralized HVT.
function ConfirmKill:Neutralized(hvt, killer)
    print('OpFor HVT eliminated')
    self.Team:DisplayMessageToAlivePlayers('HVTEliminated', 'Upper', 5.0, 'ObjectiveMessage')
    timer.Set(
        self.PromptTimer.Name,
        self,
        self.GuideToObjectiveTimer,
        self.PromptTimer.DelayTime,
        true
    )
    self.Team:ChangeScore(killer, 'HVTNeutralized', 250)
    table.insert(
        self.HVT.EliminatedNotConfirmedLocations,
        actor.GetLocation(hvt)
    )
    self.HVT.EliminatedNotConfirmedCount =
        self.HVT.EliminatedNotConfirmedCount + 1
    self:ShouldConfirmKillTimer()
end

---Used to display world prompt guiding players to the neutralized HVT for confirming
---the kill.
function ConfirmKill:GuideToObjectiveTimer()
    for _, leaderLocation in ipairs(self.HVT.EliminatedNotConfirmedLocations) do
        self.Team:DisplayPromptToAlivePlayers(
            leaderLocation,
            'ConfirmKill',
            self.PromptTimer.ShowTime,
            'ObjectivePrompt'
        )
    end
end

---Checks if any player is in range of the neutralized HVT in order to confirm the
---kill. If player is in range, will confirm the kill. If no player is in range,
---will find distance from neutralized HVT to closest players, and based on that
---distance determine how much time until next check.
function ConfirmKill:ShouldConfirmKillTimer()
	if self.HVT.EliminatedNotConfirmedCount <= 0 then
        timer.Clear(self, self.PromptTimer.Name)
		return
	end
	local LowestDist = self.ObjectiveTimer.TimeStep.Max * 1000.0
	for leaderIndex, leaderLocation in ipairs(self.HVT.EliminatedNotConfirmedLocations) do
		for _, playerController in ipairs(self.Team:GetAlivePlayers()) do
			local playerLocation = actor.GetLocation(
				player.GetCharacter(playerController)
			)
			local DistVector = playerLocation - leaderLocation
			local Dist = vector.Size(DistVector)
			LowestDist = math.min(LowestDist, Dist)
			if Dist <= 250 and math.abs(DistVector.z) < 110 then
                self:ConfirmKill(leaderIndex, playerController)
			end
		end
	end
	self.ObjectiveTimer.TimeStep.Value = math.max(
		math.min(
			LowestDist/1000,
			self.ObjectiveTimer.TimeStep.Max
		),
		self.ObjectiveTimer.TimeStep.Min
	)
	timer.Set(
		self.ObjectiveTimer.Name,
		self,
		self.ShouldConfirmKillTimer,
		self.ObjectiveTimer.TimeStep.Value,
		false
	)
end

---Confirms the kill and updates objective tracking variables.
---@param leaderIndex integer index of the leader location in table EliminatedNotConfirmedLocations that was confirmed.
function ConfirmKill:ConfirmKill(leaderIndex, confirmer)
    table.remove(self.HVT.EliminatedNotConfirmedLocations, leaderIndex)
    self.HVT.EliminatedNotConfirmedCount = #self.HVT.EliminatedNotConfirmedLocations
    self.HVT.EliminatedAndConfirmedCount = self.HVT.EliminatedAndConfirmedCount + 1
    self.Team:ChangeScore(confirmer, 'KillConfirmed', 750)
    if self:AreAllConfirmed() then
		print('All HVT kills confirmed')
        self.Team:DisplayMessageToAlivePlayers('HVTConfirmedAll', 'Upper', 5.0, 'ObjectiveMessage')
        self.OnObjectiveCompleteFunc(self.OnObjectiveCompleteFuncOwner)
	else
        self.Team:DisplayMessageToAlivePlayers('HVTConfirmed', 'Upper', 5.0, 'ObjectiveMessage')
	end
end

---Sets the HVT count.
---@param count integer Desired HVT count.
function ConfirmKill:SetHvtCount(count)
    if count > #self.HVT.Spawns then
        self.HVT.Count = #self.HVT.Spawns
    else
        self.HVT.Count = count
    end
end

---Gets the current HVT count.
---@return integer hvtCount Current HVT count.
function ConfirmKill:GetHvtCount()
    return self.HVT.Count
end

---Returns true if all HVTs are neutralized, false otherwise.
---@return boolean areAllNeutralized
function ConfirmKill:AreAllNeutralized()
    return self.HVT.EliminatedNotConfirmedCount >= self.HVT.Count
end

---Returns true if all HVT kill are confirmed, false otherwise.
---@return boolean areAllConfirmed
function ConfirmKill:AreAllConfirmed()
    return self.HVT.EliminatedAndConfirmedCount >= self.HVT.Count
end

---Returns all spawn points count.
---@return integer allSpawnPointsCount
function ConfirmKill:GetAllSpawnPointsCount()
    return #self.HVT.Spawns
end

---Returns a table of shuffled spawn points.
---@return table shuffledSpawnPoints list of shuffled spawn points.
function ConfirmKill:GetShuffledSpawnPoints()
    return {table.unpack(self.HVT.SpawnsShuffled)}
end

---Returns the spawn point specified by the index in the shuffled spawn points table.
---@param index integer index of the spawn point in the shuffled spawn points table.
---@return userdata spawnPoint
function ConfirmKill:GetShuffledSpawnPoint(index)
    return self.HVT.SpawnsShuffled[index]
end

---Returns a copy of shuffled spawn points table, and empties the original shuffled
---spawn points table.
---@return table
function ConfirmKill:PopShuffledSpawnPoints()
    print('Poping ' .. self.HVT.Tag .. ' spawns')
    local hvtSpawns = self:GetShuffledSpawnPoints()
    self.HVT.SpawnsShuffled = {}
    return hvtSpawns
end

return ConfirmKill
