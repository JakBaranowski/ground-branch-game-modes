# Ground Branch game modes

## Description

Hi, hungry for some extra game modes? This repo contains custom game modes and missions 
for Ground Branch (and all other files neccessary for them to work).

Keep in mind the game is in early access, and this repo is a work in progress, everything
is subject to change.

### DIY Documentation

Additionally, I'll note stuff that I learn about making game modes in a wiki. Maybe 
someone will find them useful. If you're interested in those start
[here](https://github.com/JakBaranowski/ground-branch-game-modes/wiki).

### Workarounds

I also keep workaround files in the repo. For now it's only 
[WorkaroundAiLoadouts.bat](WorkaroundAiLoadouts.bat) but the list may grow.

* [WorkaroundAiLoadouts.bat](WorkaroundAiLoadouts.bat) will mirror the contents of 
`GroundBranch\Content\GroundBranch\AI\Loadouts\BadGuys` in 
`GroundBranch\Content\GroundBranch\AI\Loadouts\_BadGuys` using empty files to allow
selection of the created loadout file in mission editor.

## Installation

This repository root folder is at the same level as the Ground Branch root folder. This
means that all you need to do is copy the files from this reporsitory over to Ground 
Branch root folder. More details below:

1. In the upper right corner of this website click the "Code" dropdown,
2. Click the "Download zip" button,
3. After the download is finished unpack the contents of `ground-branch-game-modes-main` 
folder from within the `ground-branch-game-modes-main.zip` to your Ground Branch 
installation folder (by default:
`C:\Program Files (x86)\Steam\steamapps\common\Ground Branch`).

## Updating

Follow the same steps as in the installation guide and overwrite all existing files.

## Collaboration

You're more than welcome to clone, fork and send pull requests for this repository.
Below is more info how to set up the repo locally.

### Get the git repository

Git does not allow for cloning repositories to not empty directories, that's why you'll 
need to clone to any empty directory and then copy contents of that directory to Ground 
Branch root directory.

1. Open your prefered Git terminal (I recommend 
[Git for Windows](https://gitforwindows.org/))
2. Clone the repository:
    * HTTPS: `git clone https://github.com/JakBaranowski/ground-branch-game-modes.git`
    * SSH: `git clone git@github.com:JakBaranowski/ground-branch-game-modes.git`
3. Copy files over from the cloned repository to Ground Branch root directory
   (by default: `C:\Program Files (x86)\Steam\steamapps\common\Ground Branch`).

### Pulling changes

1. Navigate to the Ground Branch root directory 
(by default: `C:\Program Files (x86)\Steam\steamapps\common\Ground Branch`)
2. Open your prefered Git terminal (I recommend 
[Git for Windows](https://gitforwindows.org/))
3. Pull the changes `git pull`

## Kudos

* **BlackFoot** Studios for creating Ground Branch.
* **tjl** for creating this awesome 
[Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2461956424).
* **AV** for creating this [Video Tutorial](https://www.youtube.com/playlist?list=PLle5osICJhZJwHxGOb1iBXoyu_uk9yXMY).
* **r1ft4469** for creating this [GitHub repo](https://github.com/r1ft4469/GB-Server-Mods)

## License
