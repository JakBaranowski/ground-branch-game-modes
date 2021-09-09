local Maths = {
    OneOverSquareRootOfThree = 0.57735026918962576450914878050196,
    OneOverSquareRootOfTwo = 0.70710678118654752440084436210485
}

Maths.__index = Maths

---Rounds the given number to integer.
---@param number number number to round.
---@return integer roundedNumber
function Maths.RoundNumberToInt(number)
    local roundNumber = 0
    local floatingPoint = number - math.floor(number)
    if floatingPoint <= 0.5 then
        roundNumber = math.floor(number)
    else
        roundNumber = math.ceil(number)
    end
    print('Rounded number ' .. number .. ' to ' .. roundNumber)
    return roundNumber
end

---Applies deviation, making the resulting integer smaller or bigger, by amount
---provided as deviationInt.
---@param number integer base number that the deviation will be applied to.
---@param deviationInt integer the max absolute deviation.
---@return integer numberWithDeviation number after applying deviation.
function Maths.ApplyDeviationNumber(number, deviationInt)
    local numberDeviation = math.random(-deviationInt, deviationInt)
    return number + numberDeviation
end

---Applies deviation, making the resulting integer smaller or bigger, calculated
---as a deviationPercent of the proivided number.
---@param number number base number that the deviation will be applied to.
---@param deviationPercent number percentage, between 0 and 1.
---@return integer numberWithDeviation number after applying deviation.
function Maths.ApplyDeviationPercent(number, deviationPercent)
    local deviationInt = deviationPercent * number
    deviationInt = math.ceil(deviationInt)
    return Maths.ApplyDeviationNumber(number, deviationInt)
end

return Maths
