local vectors = require("Common.Vectors")
local common = require("Navigation.Common")

---Direction table maps human-readeable directions to numbers in a way that allows
---to easily find opposite direction and compare direction faster.
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
        AngleMax = 45.0,
        LastStepDirection = "None",
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

---Creates new object from prototype Navigation.Advanced.
---@param start table vector {x,y,z}
---@param destination table vector {x,y,z}
---@param stepLength number
---@param minStepThreshold number
---@return table Advanced
function Advanced:Create(start, destination, stepLength, minStepThreshold)
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
    adv.Extents.Horizontal = vector:new(stepLength * 0.75, stepLength * 0.75, stepLength * 1.5)
    adv.Extents.Vertical =  vector:new(stepLength * 1.5, stepLength * 1.5, stepLength * 0.75)
    return adv
end

---Attempts to plot a route from self.Start to self.Destination. angleMiss
---can be used to plot a side route.
---@param angleMiss number
---@param maxPoints integer
---@return table
function Advanced:PlotRoute(
    angleMiss,
    maxPoints
)
    print(" --- Started plotting route --- ")

    local loopSteps = maxPoints - 1
    local angleMissCurrent = angleMiss
    local angleCorrectionPerStep = angleMiss / loopSteps * 1.5

    for loopStep = 1, loopSteps do
        self.Step.Index = loopStep

        local distanceVector = self.Destination - self:GetRoutePointSafe(self.Step.Index)
        local distanceSq = vector.SizeSq(distanceVector)
        if distanceSq <= self.Step.LengthSq then
            print("@[ " .. self.Step.Index .. " ] -> !!! Arrived at destination !!!")
            table.insert(self.Route, self.Destination)
            break
        end

        local directionVector3D = vectors.GetUnitVector(distanceVector)
        local directionVectorHorizontal = vectors.GetUnitVector2D(distanceVector)

        local directionList = {}
        if directionVector3D.z > 0.5 then
            self:AddToDirectionList(directionList, "Up")
            self:AddToDirectionList(directionList, "Forward")
            self:AddToDirectionList(directionList, "Down")
        elseif directionVector3D.z < -0.5 then
            self:AddToDirectionList(directionList, "Down")
            self:AddToDirectionList(directionList, "Forward")
            self:AddToDirectionList(directionList, "Up")
        else
            self:AddToDirectionList(directionList, "Forward")
            self:AddToDirectionList(directionList, "Down")
            self:AddToDirectionList(directionList, "Up")
        end
        self:AddToDirectionList(directionList, "Forward")
        if math.random() > 0.5 then
            self:AddToDirectionList(directionList, "Left")
            self:AddToDirectionList(directionList, "Right")
        else
            self:AddToDirectionList(directionList, "Right")
            self:AddToDirectionList(directionList, "Left")
        end
        self:AddToDirectionList(directionList, "Backward")

        local nextStep = nil
        for _, direction in ipairs(directionList) do
            nextStep = self[direction](self, directionVectorHorizontal, angleMissCurrent)
            if nextStep ~= nil then
                print(
                    "@[ " .. self.Step.Index .. " ]" ..
                    " -> " .. direction
                )
                self.LastStepDirection = direction
                break
            end
        end

        if nextStep == nil then
            print("@[ " .. self.Step.Index .. " ] -> !!! Stuck !!!")
            break
        end

        table.insert(self.Route, nextStep)

        if math.abs(angleMissCurrent) > angleCorrectionPerStep then
            angleMissCurrent = angleMissCurrent - angleCorrectionPerStep
        else
            angleMissCurrent = 0
        end
    end

    print(" --- Finished plotting route --- ")

    return self.Route
end

---Helper function for getting a possible step forward.
---Should not be called outside of Navigation.Advanced class.
---@param directionVector table vector {x,y,z}
---@param angleMiss number
---@return table vector {x,y,z}
function Advanced:Forward(directionVector, angleMiss)
    local stepVector = vectors.MultiplyByNumber(directionVector, self.Step.Length)
    return self:GetPossibleStepHorizontal(stepVector, angleMiss)
end

---Helper function for getting a possible step backward.
---Should not be called outside of Navigation.Advanced class.
---@param directionVector table vector {x,y,z}
---@param angleMiss number
---@return table vector {x,y,z}
function Advanced:Backward(directionVector, angleMiss)
    local stepVector = vectors.MultiplyByNumber(directionVector, self.Step.Length)
    stepVector = vectors.GetOppositeVector(stepVector)
    return self:GetPossibleStepHorizontal(stepVector, angleMiss)
end

---Helper function for getting a possible step left.
---Should not be called outside of Navigation.Advanced class.
---@param directionVector table vector {x,y,z}
---@param angleMiss number
---@return table vector {x,y,z}
function Advanced:Left(directionVector, angleMiss)
    local stepVector = vectors.MultiplyByNumber(directionVector, self.Step.Length)
    stepVector = vectors.GetHorizontalyPerpendicularVector(stepVector, false)
    return self:GetPossibleStepHorizontal(stepVector, angleMiss)
end

---Helper function for getting a possible step right.
---Should not be called outside of Navigation.Advanced class.
---@param directionVector table vector {x,y,z}
---@param angleMiss number
---@return table vector {x,y,z}
function Advanced:Right(directionVector, angleMiss)
    local stepVector = vectors.MultiplyByNumber(directionVector, self.Step.Length)
    stepVector = vectors.GetHorizontalyPerpendicularVector(stepVector, true)
    return self:GetPossibleStepHorizontal(stepVector, angleMiss)
end

---Helper function for getting a possible step up.
---Should not be called outside of Navigation.Advanced class.
---@param directionVector table vector {x,y,z}
---@param angleMiss number
---@return table vector {x,y,z}
function Advanced:Up(directionVector, angleMiss)
    local stepVector = vector:new(0.0, 0.0, self.Step.Length)
    return self:GetPossibleStepVertical(stepVector)
end

---Helper function for getting a possible step down.
---Should not be called outside of Navigation.Advanced class.
---@param directionVector table vector {x,y,z}
---@param angleMiss number
---@return table vector {x,y,z}
function Advanced:Down(directionVector, angleMiss)
    local stepVector = vector:new(0.0, 0.0, -self.Step.Length)
    return self:GetPossibleStepVertical(stepVector)
end

---Attemtpts to get a possible step, i.e. step on nav point within extent, in the
---given direction on horizontal plane. If no points are found will return nil.
---@param stepVector table vector {x,y,z}
---@return table vector {x,y,z}
function Advanced:GetPossibleStepHorizontal(stepVector, angleMiss)
    for _ = 1, self.Tries.Horizontal do
        local randomAngle = self.Step.AngleMax * (math.random() - 0.5)
        local angleSum = randomAngle + angleMiss
        local chosenDirectionVector = vectors.GetHorizontalyRotatedVector(
            stepVector,
            angleSum
        )
        local nextStep = common.AttemptStep(
            self:GetRoutePointSafe(self.Step.Index),
            chosenDirectionVector,
            self.Extents.Horizontal
        )
        if nextStep ~= nil then
            if self:IsOutsideThreshold(nextStep, 3) then
                return nextStep
            end
        end
    end
    return nil
end

---Attempts to get a possible step, i.e. step on nav point within extent, up or down.
---Each try will attempt a longer step. If no points are found will return nil.
---@param stepVector table vector {x,y,z}
---@return table vector {x,y,z}
function Advanced:GetPossibleStepVertical(stepVector)
    local currentStepVector = stepVector
    for _ = 1, self.Tries.Vertical do
        local nextStep = common.AttemptStep(
            self:GetRoutePointSafe(self.Step.Index),
            stepVector,
            self.Extents.Vertical
        )
        if nextStep ~= nil then
            if self:IsOutsideThreshold(nextStep, 3) then
                return nextStep
            end
        end
        currentStepVector = currentStepVector + stepVector
    end
    return nil
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

---If given direction is not opposite to the self.LastStepDirection will add the
---given direction to the directionList. Helps avoid going back and forth.
---@param directionList table
---@param direction string
function Advanced:AddToDirectionList(directionList, direction)
    if Direction[self.LastStepDirection] ~= -Direction[direction] then
        table.insert(directionList, direction)
    end
end

---Checks if the provided newPoint is outside of the minimum distance threshold.
---Returns true if newPoint is outside threshold, false otherwise.
---@param newPoint number
---@param pointsToCheck number
---@return boolean
function Advanced:IsOutsideThreshold(newPoint, pointsToCheck)
    for i = self.Step.Index, self.Step.Index - pointsToCheck + 1, -1 do
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
