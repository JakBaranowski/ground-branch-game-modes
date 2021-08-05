local GameMessageBroker = {
    Recipients = {},
    Position = 'Engine',
}

GameMessageBroker.__index = GameMessageBroker

---comment
---@param recipients any
---@param position any
---@return table GameMessageBroker
function GameMessageBroker:Create(recipients, position)
    local gmb = self
    setmetatable(gmb, self)
    self.__index = self
    print('Initialized Game Message Broker ' .. tostring(self))
    self.Recipients = recipients or {}
    self.Position = position or 'Engine'
    return gmb
end

function GameMessageBroker:SetRecipients(recipients)
    self.Recipients = recipients
end

function GameMessageBroker:Display(message, duration)
    if not self.Recipients then
        print('No recipients specified')
        return
    end
    for _, playerInstance in ipairs(self.Recipients) do
        player.ShowGameMessage(
            playerInstance,
            message,
            self.Position,
            duration
        )
    end
end

return GameMessageBroker
