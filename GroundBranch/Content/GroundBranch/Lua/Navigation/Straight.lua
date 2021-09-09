local Vectors = require('Common.Vectors')

local Straight = {}

Straight.__index = Straight

---Returns a table of steps (vectors) representing a straight route from start to
---destination. The distance between each point on route is equal to stepLength.
---The last step might be shorter than stepLength. The start and destination are
---included in the returned table.
---@param start table vector {x,y,z} starting location.
---@param destination table vector {x,y,z} ending location.
---@param stepLength number length of a single step in centimeters.
---@return table routeSteps an indexed table of route steps. Each step is a vector {x,y,z}.
function Straight.GetStraightRouteStepLength(start, destination, stepLength)
    local distance = vector.Size(destination - start)
    local points = math.floor(distance / stepLength)
    return Straight.GetStraightRoutePoints(start, destination, points)
end

---Returns a table of steps (vectors) representing straight route from start to
---destination. The number of points in the returned table is equal to specified
---points. The distance between each point is equal. The start and destination
---are included in the returned table.
---@param start table vector {x,y,z} starting location.
---@param destination table vector {x,y,z} ending location.
---@param points integer the amount of points on route.
---@return table routeSteps an indexed table of route steps. Each step is a vector {x,y,z}.
function Straight.GetStraightRoutePoints(start, destination, points)
    local distanceVector = destination - start
    local stepVector = Vectors.DivideByNumber(distanceVector, points)
    local route = {start}
    for i = 1, points - 2 do
        local nextStepLocation = route[i] + stepVector
        table.insert(route, nextStepLocation)
    end
    table.insert(route, destination)
    return route
end

---Returns a table of route points projected to navigation mesh. Extent controls
---how much the projected point can differ from respective point on route.
---@param route table a indexed table of route steps.
---@param extent table vector {x,y,z} extent within which to search for the point on nav mesh.
---@return table routeSteps an indexed table of route steps. Each step is a vector {x,y,z}.
function Straight.ProjectRouteToNavigation(route, extent)
    local projectedRoute = {}
    for _, point in ipairs(route) do
        local projectedPoint = ai.ProjectPointToNavigation(point, extent)
        table.insert(projectedRoute, projectedPoint)
    end
    return projectedRoute
end

return Straight
