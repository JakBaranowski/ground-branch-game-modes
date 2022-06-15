--[[
Some standalone (non-hosted) unit tests

Run with:
    lua.exe UnitTest.lua
--]]

local test = UnitTest

---
--- Example tests
---
do
    test('Trivial test #1', 2 < 3)

    test('Trivial test #2', function()
        assert(2 < 3)
        assert(3 > 2)
    end)

    test('Foo', function()
        print('Hello')
        test.AssertStdout('Hello\n')
    end)

    test('Foo', function()
        print('Hello')
        print('World')
        test.AssertStdout({ 'Hello', 'World' })
    end)
end
