--[[
Simple regression test suite.

Run with
    lua5.3.exe TestSuite.lua

Command line options:
    lua5.3.exe TestSuite.lua [all | TEST_CASE_NAME]
]]--

local test_cases = {
    'BasicTest',
    'LoggerTest',
    'SmokeTest'
}

local unittest = require("test.Lib.UnitTest")
local wanted_name = arg[1] or 'all'
local new_global_names = {}

local function fail_on_global_assignment(_, name)
    table.insert(new_global_names, name)
    print("Unwanted new global: " .. name)
end

setmetatable(_G, {__newindex=fail_on_global_assignment})


for _,v in ipairs(test_cases)
do
    if wanted_name == 'all' or string.find(v, wanted_name) then
        unittest.name = v
        require("test." .. v)
        print("----")
    end
end

unittest.name = 'Post'
unittest("No globals have been assigned", function()
    assert(#new_global_names == 0)
end)

unittest.PrintSummary()
