local math = require("math")

local TableOperations = {}

TableOperations.__index = TableOperations

---Returns a table with shuffled entries of the provided ordered table
---@param orderedTable table
---@return table
function TableOperations.ShuffleTable(orderedTable)
    local tempTable = {table.unpack(orderedTable)}
    local shuffledTable = {}
    for i = #tempTable, 1, -1 do
        local j = math.random(i)
        tempTable[i], tempTable[j] = tempTable[j], tempTable[i]
        table.insert(shuffledTable, tempTable[i])
    end
    return shuffledTable
end

---Takes an ordered table containing ordered tables and returns an ordered table of
---shuffled tables.
---@param tableWithOrderedTables table
---@return table
function TableOperations.ShuffleTables(tableWithOrderedTables)
    local tempTable = {table.unpack(tableWithOrderedTables)}
    local tableWithShuffledTables = {}
    for orderedTableIndex, orderedTable in ipairs(tempTable) do
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
    local tempTable = {table.unpack(twoLevelsTable)}
    local singleLevelTable = {}
    for _, secondLevelTable in ipairs(tempTable) do
        for _, entry in ipairs(secondLevelTable) do
            table.insert(singleLevelTable, entry)
        end
    end
    return singleLevelTable
end

---Concatenates two indexed tables. It keeps the order provided in argument,
---i.e. elements of table1 will start at first index, and elements of table2
---will start at #table1+1.
---Only supports concatenation of two indexed tables (not key, value tables).
---@param table1 table
---@param table2 table
---@return table
function TableOperations.ConcatenateTables(table1, table2)
    local concatenatedTable = {table.unpack(table1)}
    for _, value in ipairs(table2) do
       table.insert(concatenatedTable, value)
    end
    return concatenatedTable
end

return TableOperations
