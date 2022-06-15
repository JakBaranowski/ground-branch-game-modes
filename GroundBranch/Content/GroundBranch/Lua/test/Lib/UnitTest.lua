--[[
    A simple unit testing framework.
--]]

local UnitTest = {
    pass = {},
    fail = {},
    originalPrint = print,
    stdout = '',
    cache = {},
    counter = 0,
    name = '<Unnamed>',
}

_G['UnitTest'] = UnitTest

-- Hook into Logger to get deterministic tostring's (e.g: table 0xff00...)
local Logger = require("Common.Logger")
Logger.toStringFunction = function(obj)
    if type(obj) == 'table' or type(obj) == 'function' or
            type(obj) == 'userdata' or type(obj) == 'thread' then

        if UnitTest.cache[obj] then
            return UnitTest.cache[obj]
        else
            UnitTest.counter = UnitTest.counter + 1
            UnitTest.cache[obj] = UnitTest.counter
        end

        return string.format("%s 0xff%06x", type(obj), UnitTest.counter)
    else
        return tostring(obj)
    end
end

setmetatable(UnitTest, {
    __call = function(_, name, condition)
        UnitTest.Test(name, condition)
    end
})

function UnitTest.AssertStringEquals(expected, actual)
    if type(expected) == 'table' then
        expected = table.concat(expected, '\n') .. '\n'
    end

    if not (UnitTest.stdout == actual) then
        error("Expected '" .. expected .. "' got '" .. actual .. "'")
    end
end

function UnitTest.AssertStdout(msg)
    UnitTest.AssertStringEquals(msg, UnitTest.stdout)
end

function UnitTest.ClearStdout()
    UnitTest.stdout = ''
end

function UnitTest.Test(name, condition)
    local pass = false
    local message = ''
    local fullname = UnitTest.name .. ': ' .. name

    print('Run:  ' .. fullname)
    if type(condition) == 'boolean' then
        pass = condition
    elseif type(condition) == 'function' then
        UnitTest.counter = 0
        UnitTest.cache = {}
        UnitTest.ClearStdout()

        -- temporarily replace print function
        _G['print'] = function(...)
            local str = ''
            for _, v in ipairs({...}) do
                str = str .. v
            end

            UnitTest.stdout = UnitTest.stdout .. str .. '\n'

            local prefix = '  [print] '
            local new_str = prefix .. string.gsub(str, '\n', function()
                return '\n' .. prefix
            end)
            UnitTest.originalPrint(new_str)
        end

        local noerror
        local result
        noerror, result = pcall(condition)

        -- restore print function
        _G['print'] = UnitTest.originalPrint

        if noerror then
            pass = true
        else
            pass = false
            message = ' - ' .. result
        end
    else
        message = ' - Need a boolean or a function'
    end

    if pass then
        print("PASS: " .. fullname)
        table.insert(UnitTest.pass, fullname)
    else
        local s = fullname .. message
        print("FAIL: " .. s)
        table.insert(UnitTest.fail, s)
    end
end

function UnitTest.PrintSummary()
    print(#UnitTest.pass .. " OK / " .. #UnitTest.fail .. " failed")
    if os then
        if #UnitTest.fail > 0 then
            os.exit(1)
        else 
            os.exit(0)
        end
    end
end

return UnitTest
