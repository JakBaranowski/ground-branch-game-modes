# Ground Branch game modes

## Recommended tools

### Visual Studio Code

You can edit lua scripts and csv tables using any text editor but I recommend using Visual Studio Code
it's free and has all the features you'll need.

### Git for Windows

Moreover, I recommend using Git for Windows. Of course any bash terminal will do. Not only will it allow
you to clone this repo (or even contribute to it) it will also allow you to easily `tail` the Ground Branch
log file which in turn will help you debug issue with your game mode (or discover the issue is with Ground Branch).

## Keep in mind

Ground Branch is in Early Access and a lot of it is still subject to change. Some stuff may not be 
implemented yet, work poorly, require workarounds or not work at all. Don't get discouraged or
blame the devs. It's really awesome that they shared the tools we use here with community in such 
an early stage. Go tell them you appreciate this.

## Tips and tricks

### Play test often

Remember to play test often. Hardest mistake to find is the one that you made a long time ago.
This basically means: open Ground Branch, set up as simple mission for your game mode and play it
every time you make any change to the script (or to the mission).

### Follow the Ground Branch log files when debugging

The simplest way to tail the Ground Branch log file is to open up Git for Windows (or any other bash terminal)
and use the following command

```
tail -f ~/AppData/Local/GroundBranch/Saved/Logs/GroundBranch.log
```

It may fail if the file does not exist. To resolve just launch Ground Branch first.

## Table of contents

### Lua scripts

[Lua game mode scripts](/GroundBranch/Content/GroundBranch/Lua/Manual.md)

Directory: [/GroundBranch/Content/GroundBranch/Lua/](/GroundBranch/Content/GroundBranch/Lua)

Lua scripts in this directory define the rules of game modes availble in Ground Branch.

### Localization tables

[Localization files](/GroundBranch/Content/Localization/GroundBranch/manual.md)

Directory: [/GroundBranch/Content/Localization/GroundBranch/](/GroundBranch/Content/Localization/GroundBranch)

This directory contains tables with text localizations in a `.csv` format. We'll be mostly interested
with the contents of the `/en/` folder as it contains tables with texts used by game modes. 
Also, as far as I know only English is supported at the moment.

### Mission files

Directory: [/GroundBranch/Content/GroundBranch/Mission/](/GroundBranch/Content/GroundBranch/Mission/)

Mission files contain all enemy, objectives etc. placement on specified maps. Mission files will be
located in folders named the same as the map they are assigned to. Don't try to edit theese with code
editors.
