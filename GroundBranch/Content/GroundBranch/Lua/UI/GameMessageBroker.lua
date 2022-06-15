local GameMessageBroker = {
    Recipients = {},
    Position = 'Engine',
}

GameMessageBroker.__index = GameMessageBroker

---Creates a new Game Message Broker object. Can be used to display game messages
---to selected players.
---@param recipients table List of players to display the message to.
---@param position string Where on HUD should the message be displayed at.
---| 'Engine' Upper left corner of screen. Small orange font.
---| 'Upper' Upper center of screen. Big white font.
---| 'Center' Center of screen. Big white font.
---| 'Lower' Lower center of screen. Big white font.
---@return table GameMessageBroker The newly create Game Message Broker object.
function GameMessageBroker:Create(position, recipients)
    local self = setmetatable({}, GameMessageBroker)
    self.Position = position or 'Engine'
    self.Recipients = recipients or {}
    print('Initialized Game Message Broker ' .. tostring(self))
    return self
end

---Sets the recipients of the game message broker.
---@param recipients table List of players to display the message to.
function GameMessageBroker:SetRecipients(recipients)
    self.Recipients = recipients
end

---Displays the game message to the set recipients.
---@param message string Message to display.
---@param duration number Duration for which to display the message.
function GameMessageBroker:Display(message, duration)
    if self.Recipients and #self.Recipients > 0 then
        for _, playerInstance in ipairs(self.Recipients) do
            player.ShowGameMessage(
                playerInstance,
                message,
                self.Position,
                duration
            )
        end
    end
end

return GameMessageBroker
