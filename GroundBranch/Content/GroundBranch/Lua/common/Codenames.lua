local Codenames = {
    phonetic = {
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
}

Codenames.__index = Codenames

---Returns nth letter from the phonetic alphabet. If n is bigger than the length
---of phonetic alphabet a suffix (1,2,3...) will be added.
---@param n integer
---@return string
function Codenames.Get(n)
    local safeIndex
    if n <= #Codenames.phonetic then
        safeIndex = n
        return Codenames.phonetic[safeIndex]
    else
        local suffix = math.floor(n / Codenames.phonetic)
        safeIndex = n % #Codenames.phonetic
        if safeIndex == 0 then
            safeIndex = #Codenames.phonetic
        end
        return Codenames.phonetic[safeIndex] .. suffix
    end
end

---Returns nth letter from the phonetic alphabet prefixed with provided string.
---If n is bigger than the length of phonetic alphabet a suffix (1,2,3...) will
---be added.
---@param prefix string
---@param n integer
---@return string
function Codenames.GetPrefixedCodename(prefix, n)
    return prefix .. Codenames.Get(n)
end

return Codenames
