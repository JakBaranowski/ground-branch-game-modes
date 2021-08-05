local Maths = require('Common.Maths')

local Common = {}

Common.__index = Common

---Calculates the AI count based on the provided data, and applies the deviationPercent.
---@param baseAiCount integer
---@param maxAiCount integer
---@param playerCount integer
---@param playerCountFactor number
---@param aiCountSetting integer
---@param aiCountSettingFactor number
---@param deviationPercent number
---@return integer
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

---Calculates the AI count based on the provided data and applies the deviationInt.
---@param baseAiCount integer
---@param maxAiCount integer
---@param playerCount integer
---@param playerCountFactor number
---@param aiCountSetting integer
---@param aiCountSettingFactor number
---@param deviationInt integer
---@return integer
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
