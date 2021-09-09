local Tables = {}

Tables.__index = Tables

---Returns a copy of the provided table with shuffled entries.
---@param orderedTable table an ordered table that we want to shuffle.
---@return table shuffledTable a copy of the provdide table with shuffled entries.
function Tables.ShuffleTable(orderedTable)
    local tempTable = {table.unpack(orderedTable)}
    local shuffledTable = {}
    for i = #tempTable, 1, -1 do
        local j = math.random(i)
        tempTable[i], tempTable[j] = tempTable[j], tempTable[i]
        table.insert(shuffledTable, tempTable[i])
    end
    return shuffledTable
end

---Takes an ordered table containing ordered tables and returns an ordered table
---of shuffled tables.
---@param tableWithOrderedTables table ordered table with ordered tables.
---@return table tableWithShuffledTables ordered table with shuffled tables.
function Tables.ShuffleTables(tableWithOrderedTables)
    local tempTable = {table.unpack(tableWithOrderedTables)}
    local tableWithShuffledTables = {}
    for orderedTableIndex, orderedTable in ipairs(tempTable) do
        tableWithShuffledTables[orderedTableIndex] = Tables.ShuffleTable(
            orderedTable
        )
    end
    return tableWithShuffledTables
end

---Returns a single level indexed table containing all entries from 2nd level
---tables of the provided twoLevelTable.
---@param twoLevelTable table a table of tables.
---@return table singleLevelTable a single level table with all 2nd level table entries.
function Tables.GetTableFromTables(twoLevelTable)
    local tempTable = {table.unpack(twoLevelTable)}
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
---Only supports concatenation of two indexed tables, not key-value tables.
---@param table1 table first of the two tables to join.
---@param table2 table second of the two tables to join.
---@return table concatenatedTable concatenated table.
function Tables.ConcatenateTables(table1, table2)
    local concatenatedTable = {table.unpack(table1)}
    for _, value in ipairs(table2) do
       table.insert(concatenatedTable, value)
    end
    return concatenatedTable
end

function Tables.Index(table, value)
    for index, v in ipairs(table) do
        if v == value then
            return index
        end
    end
    return nil
end

return Tables
