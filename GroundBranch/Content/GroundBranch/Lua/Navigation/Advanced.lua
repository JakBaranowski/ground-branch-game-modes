local vectors = require("Common.Vectors")
local common = require("Navigation.Common")
-- local maths = require("Common.Maths")

--NOTES
-- If all unit vector components are equal then each component lenght would be
-- equal to one over square root of three.
-- If vertical and horziontal component of a vector are equal, then both vertical
-- and horizontal components are equal to one over square root of two.

---Direction table maps human-readeable directions to numbers in a way that allows
---to easily find opposite direction and compare direction faster.
local Direction = {
    none = 0,
    forward = 1,
    backward = -1,
    left = 2,
    right = -2,
    up = 3,
    down = -3
}

local Advanced = {
    FromPosition = {},
    ToPosition = {},
    Route = {},
    LastStepDirection = "none"
}

---Creates new object from prototype Navigation.Advanced.
---@param FromPosition table vector {x,y,z}
---@param ToPosition table vector {x,y,z}
---@return table Advanced
function Advanced:Create(FromPosition, ToPosition)
    local adv = {}
    setmetatable(adv, self)
    self.__index = self
    adv.FromPosition = FromPosition
    adv.ToPosition = ToPosition
    adv.Route = {FromPosition}
    return adv
end

---Returns the entry from route table under the provided index. If index is below
---1, will return the first entry, if index is bigger than #route, will return the
---last entry.
---@param index integer
---@return table routePoint vector {x,y,z}
function Advanced:GetRoutePointSafe(index)
    if index < 1 then
        return self.Route[1]
    elseif index > #self.Route then
        return self.Route[#self.Route]
    else
        return self.Route[index]
    end
end

---Attempts to plot a route from self.fromPosition to self.toPosition. angleMiss
---can be used to plot a side route.
---@param angleMiss number
---@param angleMax number
---@param stepLength number
---@param maxPoints integer
---@return table
function Advanced:PlotRoute(
    angleMiss,
    angleMax,
    stepLength,
    maxPoints
)
    local stepSq = stepLength ^ 2
    local sizeSqThreshold = (stepLength * 0.75) ^ 2
    local maxDistanceSq = vector.SizeSq(self.ToPosition - self.FromPosition)
    local loopSteps = maxPoints - 1
    local iterativeAngleMiss = angleMiss
    local distanceAngleMiss = angleMiss
    local angleCorrectionPerStep = angleMiss / loopSteps * 1.5
    local extentHorizontal = vector:new(stepLength * 0.75, stepLength * 0.75, stepLength * 1.5)
    local extentVertical = vector:new(stepLength * 1.5, stepLength * 1.5, stepLength * 0.75)

    for i = 1, loopSteps do
        local distanceVector = self.ToPosition - self:GetRoutePointSafe(i)
        local distanceSq = vector.SizeSq(distanceVector)
        if distanceSq <= stepSq then
            table.insert(self.Route, self.ToPosition)
            break
        end

        local directionVector = vectors.GetUnitVector(distanceVector)
        local horizontalDirectionVector = vectors.GetUnitVector2D(distanceVector)
        local stepVector = vectors.MultiplyByNumber(
            horizontalDirectionVector,
            stepLength
        )

        local possibleSteps = Advanced:GetPossibleStep(
            self:GetRoutePointSafe(i-1),
            self:GetRoutePointSafe(i),
            stepVector,
            stepLength,
            math.min(iterativeAngleMiss, distanceAngleMiss),
            angleMax,
            sizeSqThreshold,
            extentHorizontal,
            extentVertical
        )

        local nextStep = nil
        local directionList = {}
        if directionVector.z > 0.5 then
            self:AddToDirectionList(directionList, "up")
            self:AddToDirectionList(directionList, "forward")
            self:AddToDirectionList(directionList, "down")
        elseif directionVector.z < -0.5 then
            self:AddToDirectionList(directionList, "down")
            self:AddToDirectionList(directionList, "forward")
            self:AddToDirectionList(directionList, "up")
        else
            self:AddToDirectionList(directionList, "forward")
            self:AddToDirectionList(directionList, "down")
            self:AddToDirectionList(directionList, "up")
        end
        self:AddToDirectionList(directionList, "forward")
        if math.random() > 0.5 then
            self:AddToDirectionList(directionList, "left")
            self:AddToDirectionList(directionList, "right")
        else
            self:AddToDirectionList(directionList, "right")
            self:AddToDirectionList(directionList, "left")
        end
        self:AddToDirectionList(directionList, "backward")

        for _, direction in ipairs(directionList) do
            if possibleSteps[direction] ~= nil then
                print(
                    "@[ " .. i .. " ]" ..
                    " -> " .. direction
                )
                nextStep = possibleSteps[direction]
                self.LastStepDirection = direction
                break
            end
        end
        if nextStep == nil then
            print("@[ " .. i .. " ] -> !!! Stuck !!!")
            break
        end
        table.insert(self.Route, nextStep)

        if math.abs(iterativeAngleMiss) > angleCorrectionPerStep then
            iterativeAngleMiss = iterativeAngleMiss - angleCorrectionPerStep
        else
            iterativeAngleMiss = 0
        end
        distanceAngleMiss = (distanceSq / maxDistanceSq) * angleMiss
    end
    return self.Route
end

---If given direction is not opposite to the self.LastStepDirection will add the
---given direction to the directionList. Helps avoid going back and forth.
---@param directionList table
---@param direction string
function Advanced:AddToDirectionList(directionList, direction)
    if Direction[self.LastStepDirection] ~= -Direction[direction] then
        table.insert(directionList, direction)
    end
end

---Attempts to get all possible steps in all defined directions.
---@param previousStep table vector {x,y,z}
---@param currentStep table vector {x,y,z}
---@param stepVector table vector {x,y,z}
---@param stepLength number
---@param angleMiss number
---@param angleMax number
---@param sizeSqThreshold number
---@param extentHorizontal table vector {x,y,z}
---@param extentVertical table vector {x,y,z}
---@return table
function Advanced:GetPossibleStep(
    previousStep,
    currentStep,
    stepVector,
    stepLength,
    angleMiss,
    angleMax,
    sizeSqThreshold,
    extentHorizontal,
    extentVertical
)
    local possibleSteps = {
        forward = nil,
        backward = nil,
        left = nil,
        right = nil,
        up = nil,
        down = nil,
    }

    possibleSteps.forward = Advanced:GetPossibleHorizontalStep(
        previousStep,
        currentStep,
        stepVector,
        angleMiss,
        angleMax,
        sizeSqThreshold,
        5,
        extentHorizontal
    )

    possibleSteps.backward = Advanced:GetPossibleHorizontalStep(
        previousStep,
        currentStep,
        vectors.GetOppositeVector(stepVector),
        angleMiss,
        angleMax,
        sizeSqThreshold,
        5,
        extentHorizontal
    )

    possibleSteps.left = Advanced:GetPossiblePerpendicularStep(
        previousStep,
        currentStep,
        stepVector,
        angleMiss,
        angleMax,
        false,
        extentHorizontal,
        5,
        sizeSqThreshold
    )

    possibleSteps.right = Advanced:GetPossiblePerpendicularStep(
        previousStep,
        currentStep,
        stepVector,
        angleMiss,
        angleMax,
        true,
        extentHorizontal,
        5,
        sizeSqThreshold
    )

    possibleSteps.up = Advanced:GetPossibleVerticalStep(
        previousStep,
        currentStep,
        stepLength,
        10,
        true,
        sizeSqThreshold,
        extentVertical
    )

    possibleSteps.down = Advanced:GetPossibleVerticalStep(
        previousStep,
        currentStep,
        stepLength,
        10,
        false,
        sizeSqThreshold,
        extentVertical
    )

    return possibleSteps
end

---Attemtpts to get a possible step, i.e. step on nav point within extent, in the
---given direction on horizontal plane. If no points are found will return nil.
---@param previousStep table vector {x,y,z}
---@param currentStep table vector {x,y,z}
---@param stepVector table vector {x,y,z}
---@param angleMiss number
---@param angleMax number
---@param sizeSqThreshold number
---@param tries integer
---@param extent table vector {x,y,z}
---@return table vector {x,y,z}
function Advanced:GetPossibleHorizontalStep(
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
        local chosenDirectionVector = vectors.GetHorizontalyRotatedVector(
            stepVector,
            randomAngle
        )
        local nextStep = common.AttemptStep(
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

---Attempts to get a possible step, i.e. step on nav point within extent, up or down.
---Each try will attempt a longer step. If no points are found will return nil.
---@param previousStep table vector {x,y,z}
---@param currentStep table vector {x,y,z}
---@param stepLength number
---@param tries integer
---@param up boolean
---@param sizeSqThreshold number
---@param extent table vector {x,y,z}
---@return table vector {x,y,z}
function Advanced:GetPossibleVerticalStep(
    previousStep,
    currentStep,
    stepLength,
    tries,
    up,
    sizeSqThreshold,
    extent
)
    local vectorUp = vector:new(0, 0, 1)
    local stepVectorBase
    if up then
        -- print("Trying to get step up")
        stepVectorBase = vectors.MultiplyByNumber(vectorUp, stepLength)
    else
        -- print("Trying to get step down")
        stepVectorBase = vectors.MultiplyByNumber(vectorUp, -stepLength)
    end
    for i = 1, tries do
        local stepVector = vectors.MultiplyByNumber(stepVectorBase, i)
        local newPosition = common.AttemptStep(currentStep, stepVector, extent)
        if newPosition ~= nil then
            local sizeSqToCurrent = vector.SizeSq(newPosition - currentStep)
            local sizeSqToPrevious = vector.SizeSq(newPosition - previousStep)
            if
                sizeSqToCurrent > sizeSqThreshold and
                sizeSqToPrevious > sizeSqThreshold
            then
                -- print(
                --     "New vertical step found at " .. tostring(newPosition) ..
                --     " distance squared from last step " .. sizeSqToCurrent ..
                --     " threshold " .. sizeSqThreshold
                -- )
                return newPosition
            end
        end
    end
    return nil
end

---Attemtpts to get a possible step, i.e. step on nav point within extent, in a
---direction perpendicular to given stepVector on horizontal plane. If no points
---are found will return nil.
---@param previousStep table vector {x,y,z}
---@param currentStep table vector {x,y,z}
---@param stepVector table vector {x,y,z}
---@param angleMiss number
---@param angleMax number
---@param clockwise boolean
---@param extent table vector {x,y,z}
---@param tries integer
---@param sizeSqThreshold number
---@return table vector {x,y,z}
function Advanced:GetPossiblePerpendicularStep(
    previousStep,
    currentStep,
    stepVector,
    angleMiss,
    angleMax,
    clockwise,
    extent,
    tries,
    sizeSqThreshold
)
    -- print("Trying to get perpendicular step")
    local perpendicularVector =
        vectors.GetHorizontalyPerpendicularVector(stepVector, clockwise)
    return Advanced:GetPossibleHorizontalStep(
        previousStep,
        currentStep,
        perpendicularVector,
        angleMiss,
        angleMax,
        sizeSqThreshold,
        tries,
        extent
    )
end

return Advanced
