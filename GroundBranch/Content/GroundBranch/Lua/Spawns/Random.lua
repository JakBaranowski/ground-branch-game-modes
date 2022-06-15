local Tables = require('Common.Tables')

local Random = {
    Spawns = {},
    Total = 0,
    Selected = {}
}

Random.__index = Random

---Creates new Random spawns object.
---@return table Random Newly created Random spawns object.
function Random:Create()
    local self = setmetatable({}, Random)
    self.Spawns = {}
    self.Spawns = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAISpawnPoint')
    self.Total = #self.Spawns
    print('Found ' .. self.Total .. ' spawns')
    print('Initialized RandomSpawns ' .. tostring(self))
    return self
end

---Removes AI spawn points with the provided tagToExclude from Selected spawns table.
---@param tagToExclude string spawn points with this tag will be excluded from the spawn points list.
function Random:ExcludeSpawnsWithTag(tagToExclude)
    for i = #self.Spawns, 1, -1 do
        local tags = actor.GetTags(self.Spawns[i])
        for _, tag in ipairs(tags) do
            if tag == tagToExclude then
                table.remove(self.Spawns, i)
                break
            end
        end
    end
end

---Selects random spawn points.
function Random:SelectSpawnPoints()
    self.Selected = Tables.ShuffleTable(self.Spawns)
end

---Spawns AI in the selected spawn points.
---@param duration number The time over which the AI will be spawned.
---@param count integer The amount of the AI to spawn.
---@param spawnTag string The tag that will be assigned to spawned AI.
function Random:Spawn(duration, count, spawnTag)
    if count > #self.Selected then
        count = #self.Selected
    end
	ai.CreateOverDuration(
		duration,
		count,
		self:PopSelectedSpawnPoints(),
		spawnTag
	)
end

return Random
