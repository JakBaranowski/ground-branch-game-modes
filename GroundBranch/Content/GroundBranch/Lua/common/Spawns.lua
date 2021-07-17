local StrOps = require("common.StringOperations")

local Spawns = {}

Spawns.__index = Spawns

function Spawns.CalculateAiCount(
    baseAiCount,
    maxAiCount,
    playerCount,
    playerCountFactor,
    aiCountSetting,
    aiCountSettingFactor,
    deviationPercent
)
    local calculatedAiCount
    print("Calculating max AI count.")
    print(
        "baseAiCount: " .. baseAiCount ..
        " maxAiCount: " .. maxAiCount ..
        " playerCount: " .. playerCount ..
        " playerCountFactor: " .. playerCountFactor ..
        " aiCountSetting: " .. aiCountSetting ..
        " aiCountSettingFactor: " .. aiCountSettingFactor ..
        " deviationPercent: " .. deviationPercent
    )
    calculatedAiCount = baseAiCount +
        playerCount * playerCountFactor +
        aiCountSetting * aiCountSettingFactor
    print("Initial max AI count: " .. calculatedAiCount)
    local aiCountDeviationMax = deviationPercent * calculatedAiCount
    aiCountDeviationMax = math.ceil(aiCountDeviationMax)
    local aiCountDeviation = math.random(
        -aiCountDeviationMax,
        aiCountDeviationMax
    )
    calculatedAiCount = calculatedAiCount + aiCountDeviation
    print(
        "AI count after applying deviation (" .. aiCountDeviation ..
        "): " .. calculatedAiCount
    )
    calculatedAiCount = Spawns.RoundNumber(calculatedAiCount)
    calculatedAiCount = math.min(calculatedAiCount, maxAiCount)
    print("Final AI count: " .. calculatedAiCount)
    return calculatedAiCount
end

function Spawns.CalculateBaseAiCountPerGroup(
    baseAiCount,
    playerCount,
    playerCountFactor,
    aiCountSetting,
    aiCountSettingFactor
)
    print("Calculating AI count per group")
    print(
        "baseAiCount: " .. baseAiCount ..
        " playerCount: " .. playerCount ..
        " playerCountFactor: " .. playerCountFactor ..
        " aiCountSetting: " .. aiCountSetting ..
        " aiCountSettingFactor: " .. aiCountSettingFactor
    )
    local baseAiCountPerGroup = baseAiCount +
        playerCount * playerCountFactor +
        aiCountSetting * aiCountSettingFactor
    print("Initial AI per group count: " .. baseAiCountPerGroup)
    baseAiCountPerGroup = Spawns.RoundNumber(baseAiCountPerGroup)
    print("Final AI per group count: " .. baseAiCountPerGroup)
    return baseAiCountPerGroup
end

function Spawns.RoundNumber(number)
    local roundNumber = 0
    local floatingPoint = number - math.floor(number)
    if floatingPoint <= 0.5 then
        roundNumber = math.floor(number)
    else
        roundNumber = math.ceil(number)
    end
    print("Rounded number " .. number .. " to " .. roundNumber)
    return roundNumber
end

function Spawns.AddSpawnsFromRandomGroupWithinDistance(
    remainingGroups,
    selectedSpawns,
    reserveSpawns,
    aiPerGroupAmount,
    location,
    maxDistance
)
    print(
        "Searching for a group within " .. maxDistance ..
        " from location " .. tostring(location)
    )
    local groupsToConsider = {}

    for groupIndex, group in ipairs(remainingGroups) do
        local groupLocation = actor.GetLocation(group[1])
        local distanceFromGroupToLocation = vector.Size(groupLocation - location)
        if distanceFromGroupToLocation < maxDistance then
            local groupName = StrOps.GetSuffixFromActorTag(
                remainingGroups[groupIndex][1],
                "Group"
            )
            print(
                "Found " .. groupName ..
                " group at distance " .. distanceFromGroupToLocation
            )
            table.insert(groupsToConsider, groupIndex)
        end
    end

    if #groupsToConsider <=0 then
        print("No groups within distance found")
        return
    end

    local selectedGroupIndex = groupsToConsider[math.random(#groupsToConsider)]
    Spawns.addSpawnsFromGroup(
        remainingGroups,
        selectedSpawns,
        reserveSpawns,
        aiPerGroupAmount,
        selectedGroupIndex
    )
end

function Spawns.AddSpawnsFromClosestGroupWithinDistance(
    remainingGroups,
    selectedSpawns,
    reserveSpawns,
    aiPerGroupAmount,
    location,
    maxDistance
)
    print(
        "Searching for groups within " .. maxDistance ..
        " from location " .. tostring(location)
    )

    local selectedGroupIndex = 0
    local lowestDistance = maxDistance
    for groupIndex, group in ipairs(remainingGroups) do
        local groupLocation = actor.GetLocation(group[1])
        local distanceFromGroupToLocation = vector.Size(groupLocation - location)
        if distanceFromGroupToLocation < lowestDistance then
            local groupName = StrOps.GetSuffixFromActorTag(
                remainingGroups[groupIndex][1],
                "Group"
            )
            print(
                "Found new closest group " .. groupName ..
                " at distance " .. distanceFromGroupToLocation
            )
            lowestDistance = distanceFromGroupToLocation
            selectedGroupIndex = groupIndex
        end
    end

    if selectedGroupIndex == 0 then
        print("No groups within max distance found")
        return
    end

    Spawns.addSpawnsFromGroup(
        remainingGroups,
        selectedSpawns,
        reserveSpawns,
        aiPerGroupAmount,
        selectedGroupIndex
    )
end

function Spawns.AddSpawnsFromRandomGroup(
    remainingGroups,
    selectedSpawns,
    reserveSpawns,
    aiPerGroupAmount
)
    local selectedGroupIndex = math.random(#remainingGroups)
    Spawns.addSpawnsFromGroup(
        remainingGroups,
        selectedSpawns,
        reserveSpawns,
        aiPerGroupAmount,
        selectedGroupIndex
    )
end

function Spawns.addSpawnsFromGroup(
    remainingGroups,
    selectedSpawns,
    reserveSpawns,
    aiPerGroupAmount,
    selectedGroupIndex
)
    local groupName = StrOps.GetSuffixFromActorTag(
        remainingGroups[selectedGroupIndex][1],
        "Group"
    )
    print("Selected group " .. groupName)
    for j, member in ipairs(remainingGroups[selectedGroupIndex]) do
        if j <= aiPerGroupAmount then
            table.insert(selectedSpawns, member)
            print("Added spawn " .. j .. " to selected spawns")
        else
            table.insert(reserveSpawns, member)
            print("Added spawn " .. j .. " to reserve spawns")
        end
    end
    table.remove(remainingGroups, selectedGroupIndex)
    print("Removed group " .. groupName .. " from remaining groups")
end

return Spawns