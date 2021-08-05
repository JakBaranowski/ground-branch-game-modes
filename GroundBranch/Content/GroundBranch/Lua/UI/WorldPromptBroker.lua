local WorldPromptBroker = {
    Recipients = {}
}

WorldPromptBroker.__index = WorldPromptBroker

function WorldPromptBroker:Create(recipients)
    local wpb = self
    setmetatable(wpb, self)
    self.__index = self
    print('Initialized World Prompt Broker ' .. tostring(self))
    self.Recipients = recipients or {}
    return wpb
end

function WorldPromptBroker:SetRecipients(playersToShowTo)
    self.Recipients = playersToShowTo
end

function WorldPromptBroker:Display(label, duration, location)
    if not self.Recipients then
        print('No recipients specified')
        return
    end
	for _, playerInstance in ipairs(self.Recipients) do
		player.ShowWorldPrompt(
			playerInstance,
			location,
			label,
			duration
		)
	end
end

return WorldPromptBroker
