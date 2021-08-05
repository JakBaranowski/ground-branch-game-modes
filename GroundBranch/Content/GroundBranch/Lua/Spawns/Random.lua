local Tables = require('Common.Tables')

local Random = {
    Spawns = {},
    Total = 0,
    Selected = {}
}

Random.__index = Random

function Random:Create()
    local random = {}
    setmetatable(random, self)
    self.__index = self
    print('Initialized RandomSpawns ' .. tostring(self))
    return random
end

---Gathers all AI spawn points.
function Random:GatherSpawnPoints()
    self.Spawns = {}
    self.Spawns = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAISpawnPoint')
    self.Total = #self.Spawns
    print('Found ' .. self.Total .. ' spawns')
end

---Removes AI spawn points with the provided tagToExclude from Selected spawns table.
---@param tagToExclude string
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

return Random
