local training = {
}

function training:PostRun()
	gamemode.AddGameRule("AllowDeadChat")
	gamemode.AddGameRule("AllowUnrestrictedVoice")
	gamemode.AddGameRule("SpectateFreeCam")
	gamemode.AddGameRule("SpectateEnemies")
	SetGameRule("UseReadyRoom", "false")
	SetGameRule("UseRounds", "false")
end

return training
