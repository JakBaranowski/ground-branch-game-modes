local strings = require("common.Strings")

local Actors = {}

Actors.__index = Actors

---Will query actor tags, of actorWithTags, for a tag starting with tagPrefix.
---If tag starting with tagPrefix is found will return tagSuffix (part after tagPrefix)
---If tag is not found will return empty string
---@param actorWithTag any
---@param tagPrefix string
---@return string
function Actors.GetSuffixFromActorTag(actorWithTag, tagPrefix)
	for _, actorTag in ipairs(actor.GetTags(actorWithTag)) do
		if strings.StartsWith(actorTag, tagPrefix) then
			return strings.GetSuffix(actorTag, tagPrefix)
		end
	end
    return ""
end

---Calculates and returns the average location of a group of actors.
---@param group table
---@return table
function Actors.GetGroupAverageLocation(group)
    local averageLocation = {
        x = 0,
        y = 0,
        z = 0
    }
    for _, member in ipairs(group) do
        averageLocation = averageLocation + actor.GetLocation(member)
    end
    averageLocation.x = averageLocation.x / #group
    averageLocation.y = averageLocation.y / #group
    averageLocation.z = averageLocation.z / #group
    print("Average group location " .. tostring(averageLocation))
    return averageLocation
end

---Returns the shortests distance squared from any member of the group and the given
---location.
---If no member of the group is within maxDistanceSq will return maxDistanceSq.
---@param location table vector {x,y,z}
---@param group table
---@param maxDistanceSq number
---@return number
function Actors.GetShortestDistanceSqWithinGroup(location, group, maxDistanceSq)
    local shortestDistanceSq = maxDistanceSq
    for _, member in ipairs(group) do
        local memberLocation = actor.GetLocation(member)
        local distanceSq = vector.SizeSq(memberLocation - location)
        if distanceSq < shortestDistanceSq then
            shortestDistanceSq = distanceSq
        end
    end
    return shortestDistanceSq
end

---Returns the shortests distance from any member of the group and the given
---location.
---If no member of the group is within maxDistance will return maxDistance.
---@param location table vector {x,y,z}
---@param group table
---@param maxDistance number
---@return number
function Actors.GetShortestDistanceWithinGroup(location, group, maxDistance)
    local maxDistanceSq = maxDistance ^ 2
    return Actors.GetShortestDistanceSqWithinGroup(location, group, maxDistanceSq) ^ 0.5
end

return Actors
