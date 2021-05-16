[Back to start](/manual.md)

# Ground Branch localization tables

Ever wondered why something like this:

```lua
gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "EliminateOpFor", 1)
```

adds a game objective with nice text `Locate and eliminate all threats in the area` instead of
`EliminateOpFor`? Localization files is why.

## 1. Creating a localization file for your game mode

Simply create a `.csv` in the [/en](/en) folder. Name it whatever you want but remember to:

* Keep the `.csv` extension,
* steer clear of white spaces or special characters,
* note the file name you'll need it later.

Better yet copy one of the files existing in the [/en](/en) folder, rename it to whatever you
like and use it as a template.

## 2. Setting up the translations

First line of the `.csv` file has to be:

```csv
Key,SourceString,Comment
```

This line defines the order of data in each row. Now every following row should contain 
of three strings each surrounded by double quotes `"` and separated from each other with
commas `,`, like so:

```csv
"missionsetting_opforcount","Expected resistance","Opsboard"
```

### Key

This is where most of the magic happens. Key is the string Ground Branch will use to try 
and match the string from the lua script to a pretty text in the localisation file. Key 
has two parts separated by the first underscore:

* **prefix** is the part before the first underscore and has to be one of the following:
    * `objective` if it is supposed to go on the objective board, 
    used by `gamemode.AddGameObjective`
    * `summary` if it is supposed to be displayed in the after action report,
    used by `gamemode.AddGameStat("Summary=...")`
    * `gamemessage` if it is supposed to be displayd as a in game message,
    used by `gamemode.BroadcastGameMessage`
    * `missionsetting` if it is supposed to be displayed as a mission setting, 
    this is not used by any function but will be used to "translate" mission settings.
* **name** this is the part that will be used to match the string provided in any of 
the lua functions mentioned above.

Note: `missionsetting` is a special case - the name provided in the `.csv` will be matched
against the names of the variables in the game mode settings table. Also name of the 
`missionsetting` should be all lower case.

### SourceString

is the pretty string that will be used instead of the key if the key matches.

### Comment

can be anything you want and is mostly here for you. ;-)

## 3. Letting your lua script know

First of all you'll need to define the name of the localization table you want to use in your
game mode. You can do that by adding a `StringTables` variable to your gamemode in the lua script.
If I understand correctly you can add multiple string tables to a single game mode, but did not try this.

```lua
local killConfirmed = {
	...
	StringTables = {"KillConfirmed"},
    ...
}
```

Now you start using the **Key**s you from your localisation file in your lua script.

## Example

Given a localistaion file `GroundBranch\Content\Localization\GroundBranch\en\KillConfirmed.csv`

```csv
Key,SourceString,Comment
"missionsetting_opforcount","Expected resistance","Opsboard"
"objective_ExtractionPoint","Locate and eliminate all threats in the area.","Opsboard"
"gamemessage_HighValueTargetEliminated","HVT eliminated.","objective"
"summary_OpForLeaderEliminated","High Value Targets were eliminated.","AAR"
``` 

First tell the script where to look for the slugs:

```lua
local terroristhunt = {
...
	StringTables = { "KillConfirmed" },
...
```

Then the `missionsetting_opforcount` slug will match mission settings variable `OpForCount`
like this:

```lua
...
    Settings = {
        OpForCount = {
            Min = 0,
            Max = 50,
            Value = 15,
        },
    },
...
}
...
```

And following that the code below will match

* `ExfiltrateBluFor` with `objective_ExfiltrateBluFor`,
* `HighValueTargetEliminated` with `gamemessage_HighValueTargetEliminated`, and last
* `OpForLeaderEliminated` with `summary_OpForLeaderEliminated`.

```lua
...
    gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "ExfiltrateBluFor", 1)
...
    gamemode.BroadcastGameMessage("HighValueTargetEliminated", "Engine", 5.0)
...
    gamemode.AddGameStat("Summary=OpForLeaderEliminated")
...
```
