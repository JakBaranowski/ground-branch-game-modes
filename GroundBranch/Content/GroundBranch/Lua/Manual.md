[Back to start](/manual.md)

# Lua game mode scripts

Please keep in mind that all data presented here was acquired using the good old trial and
error method and therefore most probably is not accurate. However as long as there is no 
official documentation I wanted to create a place where all this data can be gathered.

On top of the above this is very much a WIP, and may never be finished.


## Lua game mode object

These are function that you should overload when creating your own game mode.

### OnRoundStageSet(RoundStage)

Parameters:

* RoundStage [string] - possible values:
    * "WaitingForReady" - Mission just started, or a round just finished, and players spawned in ready room.
    * "PreRoundWait" - All players clicked ready, or the timer finished. Players are already spawned in the game area, 
    but the round has not started yet.
    * "InProgress" - The round has properly started and is currently in progress.
    * "PostRoundWait" - The round has finshed, but players are still in play area soon to be moved to ready room.

This method works as a callback for changing round stage. In other words code placed within this 
method will be executed whenever a round stage is changed.

### PlayerInsertionPointChanged(PlayerState, InsertionPoint)

Parameters:

* PlayerState - Information on player state. Dunno much more.
* InsertionPoint - Information on the insertion point selected by the player. Dunno much more.

This method works as a callback for changing player insertion point. In other words code placed
within this method will be executed whenever a player selects or changes an insertion point.
### PlayerReadyStatusChanged(PlayerState, ReadyStatus)

Parameters:

* PlayerState - Information on player state. Dunno much more.
* ReadyStatus [string] - possible values:
    * "WaitingToReadyUp" - Mission just started, or a round just finished, and players spawned in 
    ready room.
    * "DeclaredReady" - Player selected insertion point and therefore declared that they are ready 
    to play.

This method works as a callback for changing player ready status. In other words code placed within
this method will be executed whenever a player changes their ready status (currently more or less 
equal to selecting insertion point).

## ai

### CreateOverDuration(duration, amount, spawnsTable, tag)

Parameters:

* **duration** [float] - Time in seconds. The time over which to spawn the AI. Also the AI will be
frozen until this runs out.
* **amount** [int] - the amount of the AI to spawn.
* **spawnsTable** [table] - the table with all the spawn points to spawn the AI in. Will go from the
first to
last entry, and will stop after reaching the **amount**.
* **tag** [string] - this tag will be added to the spawned AI. Keep in mind that the AI will spawn
without a tag
unless you assign on here, regardless of whether the spawn point used has tags or not.

This method will spawn AI over the time specified in **duration**. This method is asynchronus, which
means it will not stop the execution of the remaining code in the script. Moreover there can be only
one "instance" of this method running at any given time. This means that you will need to wait until
the last call is finished before calling it again.

### Create(spawnPoint, tag, freezeTime)

Parameters: 

* **spawnPoint** - a spawn point at which the AI will be spawned.
* **tag** [string] - this tag will be added to the spawned AI. Keep in mind that the AI will spawn
without a tag unless you assign on here, regardless of whether the spawn point used has tags or not.
* **freezeTime** [float] - Time in seconds. AI will be frozen until this time runs out.

This method will spawn a frozen AI at a given **spawnPoint**. The AI will unfreeze after time passed
as **freezeTime**.

### CleanUp(tag)

Parameters:

* **tag** [string] - used to determine which AI instances to clean up.

This method will clean up all AI instances with a given **tag**.

### GetMaxCount()

This method will return an integer specifying the maximum amount of the AI that can be spawned.
I assume that this is a value set up in the game itself, and can't be defined by the user.

## gamemode

### AddGameObjective

### AddGameStat

### AddObjectiveMarker

### BroadcastGameMessage

### EnterPlayArea

### GetPlayerCount

### GetPlayerListByLives

### GetReadyPlayerTeamCounts

### GetRoundStage

### PrepLatecomer

### SetRoundStage

## gameplaystatics

### GetAllActorsOfClass

### GetAllActorsOfClassWithTag
