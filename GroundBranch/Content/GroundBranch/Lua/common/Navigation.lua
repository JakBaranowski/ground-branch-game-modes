local vectors = require("common.Vectors")

local Navigation = {}

Navigation.__index = Navigation

---Calculates a straight route from fromLocation to toLocation. Returns a table
---of vectors representing this route. The distance between each point on route
---is equal to stepLength. The last step might be shorter than stepLength. The
---fromLocation and toLocation are included in the returned table.
---@param fromLocation table vector {x,y,z}
---@param toLocation table vector {x,y,z}
---@param stepLength number
---@return table
function Navigation.GetStraightRoute(fromLocation, toLocation, stepLength)
    local distanceVector = toLocation - fromLocation
    local unitDistanceVector = vectors.DivideByNumber(distanceVector, vector.Size(distanceVector))
    local stepLengthVector = vectors.MultiplyByNumber(unitDistanceVector, stepLength)
    local route = {fromLocation}
    for i = 1, 100 do
        local remainingDistance = vector.Size(toLocation - route[i])
        if remainingDistance <= stepLength then
            break
        end
        local nextStepLocation = route[i] + stepLengthVector
        table.insert(route, nextStepLocation)
    end
    table.insert(route, toLocation)
    return route
end

---Calculates a straight route from fromLocation to toLocation. Returns a table
---of vectors representing this route. The number of points in the returned table
---is equal to points. The distance between each point is equal. The fromLocation
---and toLocation are included in the returned table.
---@param fromLocation table vector {x,y,z}
---@param toLocation table vector {x,y,z}
---@param points integer
---@return table
function Navigation.GetStraightRoutePoints(fromLocation, toLocation, points)
    local stepLength = vector.Size(toLocation - fromLocation) / (points - 1)
    return Navigation.GetStraightRoute(fromLocation, toLocation, stepLength)
end

---Returns a table of route points projected to navigation mesh. Extent controls
---how much the projected point can differ from respective point on route.
---@param route table
---@param extent table vector {x,y,z}
---@return table
function Navigation.ProjectRouteToNavigation(route, extent)
    local projectedRoute = {}
    for _, point in ipairs(route) do
        local projectedPoint = ai.ProjectPointToNavigation(point, extent)
        table.insert(projectedRoute, projectedPoint)
    end
    return projectedRoute
end

---Retruns a table of random reachable points found along the route and within
---radius.
---@param route table
---@param radius number
---@param pointsPerStep integer
---@return table
function Navigation.GetRandomPointsAlongRoute(route, radius, pointsPerStep)
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

return Navigation
