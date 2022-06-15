local test = UnitTest or error("Run with TestSuite.lua")
local modes = {
    'BreakOut',
    'BreakThrough',
    'Debug',
    'Defend',
    'KillConfirmed',
    'TemplateAll',
    'Test'
}

for _, mode in ipairs(modes)
do
    test("Can load " .. mode .. ".lua", function()
        require(mode)
    end)
end
