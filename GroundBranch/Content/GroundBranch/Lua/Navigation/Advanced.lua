local Vectors = require('Common.Vectors')
local Common = require('Navigation.Common')

---Direction table maps human-readable directions to numbers in a way that allows
---to easily find opposite direction and compare directions faster.
local Direction = {
    None = 0,
    Forward = 1,
    Backward = -1,
    Left = 2,
    Right = -2,
    Up = 3,
    Down = -3
}

local Advanced = {
    Start = {},
    Destination = {},
    Step = {
        Index = 1,
        Length = 250.0,
        LengthSq = 250.0 ^ 2,
        Threshold = 0.75,
        ThresholdCheck = 5,
        AngleMax = 45.0,
        LastStepDirection = 'None',
    },
    Extents = {
        Horizontal = {},
        Vertical = {},
    },
    Tries = {
        Horizontal = 5,
        Vertical = 10,
    },
    Route = {},
}

---Creates new object of type Navigation.Advanced.
---@param start table vector {x,y,z} starting location.
---@param destination table vector {x,y,z} ending location.
---@param stepLength number length of a single step in centimeters.
---@param minStepThreshold number length below which a step will not be considered valid.
---@param thresholdCheck integer how many previous steps should be checked.
---@return table Advanced a new instance of the Navigation.Advanced prototype.
function Advanced:Create(start, destination, stepLength, minStepThreshold, thresholdCheck)
    local adv = {}
    setmetatable(adv, self)
    self.__index = self
    adv.Route = {start}
    adv.Start = start
    adv.Destination = destination
    adv.Step.Index = 1
    adv.Step.Length = stepLength
    adv.Step.LengthSq = stepLength ^ 2
    adv.Step.Threshold = (stepLength * minStepThreshold) ^ 2
    adv.Step.ThresholdCheck = thresholdCheck
    adv.Extents.Horizontal = vector:new(stepLength * 0.75, stepLength * 0.75, stepLength * 1.5)
    adv.Extents.Vertical =  vector:new(stepLength * 1.5, stepLength * 1.5, stepLength * 0.75)
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

---Attempts to plot a route from Start to Destination. angleMiss can be used to
---plot a route with a tendency to go in specified direction.
---It is possible that the destination will not be reached.
---@param angleMiss number starting angle deviation from the destination vector.
---@param maxSteps integer the maximum amount of steps to take.
---@return table routeSteps a indexed table of route steps. Each step is a vector {x,y,z}.
function Advanced:PlotRoute(
    angleMiss,
    maxSteps
)
    -- print(' --- Started plotting route --- ')

    local loopSteps = maxSteps - 1

    for loopStep = 1, loopSteps do
        self.Step.Index = loopStep

        local distanceVector = self.Destination - self:GetRoutePointSafe(self.Step.Index)
        local distanceSq = vector.SizeSq(distanceVector)
        if distanceSq <= self.Step.LengthSq then
            -- print('@[ ' .. self.Step.Index .. ' ] -> !!! Arrived at destination !!!')
            table.insert(self.Route, self.Destination)
            break
        end

        local directionVector3D = Vectors.GetUnitVector(distanceVector)
        local directionVectorHorizontal = Vectors.GetUnitVector2D(distanceVector)

        local directionList = {}
        if directionVector3D.z > 0.5 then
            self:addToDirectionList(directionList, 'Up')
            self:addToDirectionList(directionList, 'Forward')
            self:addToDirectionList(directionList, 'Down')
        elseif directionVector3D.z < -0.5 then
            self:addToDirectionList(directionList, 'Down')
            self:addToDirectionList(directionList, 'Forward')
            self:addToDirectionList(directionList, 'Up')
        else
            self:addToDirectionList(directionList, 'Forward')
            self:addToDirectionList(directionList, 'Down')
            self:addToDirectionList(directionList, 'Up')
        end
        self:addToDirectionList(directionList, 'Forward')
        if math.random() > 0.5 then
            self:addToDirectionList(directionList, 'Left')
            self:addToDirectionList(directionList, 'Right')
        else
            self:addToDirectionList(directionList, 'Right')
            self:addToDirectionList(directionList, 'Left')
        end
        self:addToDirectionList(directionList, 'Backward')

        local nextStep = nil
        for _, direction in ipairs(directionList) do
            nextStep = self[direction](
                self,
                directionVectorHorizontal,
                ((loopSteps - loopStep) / loopSteps) * angleMiss
            )
            if nextStep ~= nil then
                -- print(
                --     '@[ ' .. self.Step.Index .. ' ]' ..
                --     ' -> ' .. direction
                -- )
                self.LastStepDirection = direction
                break
            end
        end

        if nextStep == nil then
            -- print('@[ ' .. self.Step.Index .. ' ] -> !!! Stuck !!!')
            break
        end

        table.insert(self.Route, nextStep)
    end

    -- print(' --- Finished plotting route --- ')

    return self.Route
end

---Attempts to get a possible step, point on navigation mesh within extent, in the
---given direction on horizontal plane. If no points are found will return nil.
---Should not be called outside of Navigation Advanced PlotRoute method.
---@param stepVector table vector {x,y,z}
---@return table vector {x,y,z}
function Advanced:getPossibleStepHorizontal(stepVector, angleMiss)
    for _ = 1, self.Tries.Horizontal do
        local randomAngle = self.Step.AngleMax * (math.random() - 0.5)
        local angleSum = randomAngle + angleMiss
        local chosenDirectionVector = Vectors.GetHorizontalyRotatedVector(
            stepVector,
            angleSum
        )
        local nextStep = Common.AttemptStep(
            self:GetRoutePointSafe(self.Step.Index),
            chosenDirectionVector,
            self.Extents.Horizontal
        )
        if nextStep ~= nil then
            if self:isOutsideThreshold(nextStep) then
                return nextStep
            end
        end
    end
    return nil
end

---Attempts to get a possible step forward.
---Should not be called outside of Navigation Advanced PlotRoute method.
---@param directionVector table vector {x,y,z}
---@param angleMiss number
---@return table vector {x,y,z}
function Advanced:forward(directionVector, angleMiss)
    local stepVector = Vectors.MultiplyByNumber(directionVector, self.Step.Length)
    return self:getPossibleStepHorizontal(stepVector, angleMiss)
end

---Attempts to get a possible step backward.
---Should not be called outside of Navigation Advanced PlotRoute method.
---@param directionVector table vector {x,y,z}
---@param angleMiss number
---@return table vector {x,y,z}
function Advanced:backward(directionVector, angleMiss)
    local stepVector = Vectors.MultiplyByNumber(directionVector, self.Step.Length)
    stepVector = Vectors.GetOppositeVector(stepVector)
    return self:getPossibleStepHorizontal(stepVector, angleMiss)
end

---Attempts to get a possible step left.
---Should not be called outside of Navigation Advanced PlotRoute method.
---@param directionVector table vector {x,y,z}
---@param angleMiss number
---@return table vector {x,y,z}
function Advanced:left(directionVector, angleMiss)
    local stepVector = Vectors.MultiplyByNumber(directionVector, self.Step.Length)
    stepVector = Vectors.GetHorizontalyPerpendicularVector(stepVector, false)
    return self:getPossibleStepHorizontal(stepVector, angleMiss)
end

---Attempts to get a possible step right.
---Should not be called outside of Navigation Advanced PlotRoute method.
---@param directionVector table vector {x,y,z}
---@param angleMiss number
---@return table vector {x,y,z}
function Advanced:right(directionVector, angleMiss)
    local stepVector = Vectors.MultiplyByNumber(directionVector, self.Step.Length)
    stepVector = Vectors.GetHorizontalyPerpendicularVector(stepVector, true)
    return self:getPossibleStepHorizontal(stepVector, angleMiss)
end

---Attempts to get a possible step, point on navigation mesh within extent, up or down.
---Each try will attempt a longer step. If no points are found will return nil.
---Should not be called outside of Navigation Advanced PlotRoute method.
---@param stepVector table vector {x,y,z}
---@return table vector {x,y,z}
function Advanced:getPossibleStepVertical(stepVector)
    local currentStepVector = stepVector
    for _ = 1, self.Tries.Vertical do
        local nextStep = Common.AttemptStep(
            self:GetRoutePointSafe(self.Step.Index),
            stepVector,
            self.Extents.Vertical
        )
        if nextStep ~= nil then
            if self:isOutsideThreshold(nextStep) then
                return nextStep
            end
        end
        currentStepVector = currentStepVector + stepVector
    end
    return nil
end

---Attempts to get a possible step up.
---Should not be called outside of Navigation Advanced PlotRoute method.
---@param directionVector table vector {x,y,z}
---@param angleMiss number
---@return table vector {x,y,z}
function Advanced:up(directionVector, angleMiss)
    local stepVector = vector:new(0.0, 0.0, self.Step.Length)
    return self:getPossibleStepVertical(stepVector)
end

---Attempts to get a possible step down.
---Should not be called outside of Navigation Advanced PlotRoute method.
---@param directionVector table vector {x,y,z}
---@param angleMiss number
---@return table vector {x,y,z}
function Advanced:down(directionVector, angleMiss)
    local stepVector = vector:new(0.0, 0.0, -self.Step.Length)
    return self:getPossibleStepVertical(stepVector)
end

---If given direction is not opposite to the self.LastStepDirection will add the
---given direction to the directionList. Helps avoid going back and forth.
---Should not be called outside of Navigation Advanced PlotRoute method.
---@param directionList table
---@param direction string
function Advanced:addToDirectionList(directionList, direction)
    if Direction[self.LastStepDirection] ~= -Direction[direction] then
        table.insert(directionList, direction)
    end
end

---Checks if the provided newPoint is outside of the minimum distance threshold.
---Returns true if newPoint is outside threshold, false otherwise.
---Should not be called outside of Navigation Advanced PlotRoute method.
---@param newPoint number
---@return boolean
function Advanced:isOutsideThreshold(newPoint)
    for i = self.Step.Index, self.Step.Index - self.Step.ThresholdCheck + 1, -1 do
        local sizeSqToNew = vector.SizeSq(
            newPoint - self:GetRoutePointSafe(i)
        )
        if sizeSqToNew < self.Step.Threshold then
            return false
        end
    end
    return true
end

return Advanced
