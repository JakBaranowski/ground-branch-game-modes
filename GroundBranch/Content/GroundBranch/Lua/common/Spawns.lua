local maths = require("common.Maths")
local actors = require("common.Actors")

local Spawns = {}

Spawns.__index = Spawns

---Calculates the AI count based on the provided data, and applies the deviationPercent.
---@param baseAiCount integer
---@param maxAiCount integer
---@param playerCount integer
---@param playerCountFactor number
---@param aiCountSetting integer
---@param aiCountSettingFactor number
---@param deviationPercent number
---@return integer
function Spawns.GetAiCountWithDeviationPercent(
    baseAiCount,
    maxAiCount,
    playerCount,
    playerCountFactor,
    aiCountSetting,
    aiCountSettingFactor,
    deviationPercent
)
    print("Calculating AI count with deviation percent")
    print(
        "baseAiCount: " .. baseAiCount ..
        " maxAiCount: " .. maxAiCount ..
        " playerCount: " .. playerCount ..
        " playerCountFactor: " .. playerCountFactor ..
        " aiCountSetting: " .. aiCountSetting ..
        " aiCountSettingFactor: " .. aiCountSettingFactor ..
        " deviationPercent: " .. deviationPercent
    )
    local aiCount = baseAiCount +
        playerCount * playerCountFactor +
        aiCountSetting * aiCountSettingFactor
    print("Initial AI count " .. aiCount)
    aiCount = maths.ApplyDeviationPercent(aiCount, deviationPercent)
    print("AI count after applying deviation " .. aiCount)
    aiCount = maths.RoundNumberToInt(aiCount)
    aiCount = math.min(aiCount, maxAiCount)
    print("Final AI count " .. aiCount)
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
function Spawns.GetAiCountWithDeviationNumber(
    baseAiCount,
    maxAiCount,
    playerCount,
    playerCountFactor,
    aiCountSetting,
    aiCountSettingFactor,
    deviationInt
)
    print("Calculating AI count with deviation integer")
    print(
        "baseAiCount: " .. baseAiCount ..
        " playerCount: " .. playerCount ..
        " playerCountFactor: " .. playerCountFactor ..
        " aiCountSetting: " .. aiCountSetting ..
        " aiCountSettingFactor: " .. aiCountSettingFactor
    )
    local aiCount = baseAiCount +
        playerCount * playerCountFactor +
        aiCountSetting * aiCountSettingFactor
    print("Initial AI count " .. aiCount)
    aiCount = maths.ApplyDeviationNumber(aiCount, deviationInt)
    print("AI count after applying deviation " .. aiCount)
    aiCount = maths.RoundNumberToInt(aiCount)
    aiCount = math.min(aiCount, maxAiCount)
    print("Final AI count " .. aiCount)
    return aiCount
end

---Adds spawn points from a random group found in remainingGroups table within
---given maxDistance from location to the selectedSpawns table. Spawn points
---that excceed the aiPerGroupAmount will be added to reserveSpawns table.
---@param remainingGroups table
---@param selectedSpawns table
---@param reserveSpawns table
---@param aiPerGroupAmount integer
---@param location table vector {x,y,z}
---@param maxDistance number
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
    local maxDistanceSq = maxDistance ^ 2
    local groupsToConsider = {}
    for groupIndex, group in ipairs(remainingGroups) do
        local shortestDistanceSq = actors.GetShortestDistanceSqWithinGroup(
            location,
            group,
            maxDistanceSq
        )
        if shortestDistanceSq < maxDistanceSq then
            local groupName = actors.GetSuffixFromActorTag(
                remainingGroups[groupIndex][1],
                "Group"
            )
            print(
                "Found group " .. groupName ..
                " with member at distance squared " .. shortestDistanceSq
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

---Finds group closest to location from remainingGroups. Add spawns from the
---closest group to selectedSpawns table. Spawns that exceed the aiPerGroupAmount
---will be added to the reserveSpawns table.
---If no group within maxDistance is found no spawns will be added.
---@param remainingGroups table
---@param selectedSpawns table
---@param reserveSpawns table
---@param aiPerGroupAmount integer
---@param location table vector {x,y,z}
---@param maxDistance number
function Spawns.AddSpawnsFromClosestGroup(
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
    local lowestDistanceSq = maxDistance ^ 2
    for groupIndex, group in ipairs(remainingGroups) do
        local distanceSq = actors.GetShortestDistanceSqWithinGroup(
            location,
            group,
            lowestDistanceSq
        )
        if distanceSq < lowestDistanceSq then
            local groupName = actors.GetSuffixFromActorTag(
                remainingGroups[groupIndex][1],
                "Group"
            )
            print(
                "Found new closest group " .. groupName ..
                " at distance " .. distanceSq
            )
            lowestDistanceSq = distanceSq
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

---Finds group closest to location, and within the vertical maxZDistance, from
---remainingGroups. Adds spawns from the closest group to selectedSpawns table.
---Spawns that exceed the aiPerGroupAmount will be added to the reserveSpawns table.
---If no group within maxDistance, or maxZDistance, is found no spawns will be added.
---@param remainingGroups table
---@param selectedSpawns table
---@param reserveSpawns table
---@param aiPerGroupAmount integer
---@param location table vector {x,y,z}
---@param maxDistance number
---@param maxZDistance number
function Spawns.AddSpawnsFromClosestGroupWithZLimit(
    remainingGroups,
    selectedSpawns,
    reserveSpawns,
    aiPerGroupAmount,
    location,
    maxDistance,
    maxZDistance
)
    print(
        "Searching for groups within " .. maxDistance ..
        " from location " .. tostring(location) ..
        " within max z distance " .. maxZDistance
    )
    local selectedGroupIndex = 0
    local lowestDistance = maxDistance ^ 2
    for groupIndex, group in ipairs(remainingGroups) do
        local groupLocation = actors.GetGroupAverageLocation(group)
        local groupName = actors.GetSuffixFromActorTag(
            remainingGroups[groupIndex][1],
            "Group"
        )
        local distanceVector = groupLocation - location
        local horizontalDistance = distanceVector.x ^ 2 + distanceVector.y ^ 2
        print(
            "Group " .. groupName ..
            " at distance " .. horizontalDistance
        )
        if
            horizontalDistance < lowestDistance and
            math.abs(distanceVector.z) < maxZDistance
        then
            print("Found new closest group " .. groupName)
            lowestDistance = horizontalDistance
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

---Adds spawn points to selectedSpawns table from a randomly selected group in
---the remainingGroups table.
---Spawns that exceed the aiPerGroupAmount will be added to the reserveSpawns table.
---@param remainingGroups table
---@param selectedSpawns table
---@param reserveSpawns table
---@param aiPerGroupAmount integer
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

---Helper function that adds spawns from a group with selectedGroupIndex in the
---remainingGroups table to selectedSpawns table. Spawns that exceed the 
---aiPerGroupAmount will be added to the reserveSpawns table.
---@param remainingGroups table
---@param selectedSpawns table
---@param reserveSpawns table
---@param aiPerGroupAmount integer
---@param selectedGroupIndex integer
function Spawns.addSpawnsFromGroup(
    remainingGroups,
    selectedSpawns,
    reserveSpawns,
    aiPerGroupAmount,
    selectedGroupIndex
)
    local groupName = actors.GetSuffixFromActorTag(
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
