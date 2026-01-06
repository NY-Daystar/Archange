# Archange project

**_Version v1.9.3_**

![Bash](https://img.shields.io/badge/Bash-444444?style=for-the-badge&logo=gnubash&logoColor=green)  
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/6a23974671c74910938e9aaf753c4253)](https://app.codacy.com/project/badge/Grade/6a23974671c74910938e9aaf753c4253) [![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0) [![Version](https://img.shields.io/github/tag/NY-Daystar/archange.svg)](https://github.com/NY-Daystar/archange/releases)

![GitHub repo size](https://img.shields.io/github/repo-size/ny-daystar/Archange) ![GitHub language count](https://img.shields.io/github/languages/count/ny-daystar/archange) ![GitHub top language](https://img.shields.io/github/languages/top/ny-daystar/archange)

![GitHub issues](https://img.shields.io/github/issues/ny-daystar/archange) ![GitHub closed issues](https://img.shields.io/github/issues-closed-raw/ny-daystar/archange) ![GitHub commit activity (branch)](https://img.shields.io/github/commit-activity/m/ny-daystar/archange/main) [![All Contributors](https://img.shields.io/badge/all_contributors-1-blue.svg?style=circular)](#credits) [![Used By](https://img.shields.io/sourcegraph/rrc/github.com/NY-Daystar/Archange.svg)](https://sourcegraph.com/github.com/NY-Daystar/Archange)

![GitHub watchers](https://img.shields.io/github/watchers/ny-daystar/archange) ![GitHub forks](https://img.shields.io/github/forks/ny-daystar/archange) ![GitHub Repo stars](https://img.shields.io/github/stars/ny-daystar/archange)

C# project to export in csv spotify user's playlist

Script to save the history of a server by creating a file history, and also synchronized files server-to-server.  
Source code analysed with [DeepSource](https://deepsource.com/) and [Codacy](https://app.codacy.com)

Developped in Bash `v5.2.37`

## Index

-   [Get Started](#get-started)
-   [Create alias](#create-a-persistant-alias)
-   [Read man page](#manual-page)
-   [How to use](#how-to-use)
-   [Script options](#script-options)
-   [Export configuration of DSM](#export-configuration-of-dsm)
-   [Manual Process](#manual-process)
-   [Trouble-shootings](#trouble-shootings)
-   [Credits](#credits)

## Get Started

You need to create a file call settings.conf in the repo like this

```bash
git clone https://github.com/LucasNoga/Archange.git && cd archange
```

Then create your configuration file **settings.conf** base on the sample

```bash
cp settings.sample.conf settings.conf
vim settings.conf
```

Put this into the file with your server intels

```bash
IP="XX.XX.XX.XX"
PORT="XX"
USER="XXXXXX"
PASSWORD="XXXXXX"
SOURCE_FOLDER="XXXXXX"
DESTINATION_PATH="XXXXXX"
RCLONE_PATH="XXXXXX"
EXCLUDED_DIRECTORIES="XXXXXXXXXXXXXX"
```

-   IP (optionnal) : Ip of your server, optionnal if you want to use `SOURCE_FOLDER` and `DESTINATION_FOLDER` locally
-   PORT (mandatory): SSH port of your server
-   USER (mandatory): User which has access to the server
-   PASSWORD (optional): Password of the user to get access to the server (if you not specified in your config it will be requested later)
-   SOURCE_FOLDER (optional): Path to the folder in local machine if you want to sync one of its subfolder with remote machine see [sync option](#sync)
-   DESTINATION_PATH (optional): Path on your server to get the history files (if you not specified in your config it will be requested later)
-   RCLONE_PATH (optional) : Path of RCLONE executable to sync folder, see [sync option](#sync)
    you can complete the **XX** with your server credentials, careful your user needs read and write access
-   EXCLUDED_DIRECTORIES (optional) : list of directories to exclude with sync option

Example

```bash
IP="192.168.1.1"
PORT="21"
USER="toto"
PASSWORD="password"
SOURCE_FOLDER=/c
DESTINATION_PATH="/server/dev" # get history files to the folder /server/dev
RCLONE_PATH=/c/usr/bin/rclone-v1.70.3/rclone.exe
EXCLUDED_DIRECTORIES=node_modules,.git,dist
```

## Create a persistant alias

```bash
vim ~/.bash_aliases
```

Then put this line

```bash
alias archange="<PATH_TO_REPO>/archange.sh"
```

Then in your `~/.bashrc` or `~/bash_profile` execute `bash_aliases` with this

```bash
if [ -f ~/.bash_aliases ]; then
. ~/.bash_aliases
fi
```

## Manual page

To install manual page

```bash
sudo cp archange.1 /usr/local/man/man1 && sudo mandb
```

Then you can read it

```bash
man archange
```

## How to use

If you setup the alias

```bash
archange
```

if not

```bash
./archange.sh
```

## Script options

Here's are the options on purpose  
Show help of the script

```bash
./archange.sh --help
```

Display debug mode

```bash
./archange.sh -v
./archange.sh --verbose
```

Only the filename in your history file instead of (size, date, etc...)

```bash
./archange.sh --no-details
```

Show history saved if history=5 we display only the last 5 files backups

```bash
./archange.sh --history
./archange.sh --history=5
```

Show configuration data with your file

```bash
./archange.sh --show-settings
```

Setup configuration file

```bash
./archange.sh --setup
```

Erase trace on the server

```bash
./archange.sh --trace-erase
```

Sync or Bisync from source folder to destination

```bash
./archange.sh --[bi]sync
```

Check duplicate files in folder

```bash
./archange.sh --duplicate
```

#### sync

Use rclone to sync local folder with remote folder  
[Details here with bisync rclone](https://rclone.org/commands/rclone_bisync/)  
[You can download rclone here](https://rclone.org/downloads/)

```bash
./archange.sh --sync
```

## Export configuration of DSM

-   Go to your NAS Synology then go to `Panel Configuration` > `Configuration Backup`
-   Click to `Export`

## Manual Process

-   Connect to your remote machine with ssh command `ssh <USER>@<IP> -p <PORT>`
-   Go to your folder when you want to get history
-   Create a file in your server with `ls -R . > HISTORY.txt` command in choosen repository
-   Copy in your local machine it choosen folder with `scp -p <PORT> <USER>@<IP>:/DESTINATION_PATH/.../HISTORY.txt HISTORY-$(date +"%Y-%m-%d").txt` this file

## Trouble-shootings

If you have any difficulties, problems or enquiries please let me an issue [here](https://github.com/LucasNoga/Archange/issues/new)

## Credits

Made by Lucas Noga  
Licensed under GPLv3.
