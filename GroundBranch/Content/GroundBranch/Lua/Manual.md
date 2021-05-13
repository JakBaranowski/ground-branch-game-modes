# Ground Branch lua scripts unofficial doc

Please keep in mind that all data presented here was acquired using the good old trial and
error method and therefore most probably is not accurate. However as long as there is no 
official documentation I wanted to create a place where all this data can be gathered.

On top of the above this is very much a WIP, and may never be finished.

### function gamemode:OnRoundStageSet(RoundStage)

Parameters:

* RoundStage - string, possible values:
    * "WaitingForReady" - Players are in ready room. Waiting for players to become ready.
    * "PreRoundWait" - Players are already spawned in the game area, but the round has not started yet.
    * "InProgress" - The round has properly started and is currently in progress.

This method works as a callback for changing round stage. In other words code placed within this method
will be executed whenever a round stage is changed.