local test = UnitTest or error("Run with TestSuite.lua")
local Logger = require('Common.Logger')

do
    test('Logger Stringify of simple table', function()
        local t = {
            Foo = 'some string',
            Bar = 1
        }

        local result = Logger.new('-'):Stringify(t)
        print(result)

        assert(result == [[
{ -- table 0xff000001
  "Bar" = 1,
  "Foo" = "some string",
}]])
    end)

    test('Logger Stringify of complex table', function()
        local t = { 'hello', 'world', {
            Foo = { 1, 2, 3 },
            Bar = {
                Setting1 = 'Hello',
                Setting2 = 'World',
                Setting3 = nil,
                cb = function(a, b, c)
                end
            }
        } }

        t[3].Bar.Base = t

        local result = Logger.new('-'):Stringify(t)
        print(result)

        assert(result == [[
{ -- table 0xff000001
  1 = "hello",
  2 = "world",
  3 = { -- table 0xff000002
    "Bar" = { -- table 0xff000003
      "Base" = 1 -- (Cyclic),
      "Setting1" = "Hello",
      "Setting2" = "World",
      "cb" = function 0xff000004 { -- table 0xff000005
        "isvararg" = false,
        "nparams" = 3,
      },
    },
    "Foo" = { -- table 0xff000006
      1 = 1,
      2 = 2,
      3 = 3,
    },
  },
}]])
    end)


    test('Logger simple output', function()
        local log = Logger.new('MyCustomMode')
        local log2 = Logger.new('MyUtil')

        log:Info('Running some code')
        log:Warn('Printing some state', false)
        log2:Error('Too many players', 17)

        test.AssertStdout({
            'INFO  MyCustomMode         - Running some code',
            'WARN  MyCustomMode         - Printing some state: false',
            'ERROR MyUtil               - Too many players: 17'
        })
    end)

    test('Logger multiline output', function()
        local log = Logger.new('MyCustomMode')

        local tmp = {'a', 'b'}

        log:Info('Running some code', tmp)
        log:Warn('Printing some state', false)
        log:Error('Too many players', 17)

        test.AssertStdout({
            'INFO  MyCustomMode         - Running some code: { -- table 0xff000001',
            'INFO  MyCustomMode               1 = "a",',
            'INFO  MyCustomMode               2 = "b",',
            'INFO  MyCustomMode             }',
            'WARN  MyCustomMode         - Printing some state: false',
            'ERROR MyUtil               - Too many players: 17'
        })
    end)

    test('Test log levels', function()
        local expected = {}
        local log = Logger.new('MyCustomMode')

        log:SetLogLevel('ERROR')
        log:Debug('x')
        log:Info('x')
        log:Warn('x')
        log:Error('an error')

        table.insert(expected, 'ERROR MyCustomMode         - an error')
        test.AssertStdout(expected)

        test.ClearStdout()
        log:SetLogLevel('WARN')
        log:Error('an error')
        log:Warn('a warning')
        log:Debug('x')
        log:Info('x')

        table.insert(expected, 'WARN MyCustomMode         - a warning')
        test.AssertStdout(expected)
    end)

end

