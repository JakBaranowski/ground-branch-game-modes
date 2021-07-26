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

return Actors
