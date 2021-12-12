local ModDebug = require('Debug.Members')

local Debug = {
    UseReadyRoom = true,
	UseRounds = true,
	StringTables = {'BreakOut'},
	Settings = {}
}

function Debug:PostInit()
    ModDebug.IterateMembers(_G, 'Global')
end

return Debug
