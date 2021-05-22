local Codenames = {}

Codenames.__index = Codenames

local phonetic = {
    "Alpha",
    "Bravo",
    "Charlie",
    "Delta",
    "Echo",
    "Foxtrot",
    "Golf",
    "Hotel",
    "India",
    "Juliet",
    "Kilo",
    "Lima",
    "Mike",
    "November",
    "Oscar",
    "Papa",
    "Quebec",
    "Romeo",
    "Sierra",
    "Tango",
    "Uniform",
    "Victor",
    "Whiskey",
    "Yankee",
    "X-ray",
    "Zulu",
}

---Returns nth letter from the phonetic alphabet
---@param n integer
---@return string
function Codenames.Get(n)
    local safeIndex
    if n == #phonetic then
        safeIndex = n
    else
        safeIndex = n % #phonetic
    end
    return phonetic[safeIndex]
end

---Returns nth letter from the phonetic alphabet prefixed with provided stirng
---@param prefix string
---@param n integer
---@return string
function Codenames.GetPrefixedCodename(prefix, n)
    return prefix .. Codenames.Get(n)
end

return Codenames
