local Strings = {}

Strings.__index = Strings

---StartsWith will check if the given string starts with the specified prefix and
---return true if so, false otherwise.
---@param stringCheck string
---@param prefix string
---@return boolean
function Strings.StartsWith(stringCheck, prefix)
    if string.sub(stringCheck, 1, #prefix) == prefix then
        return true
    end
    return false
end

---GetSuffix will check if the given string starts with specified prefix and if
---so will return the suffix, otherwise will return empty string.
---@param stringCheck string
---@param prefix string
---@return string
function Strings.GetSuffix(stringCheck, prefix)
    if string.sub(stringCheck, 1, #prefix) == prefix then
        return string.sub(stringCheck, #prefix + 1)
    end
    return ''
end

return Strings
