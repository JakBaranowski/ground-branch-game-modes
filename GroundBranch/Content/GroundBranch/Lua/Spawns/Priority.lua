local Tables = require('Common.Tables')

local Priority = {
    Spawns = {},
    Total = 0,
    Tags = {
        'AISpawn_1', 'AISpawn_2', 'AISpawn_3', 'AISpawn_4', 'AISpawn_5',
        'AISpawn_6_10', 'AISpawn_11_20', 'AISpawn_21_30', 'AISpawn_31_40',
        'AISpawn_41_50'
    },
    Selected = {}
}

Priority.__index = Priority

---Creates new Priority spawns object.
---@return table Priority Newly created Priority spawns object.
function Priority:Create()
    local self = setmetatable({}, Priority)
	self.Spawns = {}
	local priorityIndex = 1
	for _, priorityTag in ipairs(self.Tags) do
		local spawnsWithTag = gameplaystatics.GetAllActorsOfClassWithTag(
			'GroundBranch.GBAISpawnPoint',
			priorityTag
		)
		if #spawnsWithTag > 0 then
			self.Spawns[priorityIndex] = spawnsWithTag
			self.Total = self.Total + #spawnsWithTag
			priorityIndex = priorityIndex + 1
		end
	end
	print('Found ' .. self.Total .. ' spawns by priority')
	print('Initialized PrioritySpawns ' .. tostring(self))
    return self
end

---Shuffles priority grouped spawns. Ensures spawns of higher priority will be
---selected before lower priority.
function Priority:SelectSpawnPoints()
    local tableWithShuffledSpawns = Tables.ShuffleTables(
		self.Spawns
	)
	self.Selected = Tables.GetTableFromTables(
		tableWithShuffledSpawns
	)
end

---Spawns AI in the selected spawn points.
---@param duration number The time over which the AI will be spawned.
---@param count integer The amount of the AI to spawn.
---@param spawnTag string The tag that will be assigned to spawned AI.
function Priority:Spawn(duration, count, spawnTag)
    if count == nil or count > #self.Selected then
        count = #self.Selected
    end
	ai.CreateOverDuration(
		duration,
		count,
		self.Selected,
		spawnTag
	)
end

return Priority
