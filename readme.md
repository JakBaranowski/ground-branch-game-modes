# Ground Branch game modes

Hi, hungry for some extra game modes? This repo contains custom game modes and missions 
for Ground Branch (and all other files neccessary for them to work).

Keep in mind the game is in early access, and this repo is a work in progress, everything
is subject to change.

## DIY Documentation

Additionally, I'll note stuff that I learn about making game modes in a wiki. Maybe 
someone will find them useful. If you're interested in those start
[here](https://github.com/JakBaranowski/ground-branch-game-modes/wiki).

## How to install

This repository root folder is at the same level as the Ground Branch root folder. This
means that all you need to do is copy the files from this reporsitory over to Ground 
Branch root folder. More details below:

### Using Git

I recommend using Git since it will make it easier to "update" files if needed. Also, 
you'll be able to contribute!

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


### Not using Git

If you just want to download and play the game modes.

1. In the upper right corner of this website click the "Code" dropdown,
2. Click the "Download zip" button,
3. After the download is finished unpack the contents of `ground-branch-game-modes-main` 
folder from within the `ground-branch-game-modes-main.zip` to your Ground Branch 
installation folder (by default:
`C:\Program Files (x86)\Steam\steamapps\common\Ground Branch`).

## How to update

### Using Git

1. Navigate to the Ground Branch root directory 
(by default: `C:\Program Files (x86)\Steam\steamapps\common\Ground Branch`)
2. Open your prefered Git terminal (I recommend 
[Git for Windows](https://gitforwindows.org/))
3. Pull the changes `git pull`

### Not using Git

Follow the same steps as in the installation guide and overwrite all existing files.
