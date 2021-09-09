local Maths = require('Common.Maths')

local Common = {}

Common.__index = Common

---Calculates the AI count based on the provided data, and applies the random deviation
---based on the provided deviation percent.
---@param baseAiCount integer Base for the calculation, also can be seen as minimum ai count.
---@param maxAiCount integer Maximum ai count.
---@param playerCount integer Amount of players in game.
---@param playerCountFactor number Multiplier for the amount of players in game.
---@param aiCountSetting integer AI count game mode setting.
---@param aiCountSettingFactor number Multiplier for the AI count game mode setting.
---@param deviationPercent number Percent of the AI count to be used for calculating deviation.
---@return integer aiCount Calculated ai count.
function Common.GetAiCountWithDeviationPercent(
    baseAiCount,
    maxAiCount,
    playerCount,
    playerCountFactor,
    aiCountSetting,
    aiCountSettingFactor,
    deviationPercent
)
    print('Calculating AI count with deviation percent')
    print(
        'baseAiCount: ' .. baseAiCount ..
        ' maxAiCount: ' .. maxAiCount ..
        ' playerCount: ' .. playerCount ..
        ' playerCountFactor: ' .. playerCountFactor ..
        ' aiCountSetting: ' .. aiCountSetting ..
        ' aiCountSettingFactor: ' .. aiCountSettingFactor ..
        ' deviationPercent: ' .. deviationPercent
    )
    local aiCount = baseAiCount +
        playerCount * playerCountFactor +
        aiCountSetting * aiCountSettingFactor
    print('Initial AI count ' .. aiCount)
    aiCount = Maths.ApplyDeviationPercent(aiCount, deviationPercent)
    print('AI count after applying deviation ' .. aiCount)
    aiCount = Maths.RoundNumberToInt(aiCount)
    aiCount = math.min(aiCount, maxAiCount)
    print('Final AI count ' .. aiCount)
    return aiCount
end

---Calculates the AI count based on the provided data, and applies random deviation
---based on the provided deviation integer.
---@param baseAiCount integer Base for the calculation, also can be seen as minimum ai count.
---@param maxAiCount integer Maximum ai count.
---@param playerCount integer Amount of players in game.
---@param playerCountFactor number Multiplier for the amount of players in game.
---@param aiCountSetting integer AI count game mode setting.
---@param aiCountSettingFactor number Multiplier for the AI count game mode setting.
---@param deviationInt integer Maximum absolute value of the random deviation.
---@return integer aiCount Calculated ai count.
function Common.GetAiCountWithDeviationNumber(
    baseAiCount,
    maxAiCount,
    playerCount,
    playerCountFactor,
    aiCountSetting,
    aiCountSettingFactor,
    deviationInt
)
    print('Calculating AI count with deviation integer')
    print(
        'baseAiCount: ' .. baseAiCount ..
        ' playerCount: ' .. playerCount ..
        ' playerCountFactor: ' .. playerCountFactor ..
        ' aiCountSetting: ' .. aiCountSetting ..
        ' aiCountSettingFactor: ' .. aiCountSettingFactor
    )
    local aiCount = baseAiCount +
        playerCount * playerCountFactor +
        aiCountSetting * aiCountSettingFactor
    print('Initial AI count ' .. aiCount)
    aiCount = Maths.ApplyDeviationNumber(aiCount, deviationInt)
    print('AI count after applying deviation ' .. aiCount)
    aiCount = Maths.RoundNumberToInt(aiCount)
    aiCount = math.min(aiCount, maxAiCount)
    print('Final AI count ' .. aiCount)
    return aiCount
end

return Common
