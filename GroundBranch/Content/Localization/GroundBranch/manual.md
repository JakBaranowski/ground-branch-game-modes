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
commas `,`. 

### Key

is the string Ground Branch will use to try and match the string from the lua script to
a pretty text in the localisation file. As far as I understand partial match is enough, i.e. key 
*has* to contain the queried string, but it *can* have more characters before or after it. E.g. 
`EliminateOpFor` will match `objective_EliminateOpFor`. Feel free to add prefixes to
group your **key**s, but I would recommend to avoid adding suffixes.

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

Given a localistaion file `GroundBranch\Content\Localization\GroundBranch\en\TerroristHunt.csv`

```csv
Key,SourceString,Comment
...
"objective_EliminateOpFor","Locate and eliminate all threats in the area.","Opsboard"
...
``` 

and a lua script `GroundBranch\Content\GroundBranch\Lua\TerroristHunt.lua`

```lua
local terroristhunt = {
    ...
	StringTables = { "TerroristHunt" },
    ...
}
gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "EliminateOpFor", 1)
```

the call `gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "EliminateOpFor", 1)` 
from the script excerpt above will match the string `EliminateOpFor` with a part of the key 
`objective_EliminateOpFor` in the 
`GroundBranch\Content\Localization\GroundBranch\en\TerroristHunt.csv` table, and return the string
`Locate and eliminate all threats in the area.`.
