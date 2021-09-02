local WorldPromptBroker = {
    Recipients = {}
}

---Creates a new World Prompt Broker object. Can be used to display world prompts
---to selected players.
---@param  recipients table List of players to display the message to.
---@return table WorldPromptBroker The newly created World Prompt Broker object.
function WorldPromptBroker:Create(recipients)
    local wpb = self
    setmetatable(wpb, self)
    self.__index = self
    self.Recipients = recipients or {}
    print('Initialized World Prompt Broker ' .. tostring(wpb))
    return wpb
end

---Sets the recipients of the world prompt broker.
---@param recipients table List of players to display the world prompt to.
function WorldPromptBroker:SetRecipients(recipients)
    self.Recipients = recipients
end

---Displays the game message to the set recipients.
---@param label string Label of the world prompt.
---@param duration number Duration for which to display the world prompt.
---@param location table vector {x,y,z} Location to place the world prompt at.
function WorldPromptBroker:Display(label, duration, location)
    if self.Recipients and #self.Recipients > 0 then
        for _, playerInstance in ipairs(self.Recipients) do
            player.ShowWorldPrompt(
                playerInstance,
                location,
                label,
                duration
            )
        end
    end
end

return WorldPromptBroker
