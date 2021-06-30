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
function TableOperations.ShuffleKeyValueTables(tableWithOrderedTables)
    local tableWithShuffledTables = {}
    for orderedTableKey, orderedTable in pairs(tableWithOrderedTables) do
        tableWithShuffledTables[orderedTableKey] = TableOperations.ShuffleTable(
            orderedTable
        )
    end
    return tableWithShuffledTables
end

---Takes an 2 level table and returns a single level table containing entries from
---all 2nd level tables
---@param twoLevelsTable table
---@return table
function TableOperations.GetTableFromKeyValueTables(twoLevelsTable)
    local singleLevelTable = {}
    for _, secondLevelTable in pairs(twoLevelsTable) do
        for _, entry in ipairs(secondLevelTable) do
            table.insert(singleLevelTable, entry)
        end
    end
    return singleLevelTable
end

---Takes an ordered table containing ordered tables and returns an ordered table off
---shuffled tables.
---@param tableWithOrderedTables table
---@return table
function TableOperations.ShuffleIndexedTables(tableWithOrderedTables)
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
function TableOperations.GetTableFromIndexedTables(twoLevelsTable)
    local singleLevelTable = {}
    for _, secondLevelTable in ipairs(twoLevelsTable) do
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
