local Common = {}

Common.__index = Common

---Will attempt to make a step. If no point within extent is found will return nil.
---@param start table vector {x,y,z}
---@param stepVector table vector {x,y,z}
---@param extent table vector {x,y,z}
---@return any
function Common.AttemptStep(start, stepVector, extent)
    local newPostionStraight = start + stepVector
    local newPositionNav = ai.ProjectPointToNavigation(newPostionStraight, extent)
    return newPositionNav
end

---Retruns a table of random reachable points found along the route and within
---radius.
---@param route table
---@param radius number
---@param pointsPerStep integer
---@return table
function Common.GetRandomPointsAlongRoute(route, radius, pointsPerStep)
    local randomPoints = {}
    for _, step in ipairs(route) do
        for _ = 1, pointsPerStep do
            local randomPoint = ai.GetRandomReachablePointInRadius(step, radius)
            if randomPoint == nil then
                break
            end
            table.insert(randomPoints, randomPoint)
        end
    end
    return randomPoints
end

---Takes the given route and creates a new cleaned route. The cleaning is done by
---returning only the amount of points specified as desiredPointCount. This is done
---by ommiting points in between n-th points, where n is the number of points on
---original route divided by desiredPointCount and rounded down. The resulting point
---count may differ slightly from the desiredPointCount.
---@param route table
---@param desiredPointCount integer
---@return table
function Common.CleanRouteSimple(route, desiredPointCount)
    local step = math.floor(#route / desiredPointCount)
    local cleanedRoute = {route[1]}
    for i = step, #route, step do
        table.insert(cleanedRoute, route[i])
    end
    return cleanedRoute
end

---Takes the given route and creates a new cleaned route. The cleaning is done by
---only adding points at distance bigger then minDistance from previous step.
---@param route table
---@param minDistance number
---@return table
function Common.CleanRouteAdvanced(route, minDistance)
    local cleanedRoute = {route[1]}
    local currentIndex = 1
    while currentIndex <= #route do
        local pointFound = false
        for i = currentIndex + 1, #route do
            local distance = vector.Size(route[currentIndex] - route[i])
            if distance > minDistance then
                pointFound = true
                table.insert(cleanedRoute, route[i])
                currentIndex = i
                break
            end
        end
        if not pointFound then
            currentIndex = currentIndex + 1
        end
    end
    table.insert(cleanedRoute, route[#route])
    return cleanedRoute
end

return Common
