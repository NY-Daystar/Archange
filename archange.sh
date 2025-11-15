#!/bin/bash

# ------------------------------------------------------------------
# [Title] : Archange
# [Description] : Save the history of a server, or synced repository between machines
# [Version] : v1.9.0
# [Author] : Lucas Noga
# [Shell] : Bash v5.2.37
# [Usage] : ./archange.sh
#           ./archange.sh --bisync
#           ./archange.sh --sync
#           ./archange.sh --show-history
#           ./archange.sh --verbose
#           ./archange.sh --setup
# ------------------------------------------------------------------

PROJECT_NAME=ARCHANGE
PROJECT_VERSION=v1.9.0

# Parameters to execute script
typeset -A CONFIG=(
    [script_location]="."                              # Get absolute path to where is the script executed
    [settings_prefix]=$PROJECT_NAME                    # For settings.conf variable already used in the system ($USER, $PATH)
    [settings_file]="settings.conf"                    # Configuration file
    [server_file]="HISTORY.txt"                        # File created on the server to get history
    [folder_history]=""                                # Folder to store on the local machine the history
    [filename_history]=HISTORY-$(date +"%Y-%m-%d").txt # Name of the file which will get the copy (default HISTORY_date)
    [default_folder_history]="History"                 # Default Folder to store if no define in settings.conf
    [debug_color]=light_blue                           # Color to show log in debug mode
)

# Options params setup with command parameters
typeset -A OPTIONS=(
    [debug]=false          # Debug mode to show more log if verbose is activated
    [help]=false           # If true we show the help
    [erase_trace]=false    # If true we erase trace on the remote machine
    [history]=false        # If true launch script to show all history files
    [sync]=false           # If true launch script to sync folders
    [bisync]=false          # If true launch script to bisync folders
    [history_number]=-1    # If number positive show the last N history files
    [show_settings]=false  # If true launch script to show configuration file
    [setup_settings]=false # If true launch script to setup configuration file
    [no_details]=false     # if true we get only the file name in our history if not we get ls --format=long --all --recursive --human-readable
)

# Parameters to get access to the remote machine
typeset -A SERVER=(
    [ip]=""       # ip of the server set in configuration file
    [port]=""     # port of the server set in configuration file
    [user]=""     # user of the server set in configuration file
    [password]="" # password of the server set in configuration file
    [path]=""     # path of the server set in configuration file
)

###
# Main body of script starts here
###
function main {
    read_options "$@"
    log_debug "Launch Project $(log_color "${PROJECT_NAME} : ${PROJECT_VERSION}" "magenta")"

    set_settings "script_location" "$(dirname "$0")"
    log_debug "Folder where script localized: $(log_color "${CONFIG[script_location]}" "yellow")"

    execute
}

###
# Show which script to execute default (history)
###
function execute {
    if [ "${OPTIONS[sync]}" == true ]; then
        log_debug "Sync mode"
        read_settings "${CONFIG[settings_file]}" "${CONFIG[script_location]}"
        sync_repository
        return
    elif [ "${OPTIONS[bisync]}" == true ]; then
        log_debug "Bisync mode"
        read_settings "${CONFIG[settings_file]}" "${CONFIG[script_location]}"
        bisync_repository
        return
    elif [ "${OPTIONS[history]}" == true ]; then
        log_debug "Showing history"
        read_settings "${CONFIG[settings_file]}" "${CONFIG[script_location]}"
        show_history "${CONFIG[folder_history]}" "${OPTIONS[history_number]}"
        return
    elif [ "${OPTIONS[help]}" == true ]; then
        help
        return
    elif [ "${OPTIONS[show_settings]}" == true ]; then
        show_settings
        return
    elif [ "${OPTIONS[setup_settings]}" == true ]; then
        setup_settings
        return
    fi

    # Create the file to kept data history of your server
    read_settings "${CONFIG[settings_file]}" "${CONFIG[script_location]}"
    launch_history
}

################################################################### Core ###################################################################

###
# Main method to create history
###
function launch_history {
    setup_folder_history "${CONFIG[folder_history]}"

    get_server_path_history

    # Ask password if no filled in config
    read_server_password

    create_history
    copy_history_to_local

    # Remove file(s) from servers if option is activated
    if [ "${OPTIONS[erase_trace]}" = true ]; then
        erase_trace
    fi
}

###
# Display folders can be synced and select one of them
###
function choose_folder {
    readarray -t folders < <(ls -A "${SERVER[root_folder_sync]}")

    default_remote_root_folder="nas"
    read -p "Do you have a root folder in remote to setup [default: $(log_color "$default_remote_root_folder" "yellow")] : " remote_root_folder
    if [ -z "${remote_root_folder}" ]; then
        remote_root_folder=${default_remote_root_folder}
    fi

    subfolders_number=$(find "${SERVER[root_folder_sync]}" -maxdepth 1 -type d -print| wc -l)

    get_terminal_width
    size=$?
    define_columns ${size}
    col_num=$?

    if [ "${size}" -lt 40 ]; then
        col_num=1
    elif [ "${size}" -lt 80 ]; then
        col_num=2
    else
        col_num=3
    fi
    
    cmd="ls -A ${SERVER[root_folder_sync]} | pr -${col_num}Tn --width $size"
    log_debug "Command executed: $(log_color "${cmd}" "yellow")"
    eval "${cmd}"
    
    read -p "Which folder do you want to sync [1-${subfolders_number}] (type exit to quit) : " response
    if [ "${response}" == "exit" ]; then
        exit 1
    fi
    
    if [ "$(is_a_number "${response}")" = 0 ] || [ "${response}" -lt "0" ] || [ "${response}" -gt "${subfolders_number}" ] ;then 
        log_color "Folder $(log_color "${response}" "yellow") $(log_color "not in range" "red")" "red"
        return;
    fi

    let index=${response}-1
    folder_to_sync=\"${SERVER[root_folder_sync]}/${folders[$index]}\"
    folder_to_sync="${folder_to_sync// /\\ }"

    remote_folder=\"//${SERVER[ip]}/${remote_root_folder}${folder_to_sync//${SERVER[root_folder_sync]}/}\"
    remote_folder="${remote_folder// /\\ }"
}

###
# Choose to sync repository
###
function sync_repository {
    while true; do
        choose_folder
        [[ -z "${folder_to_sync}" ]] && continue

        log "you choose to sync folder $(log_color "${folder_to_sync}" "yellow")"
        cmd="${SERVER[rclone_path]} sync ${folder_to_sync} ${remote_folder} -v --progress --checksum --max-delete 0"
        log_debug "Command executed: $(log_color "${cmd}" "yellow")"

        read -p "Do you want to sync [Y/n] ? " yn
        case $yn in
            [Yy]* ) 
                eval "${cmd}"
                break;;
            [Nn]* ) break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

###
# Choose to bisync repository
###
function bisync_repository {
    while true; do
        choose_folder
        log "you choose to bisync folder $(log_color "${folder_to_sync}" "yellow")"
        
        cmd="${SERVER[rclone_path]} bisync ${folder_to_sync} ${remote_folder} -v --resync"
        log_debug "Command executed: $(log_color "${cmd}" "yellow")" 

        read -p "Do you want to bisync [Y/n] ? " yn
        case $yn in
            [Yy]* ) 
                eval "${cmd}"
                break;;
            [Nn]* ) break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

###
# Main method to show files history
# $1 : [string] path to folder where history files are saved
# $2 : [number] files to show (default: 10), -1 means all
###
function show_history {
    folder=$1
    files_to_show=$2

    exists=$(check_folder_exists "$folder")

    # if not exists exit program
    if [ "${exists}" -eq 0 ]; then
        log "$(log_color "Because folder" "red") $(log_color "${SERVER[path]}" "magenta") $(log_color "doesn't exist in remote machine" "red")"
        exit 1
    fi

    # Command to list history
    cmd_list_history="ls -A1 --reverse '$folder'"

    # If we need to limit the files to show if not we displayed everything
    [ "$(is_a_number "${files_to_show}")" = 1 ] && [ "${files_to_show}" -gt "-1" ] && cmd_list_history+=" | head -${files_to_show}"

    # Display in column depend of the size
    get_terminal_width
    size=$?
    define_columns ${size}
    col_num=$?

    cmd_list_history+=" | pr -${col_num}Tn --width $size"

    log_debug "Command executed: $(log_color "$cmd_list_history" "yellow")"

    # Execute final command
    eval "$cmd_list_history"
}

###
# Create History folder if it doesn't created yet
# $1: Folder History path from config
###
function setup_folder_history {
    folder=$1
    if [ -d "$folder" ]; then
        log_debug "Folder for history: $folder already exists. No need to create it."
    else
        log "Folder $(log_color "$folder" "yellow") doesn't exist.\nCreating..."
        mkdir "$folder"
        log "Folder $(log_color "$folder" "green") Created"
    fi
}

###
# Get folder to copy the file on your local machine and test if it's exist
# $1: Folder path
# Return: [string] folder where we copy the file
###
function get_folder {
    folder=$1
    if [ -z "${folder}" ] || [ ! -d "${folder}" ]; then
        folder="."
    fi
    echo "${folder}"
}

###
# Read server password asked if it's not set in configuration
###
function read_server_password {
    if [ -z "${SERVER[password]}" ]; then
        read -s -p "Type your nas admin password: " SERVER[password]
    fi
}

###
# Get path on the server to get the history
###
function get_server_path_history {
    if [ -z "${SERVER[path]}" ]; then
        read -p "Type the path you want to get history: " SERVER[path]
    fi
    log "Path of the scan history: $(log_color "${SERVER[path]}" "yellow")"
}

###
# Create ssh connection to server and create a file with all history
###
function create_history {
    log_debug "Creating SERVER history..."
    log_debug "Connection to the SERVER..."

    # Check if folder exists
    folder_exists=$(check_server_folder_exists "${SERVER[path]}")
    # if not exists exit program
    if [ "${folder_exists}" -eq 0 ]; then
        log "Please change $(log_color "${CONFIG[settings_prefix]}_PATH" "yellow") in $(log_color "${CONFIG[settings_file]}" "yellow")"
        log "$(log_color "Because folder" "red") $(log_color "${SERVER[path]}" "magenta") $(log_color "doesn't exist in remote machine" "red")"
        exit 1
    else
        log_debug "Path ${SERVER[path]} exists history creating..."
    fi

    # get command to use in remote machine
    cmd=$(get_remote_command)

    sshpass -p "${SERVER[password]}" ssh -p "${SERVER[port]}" "${SERVER[user]}@${SERVER[ip]}" "cd ${SERVER[path]} && ${cmd} > ${CONFIG[server_file]}"  

    ret=$?
    # if something's wrong
    if [ ! $ret -eq 0 ]; then
        log_color "ERROR: Failed to create history with your params." "red"
        log "Exiting..."
        exit 1
    fi
    log "$(log_color "History created on the server here:" "green")" "$(log_color "${SERVER[ip]}:${SERVER[path]}/${CONFIG[server_file]}" "yellow")"
}

###
# Create command to execute in remote machine to get history
# can be with date size and others or just the filename
# return [string] the command to execute in remote machine
###
function get_remote_command {
    cmd=""
    # if only filename is wanted
    if [ "${OPTIONS[no_details]}" = true ]; then
        cmd="ls . -R"
    else # with data formatted
        cmd="ls . -lRh --time-style=+%Y-%m-%d--%H:%M:%S"
    fi
    echo "${cmd}"
}

###
# Copy history file from server to local
###
function copy_history_to_local {
    folder=${CONFIG[folder_history]}
    log_debug "Copy History in local machine...\nConnection to the SERVER..."

    server_path=${SERVER[ip]}:${SERVER[path]}/${CONFIG[server_file]}
    local_path=$folder/${CONFIG[filename_history]}
    log "Copy the file from $(log_color "$server_path" yellow) to $(log_color "$local_path" yellow)"

    # Copy the file
    sshpass -p "${SERVER[password]}" scp -P "${SERVER[port]}" "${SERVER[user]}@${SERVER[ip]}:${SERVER[path]}/${CONFIG[server_file]}" "${folder}/${CONFIG[filename_history]}"

    ret=$?

    # if something's wrong
    if [ ! $ret -eq 0 ]; then
        log_color "ERROR: Failed to retrieve history with your credentials." "red"
        log "Exiting..."
        exit 1
    fi
    log "$(log_color "History copied:" "green")" "$(log_color "${folder}/${CONFIG[filename_history]}" "yellow")"
}

###
# Remove trace of your pass on the server
# For now removing HISTORY.txt file
###
function erase_trace {
    log_debug "Erasing trace..."
    filepath=${SERVER[path]}/${CONFIG[server_file]}

    remove_server_file "${filepath}"

    ret=$?

    # if something's wrong
    if [ ! $ret -eq 0 ]; then
        log_color "ERROR: Trace not erased from server" "red"
        exit 1
    fi
    log_color "Trace erased from remote machine" "green"
}

###
# Remove on remote machine file in filepath in param $1
###
function remove_server_file {
    filepath=$1
    log_debug "Removing File in the server : $(log_color "$filepath" red)"

    # check if file exists
    file_exists=$(check_server_file_exists "$1")

    # if not exists do nothing
    if [ "${file_exists}" -eq 0 ]; then
        log_color "File $filepath doesn't exist anymore" "light_yellow"
        return
    fi

    # remove file
    sshpass -p "${SERVER[password]}" ssh -p "${SERVER[port]}" "${SERVER[user]}@${SERVER[ip]}" -qq -t "rm ${filepath}"

    ret=$?

    # if something's wrong
    if [ ! $ret -eq 0 ]; then
        log_color "ERROR: Failed to remove your file $filepath" "red"
        log "Exiting..."
        exit 1
    fi
    log "File $(log_color "${SERVER[ip]}":"${filepath}" yellow) removed"
}

###
# Check on remote machine if folder exists in param $1
# $1 : [string] folder path to test
# Return: [bool] 1 file exists, 0 if not
###
function check_server_folder_exists {
    folder_path=$1
    sshpass -p "${SERVER[password]}" ssh -p "${SERVER[port]}" "${SERVER[user]}"@"${SERVER[ip]}" -q [[ -d "${folder_path}" ]] && echo 1 || echo 0
}

###
# Check on remote machine if file exists in param $1
# $1 : [string] file path to test
# Return: [bool] 1 file exists, 0 if not
###
function check_server_file_exists {
    filepath=$1
    sshpass -p "${SERVER[password]}" ssh -p "${SERVER[port]}" "${SERVER[user]}"@"${SERVER[ip]}" -q [[ -f "${filepath}" ]] && echo 1 || echo 0
}

################################################################### Settings functions ###################################################################

###
# Read .conf file (default ./setting.conf)
# $1 = name of the settings file (default: settings.conf)
# $2 = path to the settings file (default: ./)
###
function read_settings {
    filename=$1
    path=$2
    if [ -z "${path}" ]; then
        settings_file=$filename
    else 
        settings_file="$path/$filename"
    fi
    log_debug "Read configuration file: $settings_file"
    
    if [ ! -f "$settings_file" ]; then
        log_color "WARN: $settings_file doesn't exists." "yellow"
        log_color "Creating the file ${CONFIG[settings_file]}..." "yellow"
        setup_settings "${CONFIG[settings_file]}"

    fi

    . "$settings_file"
    log_debug "Configuration file $settings_file loaded"

    # Load data to get access to remote machine
    read_settings_server "${settings_file}"

    # If folder doens't define in file config we define it here
    if [ -z "${CONFIG[folder_history]}" ]; then
        folder_history="${CONFIG[script_location]}/${CONFIG[default_folder_history]}"
        set_settings "folder_history" "$folder_history"
        log_debug "No folder history defined. Get default folder: $(log_color "$folder_history" "yellow")"
    fi

    log_debug "Dump: $(declare -p CONFIG)"
    log_debug "Dump: $(declare -p SERVER)"
}

###
# Setup remote machine (user, password, ip, port) from configuration file
# $1 = path to the config file (default: <script_location_path>/settings.conf)
###
function read_settings_server {
    settings_file=$1

    SERVER+=(
        [ip]="$(eval echo "${IP}")"
        [port]="$(eval echo "${PORT}")"
        [user]="$(eval echo \$"${CONFIG[settings_prefix]}"_USER)"
        [password]="$(eval echo "${PASSWORD}")"
        [path]="$(eval echo \$"${CONFIG[settings_prefix]}"_PATH)"
        [root_folder_sync]="$(eval echo "${ROOT_FOLDER_SYNC}")"
        [rclone_path]="$(eval echo "${RCLONE_PATH}")"
    )

    # Check empty values
    if [ -z "${SERVER[ip]}" ]; then
        log_color "ERROR: IP is not defined into $settings_file" "red"
        log "Exiting..."
        exit 1
    fi
    if [ -z "${SERVER[port]}" ]; then
        log_color "ERROR: PORT is not defined into $settings_file" "red"
        log "Exiting..."
        exit 1
    fi
    if [ -z "${SERVER[user]}" ]; then
        log_color "ERROR: USER is not defined into $settings_file" "red"
        log "Exiting..."
        exit 1
    fi
}

###
# List settings in settings.conf file if they are defined
# $1: path where the settings file is (default: "<script_location_path>/settings.conf")
###
function show_settings {
    file=$1
    # get default configuration file if no filled
    if [ -z "${file}" ]; then
        file=${CONFIG[settings_file]}
    fi

    read_settings "${file}"

    log "Here's your settings: "
    log "\t- Ip:" "$(log_color "${SERVER[ip]}" "yellow")"
    log "\t- Port:" "$(log_color "${SERVER[port]}" "yellow")"
    log "\t- User:" "$(log_color "${SERVER[user]}" "yellow")"
    log "\t- Password:" "$(log_color "${SERVER[password]}" "yellow")"
    log "\t- Path:" "$(log_color "${SERVER[path]}" "yellow")"
    log "\t- File where the history will be saved:" "$(log_color "${CONFIG[folder_history]}/${CONFIG[filename_history]}" "yellow")"
    log "\t- Root folder to sync with remote :" "$(log_color "${SERVER[root_folder_sync]}" "yellow")"
    log "\t- Rclone path :" "$(log_color "${SERVER[rclone_path]}" "yellow")"
}

###
# Setup the settings in command line for the user, if the file exists we erased it
# $1: path where the settings file is (default: <script_location_path>/settings.conf")
###
function setup_settings {
    file=$1
    log "Setup settings need some intels to create your settings"
    # get default configuration file if no filled
    if [ -z "${file}" ]; then
        file=${CONFIG[settings_file]}
    fi
    # Check if you want to override the file
    if [ -f "${file}" ]; then
        override=$(ask_yes_no "$(log_color "$file" "yellow") already exists do you want to override it")
        if [ "$override" == false ]; then
            log_color "Abort settings editing - no override" "red"
            exit 0
        fi
    fi

    # DEFAULT VALUES
    typeset -A DEFAULT_VALUES=(
        [IP]="192.168.0.1"
        [PORT]="22"
        [USER]="root"
        [PASSWORD]="root_password"
        [PATH]="/mnt/disk"
        [ROOT_FOLDER_SYNC]=/c
        [RCLONE_PATH]=/c/usr/bin/rclone-v1.70.3/rclone.exe
    )

    log_debug "Dump: $(declare -p DEFAULT_VALUES)"

    # Read value for the user
    ip=$(read_data "Ip of remote machine (default: $(log_color "${DEFAULT_VALUES[IP]}" yellow))" "number")
    port=$(read_data "Port of remote machine (default: $(log_color "${DEFAULT_VALUES[PORT]}" yellow))" "number")
    path=$(read_data "Path of remote machine to save history on your machine (default: $(log_color "${DEFAULT_VALUES[PATH]}" yellow))" "text")
    user=$(read_data "User of remote machine (default: $(log_color "${DEFAULT_VALUES[USER]}" yellow))" "text" 1)
    password=$(read_data "Password of remote machine (default: $(log_color "${DEFAULT_VALUES[PASSWORD]}" yellow))" "password")
    root_folder_sync=$(read_data "Path of local folder to sync with remote (default: $(log_color "${DEFAULT_VALUES[ROOT_FOLDER_SYNC]}" yellow))" "text" 1)
    rclone_path=$(read_data "Path where rclone executable (default: $(log_color "${DEFAULT_VALUES[RCLONE_PATH]}" yellow))" "text" 1)

    typeset -A INPUTS+=(
        [IP]="$ip"
        [PORT]="$port"
        [USER]="$user"
        [PASSWORD]="$password"
        [PATH]="$path"
        [ROOT_FOLDER_SYNC]="$root_folder_sync"
        [RCLONE_PATH]="$rclone_path"
    )

    # Check all the inputs
    check_inputs DEFAULT_VALUES INPUTS

    log_debug "Dump: $(declare -p INPUTS)"

    for data in "${!INPUTS[@]}"; do
        if [ "${data}" == "PASSWORD" ]; then
            log_debug "$data -> ${INPUTS[$data]}"
        else
            log_color "$data -> ${INPUTS[$data]}" "light_blue"
        fi
    done

    confirmation=$(ask_yes_no "$(log_color "Do you want to apply this settings ?" "yellow")")
    if [ "$confirmation" == false ]; then
        log_color "Abort settings editing - no confirmation data" "red"
        exit 0
    fi

    # Write the settings
    write_settings_file "./${file}" "$(declare -p INPUTS)"

    # show the new settings
    show_settings "${file}"

    log "You can now restart the script"
    exit 0
}

###
# Check data filled by user and process it by replacing by default value if conditions are not satisfied
# $1 : [Assoc-Array] Reference of variable DEFAULTS_VALUE before to not get a copy
# $2 : [Assoc-Array] Reference of variable INPUTS before to not get a copy
# return [Assoc-Array] new inputs value
###
function check_inputs {
    declare -n DEFAULTS="$1"
    declare -n DATA="$2"

    for key in "${!DATA[@]}"; do
        val=${DATA[$key]}
        count=${#val}
        default_value=${DEFAULTS[$key]}
        case $key in
        "IP")
            min_char=1
            regex="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
            ;;
        "PORT")
            min_char=1
            regex="^[0-9]{0,5}$"
            ;;
        "USER" | "PATH" | "PORT" )
            min_char=1
            regex=""
            ;;
        "PASSWORD")
            min_char=0
            regex=""
            ;;
        *)
            min_char=1 # Default character to check
            regex=""
            ;;
        esac

        # Do the check on char number
        # if no values
        if [ "${count}" -eq 0 ]; then
            log_debug "Setting default value for $key: ${default_value}"
             DATA+=(["$key"]=${default_value})
            continue
        # if less than expected
        elif [ "${count}" -lt $min_char ]; then
            log_color "Incorrect value for $key you need $min_char characters at least. You have only $count ($val)" "red"
            log "Setting default value for $key: ${default_value}"
            DATA+=(["$key"]=${default_value})
            continue
        fi

        # Check Regex if exists for
        if
            [ ! -z "$regex" ] &
            [[ ! $val =~ $regex ]]
        then
            log_color "Regex not valid for $key (value: \"$val\")" "red"
            log "Setting default value for $(log_color "$key: ${default_value}" "yellow")"
            DATA+=(["$key"]=${default_value})
        fi
    done
}

###
# Write the file settings the settings in command line for the user, if the file exists we erased it
# $1: [string] path where the settings file is (default: "<script_location_path>/settings.conf")
# $2: [array] data to insert into the setting like (ip, user of else)
###
function write_settings_file {
    file=$1
    eval "declare -A DATA=${2#*=}" # eval string into a new associative array

    # if file doesn't exist we create it
    if [ ! -f "${file}" ]; then
        log_debug "Creating $(log_color "$file" "yellow")"
        touch "${file}"
        log_debug "$(log_color "$file" "yellow") Created"
    else
        log_debug "Resetting old settings in $(log_color "$file" "yellow")"
        > "${file}" # Resetting file
        log_debug "$(log_color "$file" "yellow") Reseted"
    fi

        {
        echo IP="${DATA[IP]}"
        echo PORT="${DATA[PORT]}"
        echo "${PROJECT_NAME}"_USER="${DATA[USER]}"
        echo PASSWORD="${DATA[PASSWORD]}"
        echo "${PROJECT_NAME}"_PATH="${DATA[PATH]}"
        echo ROOT_FOLDER_SYNC="${DATA[ROOT_FOLDER_SYNC]}"
        echo RCLONE_PATH="${DATA[RCLONE_PATH]}"
    } >> "$file"
}

###
# Set value to the CONFIG array
# $1 : [string] key to update
# $2 : [string] value to set
###
function set_settings {
    CONFIG+=([$1]=$2)
}

################################################################### Options functions ###################################################################

###
# Read script options like (--verbose)
# -d | --debug : Setup debug mode
# --erase-trace : Erase file and your trace on remote machine
###
function read_options {
    params=("$@") # Convert params into an array

    # Check if debug exists between all parametters
    for param in "${params[@]}"; do
        [[ $param == "-v" ]] || [[ $param == "--verbose" ]] && active_debug_mode
    done

    # Step through all params passed to the script
    for param in "${params[@]}"; do
        IFS="=" read -r key value <<<"${param}"
        case $key in
        "--help")
            log_debug "Help script activated"
            set_option "help" "true"
            ;;
        "--erase-trace")
            log_debug "Erase Trace activated"
            set_option "erase_trace" "true"
            ;;
        "--no-details")
            log_debug "No details activated"
            set_option "no_details" "true"
            ;;
        "--sync")
            set_option "sync" "true"
            ;;
        "--bisync")
            set_option "bisync" "true"
            ;;
        "--history")
            set_option "history" "true"
            [ -n "${value}" ] && set_option "history_number" "$value" # If a value is entered we update the option
            ;;
        "--show-settings")
            set_option "show_settings" "true"
            ;;
        "--setup")
            set_option "setup_settings" "true"
            ;;
        *) ;;
        esac
    done

    log_debug "Dump: $(declare -p OPTIONS)"
}

###
# Active the debug mode by changing options params
###
function active_debug_mode {
    if [ "${OPTIONS[debug]}" == true ]; then
        log_debug "Debug Mode already activated"
        return
    fi
    set_option "debug" "true"
    log_debug "Debug Mode Activated"
}

###
# Set value to the OPTIONS array
# $1 : [string] key to update
# $2 : [string] value to set
###
function set_option {
    OPTIONS+=([$1]=$2)
}

################################################################### Utils functions ###################################################################

###
# Return datetime of now (ex: 2022-01-10 23:20:35)
###
function get_datetime {
    log "$(date '+%Y-%m-%d %H:%M:%S')"
}

###
# Ask yes/no question for user and return boolean
# $1 : question to prompt for the user
###
function ask_yes_no {
    message=$1
    read -r -p "$message [y/N] : " ask
    if [ "$ask" == 'y' ] || [ "$ask" == 'Y' ]; then
        echo true
    else
        echo false
    fi
}

###
# Setup a read value for a user, and return it
# $1: [string] message prompt for the user
# $2: [string] type of data wanted (text, number, password)
# $3: [integer] number of character wanted at least
###
function read_data {
    message=$1
    type=$2
    min_char=$3

    if [ -z "${min_char}" ]; then min_char=0; fi

    read_arguments=""
    case $type in
    "text")
        read_arguments="-r"
        ;;
    "number")
        read_arguments="-r"
        ;;
    "password")
        read_arguments="-rs"
        ;;
    *) ;;
    esac

    # read command value
    read ${read_arguments} -p "${message} : " value

    echo "${value}"
}

###
# Check if folder exists in param $1
# $1 : [string] folder path to test
# Return: [bool] 1 file exists, 0 if not
###
function check_folder_exists {
    folder="$1"
    [[ -d "$folder" ]] && echo 1 || echo 0
}



###
# Get the terminal width in character
# return [number] : width of the terminal screen
###
function get_terminal_width {
    size="$(tput cols)"
    log_debug "Size of terminal ${size}"
    return "${size}"
}

###
# Define columns to show informations correctly on the terminal
# $1 : [number] size of terminal
# Return: [number] columns to display
###
function define_columns {
    size="$1"
    if [ "${size}" -lt 40 ]; then
        columns=1
    elif [ "${size}" -lt 80 ]; then
        columns=2
    else
        columns=3
    fi
    return ${columns}
}

###
# Test if value is a number or not
# $1 : [string] value to test
# return boolean: true if $1 is a number false if not
###
function is_a_number {
    [ "$1" -eq "$1" ] 2>/dev/null && echo 1 || echo 0
}

###

################################################################### Logging functions ###################################################################

###
# Simple log function to support color
###
function log {
    echo -e "$@"
}

typeset -A COLORS=(
    [default]='\033[0;39m'
    [black]='\033[0;30m'
    [red]='\033[0;31m'
    [green]='\033[0;32m'
    [yellow]='\033[0;33m'
    [blue]='\033[0;34m'
    [magenta]='\033[0;35m'
    [cyan]='\033[0;36m'
    [light_gray]='\033[0;37m'
    [light_grey]='\033[0;37m'
    [dark_gray]='\033[0;90m'
    [dark_grey]='\033[0;90m'
    [light_red]='\033[0;91m'
    [light_green]='\033[0;92m'
    [light_yellow]='\033[0;93m'
    [light_blue]='\033[0;94m'
    [light_magenta]='\033[0;95m'
    [light_cyan]='\033[0;96m'
    [nc]='\033[0m' # No Color
)

###
# Log the message in specific color
###
function log_color {
    message=$1
    color=$2
    log "${COLORS[$color]}$message${COLORS[nc]}"
}

###
# Log the message if debug mode is activated
###
function log_debug {
    message=("$@")
    date=$(get_datetime)
    if [ "${OPTIONS[debug]}" = true ]; then log_color "[$date] $message" "${CONFIG[debug_color]}"; fi
}

################################################################################
# Help                                                                         #
################################################################################
help() {
    log "Usage archange [OPTION]..."
    log "Version $PROJECT_VERSION"
    log "Save the history of a server with a ls command by creating a file history in the local machine"
    log
    log "Syntax: archange [-v|--no-details|--setup|--history][--sync]"
    log "Options:"

    log "\t --sync \t Sync one of local folder with remote folder"
    log "\t --bisync \t Bisync one of local folder with remote folder"
    log "\t --erase-trace \t\t Erase trace on the server"
    log "\t --history=<N> \t Show history saved if where N is the number of history files to show (ex: history=5) we display only the last 5 files backups, (default unlimited)"
    log "\t --no-details \t\t Get only the filename in your history file instead of (size, date, etc...)"
    log "\t --setup \t\t Setup configuration file"
    log "\t --show-settings \t Show configuration data with your file"
    log "\t -v, --verbose \t\t Verbose mode"
}

main "$@"
