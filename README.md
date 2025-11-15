# Archange project

**_Version v1.8.0_**

Save the history of a server by creating a file history

Developped in Bash `v5.2.37`

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Version](https://img.shields.io/github/tag/LucasNoga/Archange.svg)](https://github.com/NY-Daystar/Archange/releases)
[![Total views](https://img.shields.io/sourcegraph/rrc/github.com/NY-Daystar/Archange.svg)](https://sourcegraph.com/github.com/NY-Daystar/Archange)

![GitHub watchers](https://img.shields.io/github/watchers/ny-daystar/Archange)
![GitHub forks](https://img.shields.io/github/forks/ny-daystar/Archange)
![GitHub Repo stars](https://img.shields.io/github/stars/ny-daystar/Archange)
![GitHub repo size](https://img.shields.io/github/repo-size/ny-daystar/Archange)
![GitHub language count](https://img.shields.io/github/languages/count/ny-daystar/Archange)
![GitHub top language](https://img.shields.io/github/languages/top/ny-daystar/Archange) <a href="https://codeclimate.com/github/ny-daystar/Archange/maintainability"><img src="https://api.codeclimate.com/v1/badges/715c6f3ffb08de5ca621/maintainability" /></a>  
![GitHub commit activity (branch)](https://img.shields.io/github/commit-activity/m/ny-daystar/Archange/main)
![GitHub issues](https://img.shields.io/github/issues/ny-daystar/Archange)
![GitHub closed issues](https://img.shields.io/github/issues-closed-raw/ny-daystar/Archange)
[![All Contributors](https://img.shields.io/badge/all_contributors-1-blue.svg?style=circular)](#contributors)

![Bash](https://img.shields.io/badge/Bash-444444?style=for-the-badge&logo=gnubash&logoColor=green)

## Index

-   [Comming Next](#comming-next)
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
$ git clone https://github.com/LucasNoga/Archange.git
$ cd archange
```

Then create your configuration file **settings.conf** base on the sample

```bash
$ cp settings.sample.conf settings.conf
$ vim settings.conf
```

Put this into the file with your server intels

```bash
IP="XX.XX.XX.XX"
PORT="XX"
ARCHANGE_USER="XXXXXX"
PASSWORD="XXXXXX"
ARCHANGE_PATH="XXXXXX"
ROOT_FOLDER_SYNC="XXXXXX"
RCLONE_PATH="XXXXXX"
```

-   IP (mandatory) : Ip of your server
-   PORT (mandatory): SSH port of your server
-   ARCHANGE_USER (mandatory): User which has access to the server
-   PASSWORD (optional): Password of the user to get access to the server (if you not specified in your config it will be requested later)
-   ARCHANGE_PATH (optional): Path on your server to get the history files (if you not specified in your config it will be requested later )
-   ROOT_FOLDER_SYNC (optional): [sync option](#sync)- Path to the folder in local machine if you want to sync one of its subfolder with remote machine
-   RCLONE_PATH (optional) : [sync option](#sync) - Path of RCLONE executable to sync folder
    you can complete the **XX** with your server credentials, careful your user needs read and write access

Example

```bash
IP="192.168.1.1"
PORT="21"
ARCHANGE_USER="toto"
PASSWORD="password"
ARCHANGE_PATH="/server/dev" # get history files to the folder /server/dev
FOLDER_HISTORY="./MyHistory" # Store files into the folder ./MyHistory
ROOT_FOLDER_SYNC=/c
RCLONE_PATH=/c/usr/bin/rclone-v1.70.3/rclone.exe
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
$ archange
```

if not

```bash
$ ./archange.sh
```

## Script options

Here's are the options on purpose  
Show help of the script

```bash
$ ./archange.sh --help
```

Display debug mode

```bash
$ ./archange.sh -v
$ ./archange.sh --verbose
```

Only the filename in your history file instead of (size, date, etc...)

```bash
$ ./archange.sh --no-details
```

Show history saved if history=5 we display only the last 5 files backups

```bash
$ ./archange.sh --history
$ ./archange.sh --history=5
```

Show configuration data with your file

```bash
$ ./archange.sh --show-settings
```

Setup configuration file

```bash
$ ./archange.sh --setup
```

Erase trace on the server

```bash
$ ./archange.sh --trace-erase
```

#### sync

Use rclone to sync local folder with remote folder  
[Details here with bisync rclone](https://rclone.org/commands/rclone_bisync/)  
[You can download rclone here](https://rclone.org/downloads/)

```bash
$ ./archange.sh --sync
```

## Export configuration of DSM

-   Go to your NAS Synology then go to `Panel Configuration` > `Configuration Backup`
-   Click to `Export`

## Manual Process

-   Connect to your remote machine with ssh command `ssh <USER>@<IP> -p <PORT>`
-   Go to your folder when you want to get history
-   Create a file in your server with `ls -R . > HISTORY.txt` command in choosen repository
-   Copy in your local machine it choosen folder with `scp -p <PORT> <USER>@<IP>:/PATH/.../HISTORY.txt HISTORY-$(date +"%Y-%m-%d").txt` this file

## Trouble-shootings

If you have any difficulties, problems or enquiries please let me an issue [here](https://github.com/LucasNoga/Archange/issues/new)

## Credits

Made by Lucas Noga  
Licensed under GPLv3.
