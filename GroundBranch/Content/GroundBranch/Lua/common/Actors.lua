local Strings = require('Common.Strings')

local Actors = {}

Actors.__index = Actors

---Will query actor tags, of actorWithTags, for a tag starting with tagPrefix.
---If tag starting with tagPrefix is found will return tagSuffix, i.e.: part of
---the tag after tagPrefix.
---If tag is not found will return empty string.
---@param actorWithTag userdata actor reference.
---@param tagPrefix string prefix of the tag to find.
---@return string suffix suffix of the found tag.
function Actors.GetSuffixFromActorTag(actorWithTag, tagPrefix)
	for _, actorTag in ipairs(actor.GetTags(actorWithTag)) do
		if Strings.StartsWith(actorTag, tagPrefix) then
			return Strings.GetSuffix(actorTag, tagPrefix)
		end
	end
    return ''
end

---Calculates and returns the average location of a group of actors.
---@param group table a table containing a group of actors.
---@return table vector {x,y,z} the average location of the group.
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
    print('Average group location ' .. tostring(averageLocation))
    return averageLocation
end

---Returns the shortest distance squared from any actor from provided group and
---the given location.
---Good enough for comparing distances, but cheaper in terms of performance than
---calculating proper distance.
---@param location table vector {x,y,z} a location to which distance is measured.
---@param group table a table containing a group of actors.
---@return number distanceSquared the shortest squared distance.
function Actors.GetShortestDistanceSqWithinGroup(location, group)
    local firstMemberLocation = actor.GetLocation(group[1])
    local shortestDistanceSq = vector.SizeSq(firstMemberLocation - location)
    for _, member in ipairs(group) do
        local memberLocation = actor.GetLocation(member)
        local distanceSq = vector.SizeSq(memberLocation - location)
        if distanceSq < shortestDistanceSq then
            shortestDistanceSq = distanceSq
        end
    end
    return shortestDistanceSq
end

---Returns the shortest distance from any actor from provided group and the given
---location.
---@param location table vector {x,y,z} a location to which distance is measured.
---@param group table a table containing a group of actors.
---@return number distance the shortests distance.
function Actors.GetShortestDistanceWithinGroup(location, group)
    return math.sqrt(
        Actors.GetShortestDistanceSqWithinGroup(location, group)
    )
end

return Actors
