local Vectors = require('Common.Vectors')
local Common = require('Navigation.Common')

local Simple = {}

Simple.__index = Simple

---Attempts to plot a route from start to destination by blindly making steps in
---the direction more or less toward destination. angleMiss can be used to create
---a route with tendency to go in the specified direction.
---This method of plotting route usually requires bigger extent to work properly.
---May not reach the destination.
---@param start table vector {x,y,z} starting location.
---@param destination table vector {x,y,z} ending location
---@param angleMiss number starting angle deviation from the destination vector.
---@param angleMax number absolute maximum value of angles to try.
---@param angleStep number angle to move between every try.
---@param stepLength number length of step.
---@param maxPoints integer the maximum amount of steps to be taken.
---@param extent table vector {x,y,z} extent within which to search for the point on nav mesh.
---@return table routeSteps a indexed table of route steps. Each step is a vector {x,y,z}.
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
    local currentAngleMiss = angleMiss
    for i = 1, loopSteps do
        local distanceVector = destination - route[i]
        local distance = vector.Size(distanceVector)
        if distance < stepLength then
            break
        end
        local directionVector = Vectors.GetUnitVector(distanceVector)
        local stepVector = Vectors.MultiplyByNumber(directionVector, stepLength)
        local possibleNextPosition = Simple.getAllPossibleSteps(
            route[i],
            stepVector,
            currentAngleMiss,
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
        currentAngleMiss = currentAngleMiss - correctionPerStep
    end
    table.insert(route, destination)
    return route
end

---Gets all possible horizontal steps, within extent, from the start position and
---within the -angleMax to angleMax angle. Returns a table of possible steps.
---Should only be used within Navigation Simple PlotRoute method.
---@param start table vector {x,y,z}
---@param stepVector table vector {x,y,z}
---@param angleMiss number
---@param angleMax number
---@param angleStep number
---@param extent table vector {x,y,z}
---@return table
function Simple.getAllPossibleSteps(
    start,
    stepVector,
    angleMiss,
    angleMax,
    angleStep,
    extent
)
    local positionsToConsider = {}
    for angle = -angleMax, angleMax, angleStep do
        local chosenDirectionVector = Vectors.GetHorizontalyRotatedVector(
            stepVector,
            angle + angleMiss
        )
        local newPosition = Common.AttemptStep(
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
