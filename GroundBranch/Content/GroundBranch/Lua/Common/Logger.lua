--- Logging facilities

local DEFAULT_LEVEL = 'INFO'
-- uncomment the next line to enable DEBUG logging by default
--DEFAULT_LEVEL = 'DEBUG'

local Logger = {
    -- hook for testing
    toStringFunction = tostring
}

local LogLevels = {
    DEBUG = 100,
    INFO = 200,
    WARN = 300,
    ERROR = 400,
    OFF = 100000,
}

local function split_print(s)
    for str in string.gmatch(s, "([^\n]+)") do
        print(str)
    end
end

--- Create a logger
---@param name string the logger name
---@param print_function function function for printing the output
function Logger.new(name, print_function)
    local self = setmetatable({}, {__index = Logger})

    self.name = name or 'Unnamed logger'
    self.logLevel = LogLevels[DEFAULT_LEVEL] or LogLevels.DEBUG
    self.outputFunction = print_function or split_print

    return self
end

-- cycle-aware object to string function
local function stringify_helper(cache, result, object, level, indent_string, tostring)
    local arrow = ' = '
    local tab = string.rep(indent_string, level)
    local tab_next = string.rep(indent_string, level + 1)

    if type(object) == 'table' or type(object) == 'function' then
        if cache[object] then
            table.insert(result, tostring(object))
            table.insert(result, ' -- (Cyclic)')
            return
        end
        cache[object] = true
    end

    if type(object) == 'table' then
        table.insert(result, '{ -- ')
        table.insert(result, tostring(object))
        table.insert(result, '\n')

        local keys = {}
        for key, _ in pairs(object) do
            table.insert(keys, key)
        end
        table.sort(keys)

        for i = 1, #keys do
            local key = keys[i]
            local value = object[key]

            table.insert(result, tab_next)
            stringify_helper(cache, result, key, level + 1, indent_string, tostring)
            table.insert(result, arrow)

            stringify_helper(cache, result, value, level + 1, indent_string, tostring)
            table.insert(result, ',\n')
        end

        table.insert(result, tab)
        table.insert(result, '}')
    elseif type(object) == 'function' then
        local info = debug.getinfo(object)
        local info_condensed = {
            isvararg = info.isvararg,
            nparams = info.nparams
        }
        table.insert(result, tostring(object))
        table.insert(result, ' ')
        stringify_helper(cache, result, info_condensed, level, indent_string, tostring)
    elseif type(object) == 'userdata' then
        local mt = getmetatable(object)
        if mt == nil then
            table.insert(result, tostring(object))
            table.insert(result, ' with no Metatable')
        elseif mt.__tostring then
            table.insert(result, 'userdata ')
            table.insert(result, mt.__tostring(object))
        else
            table.insert(result, tostring(object))
            table.insert(result, ' with Metatable ')
            stringify_helper(cache, result, mt, level, indent_string, tostring)
        end
    elseif type(object) == 'string' then
        table.insert(result, '"')
        table.insert(result, object)
        table.insert(result, '"')
    else
        table.insert(result, tostring(object))
    end
end

--- Convert an object to a string
---@param object any object to convert
---@return string
function Logger:Stringify(object)
    local result = {}
    stringify_helper({}, result, object, 0,'  ', self.toStringFunction)
    return table.concat(result)
end

-- Internal function for printing
function Logger:_PrintMessage(name, level, msg, obj)
    local max_file_name = 20
    local separator = ' - '
    local separator_cont = '     '

    -- Print messages like this
    --  INFO  GameMode             - Some message
    --  INFO  GameMode             - Some message: with argument
    --  ERROR Util                 - Some message: with
    --  ERROR Util                     a very long argument

    local t = {}
    table.insert(t, level)
    table.insert(t,' ')
    if #level == 4 then
        table.insert(t,' ')
    end

    if #name < max_file_name then
        table.insert(t, name)
        table.insert(t, string.rep(' ', max_file_name - #name))
    else
        table.insert(t, string.sub(name, 1, max_file_name))
    end

    if obj == nil then
        table.insert(t, separator)
        table.insert(t, msg)
    else
        local prefix = '\n' .. table.concat(t) .. separator_cont
        table.insert(t, separator)
        table.insert(t, msg)
        table.insert(t, ': ')

        local s = string.gsub(self:Stringify(obj), '\n', function()
            return prefix
        end)
        table.insert(t, s)
    end

    self.outputFunction(table.concat(t))
end

function Logger:IsDebugEnabled()
    return self.logLevel <= LogLevels.DEBUG
end

function Logger:Debug(msg, object)
    if self:IsDebugEnabled() then
        self:_PrintMessage(self.name, 'DEBUG', msg, object)
    end
end

function Logger:IsInfoEnabled()
    return self.logLevel <= LogLevels.INFO
end

function Logger:Info(msg, object)
    if self:IsInfoEnabled() then
        self:_PrintMessage(self.name, 'INFO', msg, object)
    end
end

function Logger:IsWarnEnabled()
    return self.logLevel <= LogLevels.WARN
end

function Logger:Warn(msg, object)
    if self:IsWarnEnabled() then
        self:_PrintMessage(self.name, 'WARN', msg, object)
    end
end

function Logger:IsErrorEnabled()
    return self.logLevel <= LogLevels.ERROR
end

function Logger:Error(msg, object)
    if self:IsErrorEnabled() then
        self:_PrintMessage(self.name, 'ERROR', msg, object)
    end
end

function Logger:SetLogLevel(level)
    self.logLevel = LogLevels[level] or LogLevels.DEBUG
end

return Logger
