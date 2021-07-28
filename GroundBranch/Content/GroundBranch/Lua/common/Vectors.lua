local Vectors = {}

Vectors.__index = Vectors

---Divides the vector by the given number.
---@param vector table vector {x,y,z}
---@param divisor number
---@return table vector {x,y,z}
function Vectors.DivideByNumber(vector, divisor)
    local divisorVector = {
        x = divisor,
        y = divisor,
        z = divisor
    }
    return vector / divisorVector
end

---Multiplies the vector by the given number.
---@param vector table vector {x,y,z}
---@param multiplier number
---@return table vector {x,y,z}
function Vectors.MultiplyByNumber(vector, multiplier)
    local multiplierVector = {
        x = multiplier,
        y = multiplier,
        z = multiplier
    }
    return vector * multiplierVector
end

---Returns a vector perpendicular to the given vector in the 2 dimentional horizontal
---space, i.e.: the z coordinate is ignored. Uses simpler calculation than rotating.
---@param vectorX table vector {x,y,z}
---@param rotateClockwise boolean
---@return table vector {x,y,z}
function Vectors.GetPerpendicularVectorHorizontal(vectorX, rotateClockwise)
    if rotateClockwise then
        return {vectorX.y, -vectorX.x, 0}
    else
        return {-vectorX.y, vectorX.x, 0}
    end
end

---Returns a vector rotated by given degrees in 2 dimensional horizontal space,
---i.e. the z coordinate is ignored.
---@param vectorX table vector {x,y,z}
---@param angle number degrees
---@return table vector {x,y,z}
function Vectors.RotateVectorHorizontal(vectorX, angle)
    local angleRad = math.rad(angle)
    local rotatedVector = {x=0,y=0,z=0}
    rotatedVector.x = math.cos(angleRad) * vectorX.x - math.sin(angleRad) * vectorX.y
    rotatedVector.y = math.sin(angleRad) * vectorX.x + math.cos(angleRad) * vectorX.y
    return rotatedVector
end

return Vectors
