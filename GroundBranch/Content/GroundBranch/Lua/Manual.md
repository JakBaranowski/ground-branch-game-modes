# Ground Branch lua scripts unofficial doc

Please keep in mind that all data presented here was acquired using the good old trial and
error method and therefore most probably is not accurate. However as long as there is no 
official documentation I wanted to create a place where all this data can be gathered.

On top of the above this is very much a WIP, and may never be finished.

### function gamemode:OnRoundStageSet(RoundStage)

Parameters:

* RoundStage - string, possible values:
    * "WaitingForReady" - Mission just started, or a round just finished, and players spawned in ready room.
    * "PreRoundWait" - All players clicked ready, or the timer finished. Players are already spawned in the game area, but the round has not started yet.
    * "InProgress" - The round has properly started and is currently in progress.
    * "PostRoundWait" - The round has finshed, but players are still in play area soon to be moved to ready room.

This method works as a callback for changing round stage. In other words code placed within this method
will be executed whenever a round stage is changed.

### function killConfirmed:PlayerInsertionPointChanged(PlayerState, InsertionPoint)

Parameters:

* PlayerState - Information on player state. Dunno much more.
* InsertionPoint - Information on the insertion point selected by the player. Dunno much more.

### function gamemode:PlayerReadyStatusChanged(PlayerState, ReadyStatus)

Parameters:

* PlayerState - Information on player state. Dunno much more.
* ReadyStatus - string, possible values:
    * "WaitingToReadyUp" - Mission just started, or a round just finished, and players spawned in ready room.
    * "DeclaredReady" - Player selected insertion point and therefore declared that he/she is ready to play.

This method works as a callback for changing round stage. In other words code placed within this method
will be executed whenever a round stage is changed.