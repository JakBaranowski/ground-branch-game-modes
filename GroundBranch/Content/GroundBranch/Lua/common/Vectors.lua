local Vectors = {}

Vectors.__index = Vectors

---Divides the vector by the given number.
---@param vector3D table vector {x,y,z} to divide.
---@param divisor number the number to divide by.
---@return table dividedVector {x,y,z} divided vector.
function Vectors.DivideByNumber(vector3D, divisor)
    if divisor == 0 then
        print('Attempting to divide vector by 0')
        return vector:new(0, 0, 0)
    end
    return vector:new(
        vector3D.x / divisor,
        vector3D.y / divisor,
        vector3D.z / divisor
    )
end

---Multiplies the vector by the given number.
---@param vector3D table vector {x,y,z} to multiply.
---@param multiplier number the number to multiply by.
---@return table multipliedVector {x,y,z} multiplied vector.
function Vectors.MultiplyByNumber(vector3D, multiplier)
    return vector:new(
        vector3D.x * multiplier,
        vector3D.y * multiplier,
        vector3D.z * multiplier
    )
end

---Returns a unit vector of the provided vector in 3 dimensions.
---@param vector3D table vector {x,y,z}.
---@return table unitVector3D {x,y,z} 3 dimensional unit vector.
function Vectors.GetUnitVector(vector3D)
    local length = vector.Size(vector3D)
    return Vectors.DivideByNumber(vector3D, length)
end

---Returns a unit vector of the provided vector in 2 dimensions.
---@param vector3Dor2D table vector {x,y,z}.
---@return table unitVector2D {x,y,z} 2 dimensional unit vector.
function Vectors.GetUnitVector2D(vector3Dor2D)
    local vector2D = vector:new(vector3Dor2D.x, vector3Dor2D.y, 0.0)
    local length = vector.Size2D(vector2D)
    return Vectors.DivideByNumber(vector2D, length)
end

---Returns a vector perpendicular to the given vector in the 2 dimensional horizontal
---plane, i.e.: the z coordinate is ignored. Uses simpler calculation than rotating.
---@param vector3Dor2D table vector {x,y,z}.
---@param rotateClockwise boolean should rotate vector clockwise or not?
---@return table perpendicularVector {x,y,z} vector perpendicular to the given vector.
function Vectors.GetHorizontalyPerpendicularVector(vector3Dor2D, rotateClockwise)
    if rotateClockwise then
        return vector:new(vector3Dor2D.y, -vector3Dor2D.x, vector3Dor2D.z)
    else
        return vector:new(-vector3Dor2D.y, vector3Dor2D.x, vector3Dor2D.z)
    end
end

---Returns a vector opposite to the provided vector.
---@param vector3D table vector {x,y,z}.
---@return table oppositeVector {x,y,z} vector opposite to given vector.
function Vectors.GetOppositeVector(vector3D)
    return vector:new(-vector3D.x, -vector3D.y, -vector3D.z)
end

---Returns a vector rotated by given degrees in 2 dimensional horizontal plane,
---i.e. the z coordinate is ignored.
---@param vector3Dor2D table vector {x,y,z}.
---@param angle number degrees to rotate the vector by, positive values rotate clockwise.
---@return table rotatedVector {x,y,z} vector rotated by angle from given vector.
function Vectors.GetHorizontalyRotatedVector(vector3Dor2D, angle)
    local angleRad = math.rad(angle)
    return vector:new(
        math.cos(angleRad) * vector3Dor2D.x - math.sin(angleRad) * vector3Dor2D.y,
        math.sin(angleRad) * vector3Dor2D.x + math.cos(angleRad) * vector3Dor2D.y,
        vector3Dor2D.z
    )
end

return Vectors
