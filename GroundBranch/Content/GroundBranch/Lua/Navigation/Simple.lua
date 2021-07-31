local vectors = require("Common.Vectors")
local common = require("Navigation.Common")

local Simple = {}

Simple.__index = Simple

---Attempts to plot a route by making steps in the direction from start to
---destination, with the possibility to create a side route using the angleMiss
---parameter. Usually requires bigger extent to work properly.
---@param start table vector {x,y,z}
---@param destination table vector {x,y,z}
---@param angleMiss number
---@param angleMax number
---@param angleStep number
---@param stepLength number
---@param maxPoints integer
---@param extent table vector {x,y,z}
---@return table
function Simple.PlotRoute(
    start,
    destination,
    angleMiss,
    angleMax,
    angleStep,
    stepLength,
    maxPoints,
    extent
)
    local route = {start}
    local loopSteps = maxPoints - 2
    local correctionPerStep = angleMiss / loopSteps
    local angleMiss = angleMiss
    for i = 1, loopSteps do
        local distanceVector = destination - route[i]
        local distance = vector.Size(distanceVector)
        if distance < stepLength then
            break
        end
        local directionVector = vectors.GetUnitVector(distanceVector)
        local stepVector = vectors.MultiplyByNumber(directionVector, stepLength)
        local possibleNextPosition = Simple.GetAllPossibleSteps(
            route[i],
            stepVector,
            angleMiss,
            angleMax,
            angleStep,
            extent
        )
        local nextPosition = {}
        if #possibleNextPosition < 1 then
            nextPosition = route[i] + stepVector
        else
            nextPosition = possibleNextPosition[math.random(#possibleNextPosition)]
        end
        table.insert(route, nextPosition)
        angleMiss = angleMiss - correctionPerStep
    end
    table.insert(route, destination)
    return route
end

---Gets all possible horizontal steps, within extent, from the start position and
---within the -angleMax to angleMax angle. Returns a table of possible steps.
---@param start table vector {x,y,z}
---@param stepVector table vector {x,y,z}
---@param angleMiss number
---@param angleMax number
---@param angleStep number
---@param extent table vector {x,y,z}
---@return table
function Simple.GetAllPossibleSteps(
    start,
    stepVector,
    angleMiss,
    angleMax,
    angleStep,
    extent
)
    local positionsToConsider = {}
    for angle = -angleMax, angleMax, angleStep do
        local chosenDirectionVector = vectors.GetHorizontalyRotatedVector(
            stepVector,
            angle + angleMiss
        )
        local newPosition = common.AttemptStep(
            start,
            chosenDirectionVector,
            extent
        )
        if newPosition ~= nil then
            table.insert(positionsToConsider, newPosition)
        end
    end
    return positionsToConsider
end

return Simple
