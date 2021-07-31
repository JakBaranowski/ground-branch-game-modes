local Vectors = {}

Vectors.__index = Vectors

---Divides the vector by the given number.
---@param vectorX table vector {x,y,z}
---@param divisor number
---@return table vector {x,y,z}
function Vectors.DivideByNumber(vectorX, divisor)
    if divisor == 0 then
        print("Attempting to divide vector by 0")
        return vector:new(0, 0, 0)
    end
    return vector:new(
        vectorX.x / divisor,
        vectorX.y / divisor,
        vectorX.z / divisor
    )
end

---Multiplies the vector by the given number.
---@param vectorX table vector {x,y,z}
---@param multiplier number
---@return table vector {x,y,z}
function Vectors.MultiplyByNumber(vectorX, multiplier)
    return vector:new(
        vectorX.x * multiplier,
        vectorX.y * multiplier,
        vectorX.z * multiplier
    )
end

---Returns a unit vector of the provided vector in 3 dimensions.
---@param vectorX table vector {x,y,z}
---@return table vector {x,y,z}
function Vectors.GetUnitVector(vectorX)
    local length = vector.Size(vectorX)
    return Vectors.DivideByNumber(vectorX, length)
end

---Returns a unit vector of the provided vector in 2 dimensions.
---@param vectorX table vector {x,y,z}
---@return table vector {x,y,z}
function Vectors.GetUnitVector2D(vectorX)
    local vector2D = vector:new(vectorX.x, vectorX.y, 0.0)
    local length = vector.Size2D(vector2D)
    return Vectors.DivideByNumber(vector2D, length)
end

---Returns a vector perpendicular to the given vector in the 2 dimentional horizontal
---space, i.e.: the z coordinate is ignored. Uses simpler calculation than rotating.
---@param vectorX table vector {x,y,z}
---@param rotateClockwise boolean
---@return table vector {x,y,z}
function Vectors.GetHorizontalyPerpendicularVector(vectorX, rotateClockwise)
    if rotateClockwise then
        return vector:new(vectorX.y, -vectorX.x, vectorX.z)
    else
        return vector:new(-vectorX.y, vectorX.x, vectorX.z)
    end
end

---Returns a vector opposite to the provided vector.
---@param vectorX table vector {x,y,z}
---@return table vector {x,y,z}
function Vectors.GetOppositeVector(vectorX)
    return vector:new(-vectorX.x, -vectorX.y, -vectorX.z)
end

---Returns a vector rotated by given degrees in 2 dimensional horizontal space,
---i.e. the z coordinate is left as is.
---@param vectorX table vector {x,y,z}
---@param angle number degrees
---@return table vector {x,y,z}
function Vectors.GetHorizontalyRotatedVector(vectorX, angle)
    local angleRad = math.rad(angle)
    return vector:new(
        math.cos(angleRad) * vectorX.x - math.sin(angleRad) * vectorX.y,
        math.sin(angleRad) * vectorX.x + math.cos(angleRad) * vectorX.y,
        vectorX.z
    )
end

return Vectors
