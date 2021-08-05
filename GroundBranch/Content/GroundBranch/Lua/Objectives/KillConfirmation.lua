local Actors = require('Common.Actors')
local Tables = require('Common.Tables')

local KillConfirmation = {
    MessageBroker = nil,
    PromptBroker = nil,
    OnObjectiveCompleteFuncOwner = nil,
    OnObjectiveCompleteFunc = nil,
    TeamId = 1,
    PlayersWithLives = {},
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

KillConfirmation.__index = KillConfirmation

function KillConfirmation:Create(
    messageBroker,
    promptBroker,
    onObjectiveCompleteFuncOwner,
    onObjectiveCompleteFunc,
    playersWithLives,
    hvtTag,
    teamId,
    hvtCount
)
    local kc = {}
    setmetatable(kc, self)
    self.__index = self
    print('Intializing Objective Kill Confirmation ' .. tostring(kc))
    self.MessageBroker = messageBroker
    self.PromptBroker = promptBroker
    self.OnObjectiveCompleteFuncOwner = onObjectiveCompleteFuncOwner
    self.OnObjectiveCompleteFunc = onObjectiveCompleteFunc
    self.TeamId = teamId or 1
    self.PlayersWithLives = playersWithLives or {}
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
			self.TeamId,
			description,
			false
		)
	end
    self.HVT.SpawnsShuffled = {}
    self.HVT.EliminatedNotConfirmedLocations = {}
    self.HVT.EliminatedNotConfirmedCount = 0
    self.HVT.EliminatedAndConfirmedCount = 0
    return kc
end

function KillConfirmation:Reset()
    self.HVT.EliminatedNotConfirmedLocations = {}
	self.HVT.EliminatedNotConfirmedCount = 0
	self.HVT.EliminatedAndConfirmedCount = 0
end

function KillConfirmation:ShuffleSpawns()
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

function KillConfirmation:Spawn(duration)
    print('Spawning ' .. self.HVT.Tag)
    ai.CreateOverDuration(
		duration,
		self.HVT.Count,
		self:PopSelectedSpawnPoints(),
		self.HVT.Tag
	)
end

function KillConfirmation:Neutralized(character)
    print('OpFor HVT eliminated')
    if self.MessageBroker then
        self.MessageBroker:Display('HVTEliminated', 5.0)
    end
    print(self.PromptBroker)
    if self.PromptBroker ~= nil then
        timer.Set(
			self.PromptTimer.Name,
			self,
			self.GuideToObjectiveTimer,
			self.PromptTimer.DelayTime,
			true
		)
    end
    table.insert(
        self.HVT.EliminatedNotConfirmedLocations,
        actor.GetLocation(character)
    )
    self.HVT.EliminatedNotConfirmedCount =
        self.HVT.EliminatedNotConfirmedCount + 1
    self:CheckIfKillConfirmedTimer()
end

function KillConfirmation:GuideToObjectiveTimer()
    for _, leaderLocation in ipairs(self.HVT.EliminatedNotConfirmedLocations) do
        self.PromptBroker:Display(
            'ConfirmKill',
            self.PromptTimer.ShowTime,
            leaderLocation
        )
    end
end

function KillConfirmation:CheckIfKillConfirmedTimer()
	if self.HVT.EliminatedNotConfirmedCount <= 0 then
        timer.Clear(self, self.PromptTimer.Name)
		return
	end
	local LowestDist = self.ObjectiveTimer.TimeStep.Max * 1000.0
	for index, leaderLocation in ipairs(self.HVT.EliminatedNotConfirmedLocations) do
		for _, playerController in ipairs(self.PlayersWithLives) do
			local playerLocation = actor.GetLocation(
				player.GetCharacter(playerController)
			)
			local DistVector = playerLocation - leaderLocation
			local Dist = vector.Size(DistVector)
			LowestDist = math.min(LowestDist, Dist)
			if Dist <= 250 and math.abs(DistVector.z) < 110 then
                table.remove(self.HVT.EliminatedNotConfirmedLocations, index)
                self.HVT.EliminatedNotConfirmedCount = #self.HVT.EliminatedNotConfirmedLocations
                self.HVT.EliminatedAndConfirmedCount = self.HVT.EliminatedAndConfirmedCount + 1
                self:KillConfirmed()
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
		self.CheckIfKillConfirmedTimer,
		self.ObjectiveTimer.TimeStep.Value,
		false
	)
end

function KillConfirmation:KillConfirmed()
    if self:GetAllConfirmed() then
		print('All HVT kills confirmed')
        if self.MessageBroker then
            self.MessageBroker:Display('HVTConfirmedAll', 5.0)
        end
        self.OnObjectiveCompleteFunc(self.OnObjectiveCompleteFuncOwner)
	else
		print('HVT kill confirmed')
        if self.MessageBroker then
		    self.MessageBroker:Display('HVTConfirmed', 5.0)
        end
	end
end

--#region Getters and setters

function KillConfirmation:SetHvtCount(count)
    self.HVT.Count = count
end

function KillConfirmation:GetHvtCount()
    return self.HVT.Count
end

function KillConfirmation:SetPlayersWithLives(playersWithLives)
    self.PlayersWithLives = playersWithLives
end

function KillConfirmation:GetAllNeutralized()
    return self.HVT.EliminatedNotConfirmedCount >= self.HVT.Count
end

function KillConfirmation:GetAllConfirmed()
    return self.HVT.EliminatedAndConfirmedCount >= self.HVT.Count
end

function KillConfirmation:GetAllSpawnPointsCount()
    return #self.HVT.Spawns
end

function KillConfirmation:GetSelectedSpawnPoints()
    return {table.unpack(self.HVT.SpawnsShuffled)}
end

function KillConfirmation:GetSelectedSpawnPoint(index)
    return self.HVT.SpawnsShuffled[index]
end

function KillConfirmation:PopSelectedSpawnPoints()
    print('Poping ' .. self.HVT.Tag .. ' spawns')
    local hvtSpawns = self:GetSelectedSpawnPoints()
    self.HVT.SpawnsShuffled = {}
    return hvtSpawns
end

--#endregion

return KillConfirmation
