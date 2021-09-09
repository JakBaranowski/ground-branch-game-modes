local Common = {}

Common.__index = Common

---Will attempt to make a step, get a point on navigation mesh within extent in
---the given direction. If no point within extent is found will return nil.
---@param stepStart table vector {x,y,z} point to start the step.
---@param stepVector table vector {x,y,z} vector describing step direction and length.
---@param extent table vector {x,y,z} extent within which to search for the point on nav mesh.
---@return table stepEnd vector {x,y,z} point on nav mesh.
function Common.AttemptStep(stepStart, stepVector, extent)
    local newPostionStraight = stepStart + stepVector
    local newPositionNav = ai.ProjectPointToNavigation(newPostionStraight, extent)
    return newPositionNav
end

---Retruns a table of random reachable points found along the route and within
---radius.
---@param route table a list of steps on the route.
---@param radius number radius within which the random points can be created.
---@param pointsPerStep integer how many random points will be added per route step.
---@return table randomPoints a list of random points along the route.
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
---@param route table a list of steps on the route.
---@param desiredPointCount integer how many points should cleaned route have.
---@return table cleanRoute a list of desiredPointCount steps on route.
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
---@param route table a list of steps on the route.
---@param minDistance number a minimum distance between last and new step.
---@return table cleanRoute a list of route steps at distance bigger than minDistance.
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
