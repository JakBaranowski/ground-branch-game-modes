local vectors = require("common.Vectors")

local Navigation = {}

Navigation.__index = Navigation

--#region Straight

---Calculates a straight route from fromLocation to toLocation. Returns a table
---of vectors representing this route. The distance between each point on route
---is equal to stepLength. The last step might be shorter than stepLength. The
---fromLocation and toLocation are included in the returned table.
---@param fromLocation table vector {x,y,z}
---@param toLocation table vector {x,y,z}
---@param stepLength number
---@return table
function Navigation.GetStraightRoute(fromLocation, toLocation, stepLength)
    local distance = vector.Size(toLocation - fromLocation)
    local points = math.floor(distance / stepLength)
    return Navigation.GetStraightRoutePoints(fromLocation, toLocation, points)
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
    local distanceVector = toLocation - fromLocation
    local stepVector = vectors.DivideByNumber(distanceVector, points)
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

--#endregion

--#region Top

function Navigation.PlotNav(
    fromPosition,
    toPosition,
    angleMiss,
    angleMax,
    stepLength,
    maxPoints
)
    local route = {fromPosition}
    local stepSq = stepLength ^ 2
    local sizeSqThreshold = stepSq * 0.66
    local loopSteps = maxPoints - 1
    local currentAngleMiss = angleMiss
    local angleCorrectionPerStep = currentAngleMiss / loopSteps
    local extent = vector:new(stepLength / 2, stepLength / 2, stepLength)

    for i = 1, loopSteps do
        local distanceVector = toPosition - route[i]
        local distanceSq = vector.SizeSq(distanceVector)
        -- local oneOverSqareRootOfThree = 0.57735026918962576450914878050196
        if distanceSq < stepSq then
            table.insert(route, toPosition)
            break
        end

        local directionVector = vectors.GetUnitVector(distanceVector)
        print("Direction unit vector " .. tostring(directionVector))
        local horizontalDirectionVector = vectors.GetUnitVector2D(distanceVector)
        local stepVector = vectors.MultiplyByNumber(
            horizontalDirectionVector,
            stepLength
        )

        local possibleSteps = Navigation.GetPossibleStep(
            route[i-1],
            route[i],
            stepVector,
            currentAngleMiss,
            angleMax,
            sizeSqThreshold,
            extent
        )

        local nextStep = nil

        if
            math.abs(directionVector.z) > 0.75 and
            possibleSteps.vertical ~= nil
        then
            print("Going vertical")
            nextStep = possibleSteps.vertical
        elseif possibleSteps.horizontal ~= nil then
            print("Going horizontal")
            nextStep = possibleSteps.horizontal
        end

        if nextStep == nil then
            local chosenDirectionVector = vectors.RotateVectorHorizontal(
                stepVector,
                angleMiss
            )
            nextStep = route[i] + chosenDirectionVector
        end

        table.insert(route, nextStep)
        currentAngleMiss = currentAngleMiss - angleCorrectionPerStep
    end
    return route
end

function Navigation.GetPossibleStep(
    previousStep,
    currentStep,
    stepVector,
    angleMiss,
    angleMax,
    sizeSqThreshold,
    extent
)
    local possibleSteps = {
        vertical = nil,
        horizontal = nil,
        perpendicular = nil
    }

    possibleSteps.vertical = Navigation.GetPossibleHorizontalStep(
        previousStep,
        currentStep,
        stepVector,
        angleMiss,
        angleMax,
        sizeSqThreshold,
        5,
        extent
    )

    possibleSteps.horizontal = Navigation.GetPossibleVerticalStep(
        previousStep,
        currentStep,
        250.0,
        10,
        sizeSqThreshold
    )

    return possibleSteps
end

function Navigation.GetPossibleHorizontalStep(
    previousStep,
    currentStep,
    stepVector,
    angleMiss,
    angleMax,
    sizeSqThreshold,
    tries,
    extent
)
    -- print("Trying to get horizontal step")
    for _ = 1, tries do
        local randomAngle = angleMax * (math.random() - 0.5) + angleMiss
        local chosenDirectionVector = vectors.RotateVectorHorizontal(
            stepVector,
            randomAngle
        )
        local nextStep = Navigation.AttemptStep(
            currentStep,
            chosenDirectionVector,
            extent
        )
        if nextStep ~= nil then
            local sizeSqToCurrent = vector.SizeSq(nextStep - currentStep)
            local sizeSqToPrevious = vector.SizeSq(nextStep - previousStep)
            if
                sizeSqToCurrent > sizeSqThreshold and
                sizeSqToPrevious > sizeSqThreshold
            then
                -- print(
                --     "New horizontal step found at " .. tostring(nextStep) ..
                --     " distance squared from last step " .. sizeSqToCurrent ..
                --     " threshold " .. sizeSqThreshold
                -- )
                return nextStep
            end
        end
    end
    return nil
end

function Navigation.GetPossibleVerticalStep(
    previousStep,
    currentStep,
    stepLength,
    tries,
    sizeSqThreshold
)
    -- print("Trying to get vertical step")
    local vectorUp = vector:new(0, 0, 1)
    local extent = vector:new(stepLength * 2, stepLength * 2, stepLength / 2)
    for i = 1, tries do

        local stepDown = vectors.MultiplyByNumber(vectorUp, -stepLength * i)
        local down = Navigation.AttemptStep(currentStep, stepDown, extent)
        if down ~= nil then
            local sizeSqToCurrent = vector.SizeSq(down - currentStep)
            local sizeSqToPrevious = vector.SizeSq(down - previousStep)
            if
                sizeSqToCurrent > sizeSqThreshold and
                sizeSqToPrevious > sizeSqThreshold
            then
                -- print(
                --     "New vertical step down found at " .. tostring(down) ..
                --     " distance squared from last step " .. sizeSqToCurrent ..
                --     " threshold " .. sizeSqThreshold
                -- )
                return down
            end
        end

        local stepUp = vectors.MultiplyByNumber(vectorUp, stepLength * i)
        local up = Navigation.AttemptStep(currentStep, stepUp, extent)
        if up ~= nil then
            local sizeSqToCurrent = vector.SizeSq(up - currentStep)
            local sizeSqToPrevious = vector.SizeSq(up - previousStep)
            if
                sizeSqToCurrent > sizeSqThreshold and
                sizeSqToPrevious > sizeSqThreshold
            then
                -- print(
                --     "New vertical step up found at " .. tostring(up) ..
                --     " distance squared from last step " .. sizeSqToCurrent ..
                --     " distance squared from previous step " .. sizeSqToPrevious ..
                --     " threshold " .. sizeSqThreshold
                -- )
                return up
            end
        end
    end

    return nil
end

function Navigation.GetPossiblePerpendicularStep(
    previousStep,
    currentStep,
    stepVector,
    clockwise,
    extent,
    sizeSqThreshold
)
    -- print("Trying to get perpendicular step")
    local perpendicularVector =
        vectors.GetPerpendicularVectorHorizontal(stepVector, clockwise)
    local nextStep = Navigation.AttemptStep(currentStep, perpendicularVector, extent)
    local sizeSqToCurrent = vector.SizeSq(nextStep - currentStep)
    local sizeSqToPrevious = vector.SizeSq(nextStep - previousStep)
    if
        nextStep ~= nil and
        sizeSqToCurrent > sizeSqThreshold and
        sizeSqToPrevious > sizeSqThreshold
    then
        -- print(
        --     "New perpendicular step found at " .. tostring(nextStep) ..
        --     " distance squared from last step " .. sizeSqToCurrent ..
        --     " distance squared from previous step " .. sizeSqToPrevious ..
        --     " threshold " .. sizeSqThreshold
        -- )
        return nextStep
    end
    return nil
end

--#endregion

--#region Random

function Navigation.PlotNavRandom(
    fromPosition,
    toPosition,
    missStart,
    angleMax,
    angleStep,
    stepLength,
    maxPoints,
    extent
)
    local route = {fromPosition}
    local loopSteps = maxPoints - 2
    local correctionPerStep = missStart / loopSteps
    local angleMiss = missStart
    for i = 1, loopSteps do
        local distanceVector = toPosition - route[i]
        local distance = vector.Size(distanceVector)
        if distance < stepLength then
            break
        end
        local directionVector = vectors.GetUnitVector(distanceVector)
        local stepVector = vectors.MultiplyByNumber(directionVector, stepLength)
        local possibleNextPosition = Navigation.GetAllPossibleSteps(
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
    table.insert(route, toPosition)
    return route
end

function Navigation.GetAllPossibleSteps(
    start,
    stepVector,
    angleMiss,
    angleMax,
    angleStep,
    extent
)
    local positionsToConsider = {}
    for angle = -angleMax, angleMax, angleStep do
        local chosenDirectionVector = vectors.RotateVectorHorizontal(
            stepVector,
            angle + angleMiss
        )
        local newPosition = Navigation.AttemptStep(
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

--#endregion

--#region Common

function Navigation.AttemptStep(start, stepVector, extent)
    local newPostionStraight = start + stepVector
    local newPositionNav = ai.ProjectPointToNavigation(newPostionStraight, extent)
    return newPositionNav
end

--#endregion

--#region Cleaning

function Navigation.CleanPlottedNavAdvanced(route, minDistance)
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

function Navigation.CleanPlottedNavSimple(route, points)
    local step = math.floor(#route / points)
    local cleanedRoute = {route[1]}
    for i = step, #route, step do
        table.insert(cleanedRoute, route[i])
    end
    return cleanedRoute
end

--#endregion

return Navigation
