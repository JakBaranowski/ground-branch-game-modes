local math = require("math")

local TableOperations = {}

TableOperations.__index = TableOperations

---Returns a table with shuffled entries of the provided ordered table
---@param orderedTable table
---@return table
function TableOperations.ShuffleTable(orderedTable)
    local shuffledTable = {}
    for i = #orderedTable, 1, -1 do
        local j = math.random(i)
        orderedTable[i], orderedTable[j] = orderedTable[j], orderedTable[i]
        table.insert(shuffledTable, orderedTable[i])
    end
    return shuffledTable
end

---Takes an ordered table containing ordered tables and returns an ordered table off
---shuffled tables.
---@param tableWithOrderedTables table
---@return table
function TableOperations.ShuffleTables(tableWithOrderedTables)
    local tableWithShuffledTables = {}
    for orderedTableIndex, orderedTable in ipairs(tableWithOrderedTables) do
        tableWithShuffledTables[orderedTableIndex] = TableOperations.ShuffleTable(
            orderedTable
        )
    end
    return tableWithShuffledTables
end

---Takes an 2 level table and returns a single level table containing entries from
---all 2nd level tables
---@param twoLevelsTable table
---@return table
function TableOperations.GetTableFromTables(twoLevelsTable)
    local singleLevelTable = {}
    for _, secondLevelTable in ipairs(twoLevelsTable) do
        for _, entry in ipairs(secondLevelTable) do
            table.insert(singleLevelTable, entry)
        end
    end
    return singleLevelTable
end

return TableOperations
