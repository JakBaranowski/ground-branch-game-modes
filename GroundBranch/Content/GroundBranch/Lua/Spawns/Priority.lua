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
---@return table
function Priority:Create()
    local priority = {}
    setmetatable(priority, self)
    self.__index = self
	print('Initialized PrioritySpawns ' .. tostring(self))
    return priority
end

---Gathers all AI spawn points with a priority tag, and groups them by priority.
function Priority:GatherSpawnPoints()
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
	print(
		'Found ' .. self.Total ..
		' spawns by priority'
	)
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

return Priority
