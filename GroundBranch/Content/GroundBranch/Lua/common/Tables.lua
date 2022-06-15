local Tables = {}

Tables.__index = Tables

---Returns a copy of the provided table with shuffled entries.
---@param orderedTable table an ordered table that we want to shuffle.
---@return table shuffledTable a copy of the provided table with shuffled entries.
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

function Tables.RemoveDuplicates(tableIn)
    print(tableIn)
    if tableIn == nil then
        return nil
    elseif #tableIn < 2 then
        return {table.unpack(tableIn)}
    end
    local hash = {}
    local tableOut = {}
    for _, v in ipairs(tableIn) do
        if not hash[v] then
            tableOut[#tableOut+1] = v
            hash[v] = true
        end
    end
    return tableOut
end

function Tables.Index(table, value)
    for index, v in ipairs(table) do
        if v == value then
            return index
        end
    end
    return nil
end

--[[
Table shallow copy and deep copy code adapted from Penlight's tablex <https://github.com/lunarmodules/Penlight>

Copyright (C) 2009-2016 Steve Donovan, David Manura.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT
SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
OR OTHER DEALINGS IN THE SOFTWARE.
]]--

local function complain (idx,msg)
    print("ERROR! Argument " .. idx .. " is not " + msg)
end

local function check_meta (val)
    if type(val) == 'table' then return true end
    return getmetatable(val)
end

local function types_is_iterable (val)
    local mt = check_meta(val)
    if mt == true then return true end
    return mt and mt.__pairs and true
end

local function assert_arg_iterable (idx,val)
    if not types_is_iterable(val) then
        complain(idx,"iterable")
    end
end

--- make a shallow copy of a table
--- @param tab table an iterable source
--- @return table new table
function Tables.Copy (t)
    assert_arg_iterable(1,t)
    local res = {}
    for k,v in pairs(t) do
        res[k] = v
    end
    return res
end

local function cycle_aware_copy(t, cache)
    if type(t) ~= 'table' then return t end
    if cache[t] then return cache[t] end
    assert_arg_iterable(1,t)
    local res = {}
    cache[t] = res
    local mt = getmetatable(t)
    for k,v in pairs(t) do
        k = cycle_aware_copy(k, cache)
        v = cycle_aware_copy(v, cache)
        res[k] = v
    end
    setmetatable(res,mt)
    return res
end

--- make a deep copy of a table, recursively copying all the keys and fields.
--- This supports cycles in tables; cycles will be reproduced in the copy.
--- This will also set the copied table's metatable to that of the original.
--- @param tab table A table
--- @return table new table
function Tables.DeepCopy(t)
    return cycle_aware_copy(t,{})
end

return Tables
