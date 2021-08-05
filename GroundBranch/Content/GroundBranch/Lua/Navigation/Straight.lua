local Vectors = require('Common.Vectors')

local Straight = {}

Straight.__index = Straight

---Calculates a straight route from fromLocation to toLocation. Returns a table
---of vectors representing this route. The distance between each point on route
---is equal to stepLength. The last step might be shorter than stepLength. The
---fromLocation and toLocation are included in the returned table.
---@param fromLocation table vector {x,y,z}
---@param toLocation table vector {x,y,z}
---@param stepLength number
---@return table
function Straight.GetStraightRouteStepLength(fromLocation, toLocation, stepLength)
    local distance = vector.Size(toLocation - fromLocation)
    local points = math.floor(distance / stepLength)
    return Straight.GetStraightRoutePoints(fromLocation, toLocation, points)
end

---Calculates a straight route from fromLocation to toLocation. Returns a table
---of vectors representing this route. The number of points in the returned table
---is equal to points. The distance between each point is equal. The fromLocation
---and toLocation are included in the returned table.
---@param fromLocation table vector {x,y,z}
---@param toLocation table vector {x,y,z}
---@param points integer
---@return table
function Straight.GetStraightRoutePoints(fromLocation, toLocation, points)
    local distanceVector = toLocation - fromLocation
    local stepVector = Vectors.DivideByNumber(distanceVector, points)
    local route = {fromLocation}
    for i = 1, points - 2 do
        local nextStepLocation = route[i] + stepVector
        table.insert(route, nextStepLocation)
    end
    table.insert(route, toLocation)
    return route
end

---Returns a table of route points projected to navigation mesh. Extent controls
---how much the projected point can differ from respective point on route.
---@param route table
---@param extent table vector {x,y,z}
---@return table
function Straight.ProjectRouteToNavigation(route, extent)
    local projectedRoute = {}
    for _, point in ipairs(route) do
        local projectedPoint = ai.ProjectPointToNavigation(point, extent)
        table.insert(projectedRoute, projectedPoint)
    end
    return projectedRoute
end

return Straight
