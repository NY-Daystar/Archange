#!/bin/bash

# ------------------------------------------------------------------
# [Title] : Archange
# [Description] : Save the history of a server, or synced repository between machines
# [Version] : v1.9.3
# [Author] : Lucas Noga
# [Shell] : Bash v5.2.37
# [Usage] : ./archange.sh
#           ./archange.sh --bisync
#           ./archange.sh --sync
#           ./archange.sh --duplicate
#           ./archange.sh --show-history
#           ./archange.sh --verbose
#           ./archange.sh --setup
#           ./archange.sh --duplicate
# ------------------------------------------------------------------

PROJECT_NAME=ARCHANGE
PROJECT_VERSION=v1.9.3

# Parameters to execute script
typeset -A CONFIG=(
    [script_location]="."                               # Get absolute path to where is the script executed
    [settings_file]="settings.conf"                     # Configuration file
    [excluded_list_file]="exclude-list.conf"            # Exclude list file for folder 
    [filter_file]="filters.conf"                        # Filter file to use rclone correctly
    [server_file]="HISTORY.txt"                         # File created on the server to get history
    [folder_history]=""                                 # Folder to store on the local machine the history
    [filename_history]=HISTORY-$(date +"%Y-%m-%d").txt  # Name of the file which will get the copy (default HISTORY_date)
    [default_folder_history]="History"                  # Default Folder to store if no define in settings.conf
    [nis_file]="not_in_source.txt"                      # When using sync display file not in source directory
    [duplicate_file]="duplicates.txt"                   # File to list duplicate files in path
    [log_file]="archange.log"                           # File of log when sync is launched
    [debug_color]=light_blue                            # Color to show log in debug mode
)

# Options params setup with command parameters
typeset -A OPTIONS=(
    [debug]=false          # Debug mode to show more log if verbose is activated
    [help]=false           # If true we show the help
    [erase_trace]=false    # If true we erase trace on the remote machine with ip and port configuration
    [history]=false        # If true launch script to show all history files
    [sync]=false           # If true launch script to sync folders
    [bisync]=false         # If true launch script to bisync folders
    [duplicate]=false      # If true launch script to check duplicate files
    [gzip]=false           # If true gzip history file to save disk space
    [history_number]=-1    # If number positive show the last N history files
    [show_settings]=false  # If true launch script to show configuration file
    [setup_settings]=false # If true launch script to setup configuration file
    [no_details]=false     # if true we get only the file name in our history if not we get ls --format=long --all --recursive --human-readable
)

# Parameters to get access to the remote machine for destination folder
typeset -A SETTINGS=(
    [ip]=""             # ip of the server set in configuration file
    [port]=""           # port of the server set in configuration file
    [user]=""           # user of the server set in configuration file
    [password]=""       # password of the server set in configuration file
    [source_folder]=""  # source path to copy on the server
    [path]=""           # destination path of the server set in configuration file
    [rclone_path]=""    # path of rclone to execute sync, bisync commands
    [excluded_list]=""  # list of subfolders to exclude when using sync or bisync (delimited by ,)
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
    read_settings "${CONFIG[settings_file]}" "${CONFIG[script_location]}"
    create_exclude_file

    if [ "${OPTIONS[sync]}" == true ]; then
        log_debug "Sync mode"
        handle_nis_file
        sync_repository
        return
    elif [ "${OPTIONS[bisync]}" == true ]; then
        log_debug "Bisync mode"
        handle_nis_file
        bisync_repository
        return
    elif [ "${OPTIONS[history]}" == true ]; then
        log_debug "Showing history"
        show_history "${CONFIG[folder_history]}" "${OPTIONS[history_number]}"
        return
    elif [ "${OPTIONS[duplicate]}" == true ]; then
        log_debug "Check duplicates"
        check_duplicates
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

    launch_history
}

################################################################### Core ###################################################################

###
# Create file .conf to exclude subfolders
###
function create_exclude_file {   
    > "${CONFIG[excluded_list_file]}" # Resetting file
    {
        echo "# list of subfolders and file to exclude"
        IFS=',' read -ra list <<< "${SETTINGS[excluded_list]}"
        for folder in "${list[@]}"; do
            echo "**/${folder}/"
        done
    } >> "${CONFIG[excluded_list_file]}"

    return 0
}

###
# Main method to create history
###
function launch_history {
    setup_folder_history "${CONFIG[folder_history]}"

    get_server_path_history

    # Ask password if no filled in config
    read_server_password

    create_history
    copy_history

    # Remove file(s) from servers if option is activated
    [[ "${OPTIONS[erase_trace]}" = true ]] && erase_trace
}

###
# Handle nis file because rclone doesn't put all occurences in single try
###
function handle_nis_file {
    [[ ! -f "${CONFIG[nis_file]}" ]] && log_debug "not in source file not exist" && return
    
    words="$(wc -w "${CONFIG[nis_file]}" | awk '{print $1}')"
    if [ "${words}" -ne 0 ];then 
        log_color "WARN: ${CONFIG[nis_file]} is not empty, please check it" "red"
        return
    else 
        rm "${CONFIG[nis_file]}"
    fi
}

###
# Set a destination folder to sync or bisync files
###
function set_destination_folder {
    [[ -n "${SETTINGS[ip]}" ]] && default="//${SETTINGS[ip]}/${SETTINGS[path]}" || default="${SETTINGS[path]}"
    read -p "Setup your destination folder [default: $(log_color "${default}" "yellow")] : " destination_path
    echo
    if [ -z "${destination_folder}" ]; then
        destination_path="${default}"
    elif [ -n "${SETTINGS[ip]}" ]; then
        destination_path="//${SETTINGS[ip]}/${destination_path}"
    fi
    log "Your folder is $(log_color "${destination_path}" "yellow")"
}

###
# Display folders can be synced and select one or several
# $1 : [string] path to destination folder
###
#TODO deepsource et codacy non-conformites
#TODO tester toutes les options avant de faire la release
function choose_directories {
    root_dir="${1:-${SETTINGS[source_folder]}}"
    root_dir=$(echo "${root_dir}" | tr -d '\n')

    subfolders_number=$(find "${root_dir}" -maxdepth 1 -type d -print| wc -l)

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
    
    cmd="ls -A ${root_dir} | pr -${col_num}Tn --width $size"
    log_debug "Command executed: $(log_color "${cmd}" "yellow")"
    eval "${cmd}"
    
    read -p "Which folder do you want [1-${subfolders_number}] (type exit to quit) : " response

    [[ "${response}" == "" ]] && return 
    if [ "${response}" == "exit" ]; then
        exit 1
    fi

    source_dirs=""
    readarray -t folders < <(ls -A "${root_dir}")
    for el in ${response//,/ }; do
            if [ "$(is_a_number "${el}")" = 0 ] || [ "${el}" -lt "0" ] || [ "${el}" -gt "${subfolders_number}" ] ;then 
                log_color "Folder $(log_color "${el}" "yellow") $(log_color "not in range" "red")" "red"
                return;
            fi
            let index=${el}-1
            source_dirs="${source_dirs},${folders[$index]}"
    done
    source_dirs="${source_dirs:1}"

    log "you choose folder $(log_color "${source_dirs}" "yellow")"
    for dir in ${source_dirs//,/ };do
        log "Destination folder: $(log_color "${destination_path}/${dir}" "yellow")"
    done
}

###
# Create filter file to use rclone 
###
function create_filter {
    # insert folders to exclude
    {
        while IFS= read -r line; do
            echo "- ${line}"
        done < "${CONFIG[excluded_list_file]}"
    } > "${CONFIG[filter_file]}"

    # include folders selected
    {
        for dir in ${source_dirs//,/ }; do 
            echo "+ /${dir}/**"
        done
    } >> "${CONFIG[filter_file]}"

    # ignore all the rest
    {
        echo "- *"
    } >> "${CONFIG[filter_file]}"
}

###
# Choose to sync repository
###
function sync_repository {
    set_destination_folder

    while true; do
        choose_directories
        create_filter
        [[ -z "${source_dirs}" ]] && continue

        command="${SETTINGS[rclone_path]} sync ${SETTINGS[source_folder]} ${destination_path} --filter-from='${CONFIG[filter_file]}' -v --progress --checksum --max-delete 0 --error ${CONFIG[nis_file]} --log-file ${CONFIG[log_file]}"
        
        # Dry run in debug mode
        [[ "${OPTIONS[debug]}" = true ]] && log_color "DEBUG MODE DRY_RUN IS ACTIVATED" "magenta" && command="${command} --dry-run"

        read -p "Do you want to sync [Y/n] ? " yn
        case $yn in
            [Yy]* ) 
                log "command executed: $(log_color "${command}" "yellow")"
                eval "${command}"
                continue;;
            [Nn]* ) continue;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

###
# Choose to bisync repository
###
function bisync_repository {
    set_destination_folder

    while true; do
        choose_directories
        create_filter
        [[ -z "${source_dirs}" ]] && continue
        
        command="${SETTINGS[rclone_path]} bisync ${SETTINGS[source_folder]} ${destination_path} --filter-from='${CONFIG[filter_file]}' -v --resync --progress"
        
        # Dry run in debug mode
        [[ "${OPTIONS[debug]}" = true ]] && log_color "DEBUG MODE DRY_RUN IS ACTIVATED" "magenta" && command="${command} --dry-run"

        read -p "Do you want to sync [Y/n] ? " yn
        case $yn in
            [Yy]* ) 
                log "command executed: $(log_color "${command}" "yellow")"
                eval "${command}"
                continue;;
            [Nn]* ) continue;;
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
        log "$(log_color "Because folder" "red") $(log_color "${SETTINGS[path]}" "magenta") $(log_color "doesn't exist in remote machine" "red")"
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
    if [ -z "${SETTINGS[password]}" ]; then
        read -s -p "Type your nas admin password: " SETTINGS[password]
    fi
}

###
# Get path on the server to get the history
###
function get_server_path_history {
    if [ -z "${SETTINGS[path]}" ]; then
        read -p "Type the path you want to get history: " SETTINGS[path]
    fi
    log "Path of the scan history: $(log_color "${SETTINGS[path]}" "yellow")"
}

###
# Create ssh connection to server and create a file with all history
###
function create_history {
    log_debug "Creating SERVER history..."
    log_debug "Connection to the Server..."

    folder_exists=$(check_server_folder_exists "${SETTINGS[path]}")
    if [ "${folder_exists}" -eq 0 ]; then
        log "$(log_color "Folder" "red") $(log_color "${SETTINGS[path]}" "magenta") $(log_color "doesn't exist in remote machine" "red")"
        exit 1
    else
        log_debug "Path ${SETTINGS[path]} exists history creating..."
    fi

    # get command to use in remote machine
    cmd=$(get_remote_command)

    sshpass -p "${SETTINGS[password]}" ssh -p "${SETTINGS[port]}" "${SETTINGS[user]}@${SETTINGS[ip]}" "cd ${SETTINGS[path]} && ${cmd} > ${CONFIG[server_file]}"  

    ret=$?
    # if something's wrong
    if [ ! $ret -eq 0 ]; then
        log_color "ERROR: Failed to create history with your params." "red"
        log "Exiting..."
        exit 1
    fi
    log "$(log_color "History created on the server here:" "green")" "$(log_color "${SETTINGS[ip]}:${SETTINGS[path]}/${CONFIG[server_file]}" "yellow")"
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
# Copy history file in local machine
###
function copy_history {
    log_debug "Copy history in local machine...\nConnection to the SERVER..."

    file_to_copy="${SETTINGS[path]}/${CONFIG[server_file]}"
    destination_path="${CONFIG[folder_history]}/${CONFIG[filename_history]}"
    log "Copy the file from $(log_color "${file_to_copy}" yellow) to $(log_color "${destination_path}" yellow)"

    if [ "${OPTIONS[gzip]}" = true ];then
        log_debug "Gzipping file ${file_to_copy}"
        sshpass -p "${SETTINGS[password]}" ssh -p "${SETTINGS[port]}" "${SETTINGS[user]}@${SETTINGS[ip]}" -qq -t "gzip -f ${file_to_copy}"      
        file_to_copy="${file_to_copy}.gz"
        destination_path="${destination_path}.gz"
    fi

    # Copy the file
    sshpass -p "${SETTINGS[password]}" scp -P "${SETTINGS[port]}" "${SETTINGS[user]}@${SETTINGS[ip]}:${file_to_copy}" "${destination_path}"

    ret=$?

    # if something's wrong
    if [ ! $ret -eq 0 ]; then
        log_color "ERROR: Failed to retrieve history with your credentials." "red"
        log "Exiting..."
        exit 1
    fi
    log "$(log_color "History copied:" "green")" "$(log_color "${destination_path}" "yellow")"
}

###
# Remove trace of your pass on the server
# For now removing HISTORY.txt and HISTORY.txt.gz
###
function erase_trace {
    log_debug "Erasing trace..."
    filepath=${SETTINGS[path]}/${CONFIG[server_file]}

    remove_server_file "${filepath}"
    remove_server_file "${filepath}.gz"

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
    sshpass -p "${SETTINGS[password]}" ssh -p "${SETTINGS[port]}" "${SETTINGS[user]}@${SETTINGS[ip]}" -qq -t "rm ${filepath}"

    ret=$?

    # if something's wrong
    if [ ! $ret -eq 0 ]; then
        log_color "ERROR: Failed to remove your file $filepath" "red"
        log "Exiting..."
        exit 1
    fi
    log "File $(log_color "${SETTINGS[ip]}":"${filepath}" yellow) removed"
}

###
# Set a folder to check duplicates
###
function set_checking_duplicate_folder {
    [[ -n "${SETTINGS[ip]}" ]] && default="//${SETTINGS[ip]}/${SETTINGS[path]}" || default="${SETTINGS[path]}"
    read -p "Which folder do you want to check [default: $(log_color "${default}" "yellow")] : " duplicate_path
    
    if [ -z "${duplicate_path}" ]; then
        duplicate_path="${default}"
    fi
    log "Your duplicate folder is $(log_color "${duplicate_path}" "yellow")"
}

function check_duplicates {
    set_checking_duplicate_folder
    choose_directories "${duplicate_path}"
    
    [[ -z "${source_dirs}" ]] && log_color "Error you select no folder to check" "red" && return

    duplicate_dir="${duplicate_path}/${source_dirs}"
    
    dir_to_exclude=()
    while IFS= read -r line; do
        if [[ ${line} != \#* ]];then
            dir_to_exclude+=( ${line::-1} )
        fi
    done < "${CONFIG[excluded_list_file]}"

    for excluded in "${dir_to_exclude[@]}"; do
        EXCLUDES+=( -path "$excluded" -prune -o )
    done

    declare -A file_groups

    total_files=$(find "${duplicate_dir}" "${FIND_EXCLUDES[@]}" -type f | wc -l)

    let progress=0
    let start_time=$(date +%s)
    let last_print=0

    # Scanning files
    while IFS= read -r file; do
        show_process "Scanning files" "${total_files}" "$((progress++))" "${last_print}" "${start_time}"
        filename="$(basename "$file")"
        key="$filename"
        [[ ${key} == .* ]] && key=${key:1} # remove . in beginning
        key="${key%%.*}"                   # remove multiple extensions
        key="${key,,}"                     # case minus
        #echo v $key
        key="$(echo "$key" \
              | sed -E 's/[ _-]+//g; s/\([0-9]+\)//g; s/é/e/g; s/è/e/g; s/à/a/g; s/ç/c/g; s/ô/o/g; s/€/euros/g; ')"

        #echo $key - $file
        file_groups["$key"]+="${file}"$'\n'
        
    done < <(
        find "${duplicate_dir}" \
            "${EXCLUDES[@]}" \
            -type f
    )
    log_color "Scan finished : ${progress} / ${total} files" "green"

    # Display groups with duplicates
    rm -f "${CONFIG["duplicate_file"]}"
    group_id=0
    for key in "${!file_groups[@]}"; do
        count=$(echo -n "${file_groups[${key}]}" | grep -c '^')
        if (( count > 1 )); then
            group_id=$((group_id + 1))

            log_color "🟦 Group ${group_id} - ${key}" "magenta"
            while IFS= read -r line; do
                    printf "   - %s\n" "$line"
            done <<< "${file_groups[$key]}"
            echo
            {
                echo "🟦 Group ${group_id} - ${key}"
                while IFS= read -r line; do
                    printf "   - %s\n" "$line"
                done <<< "${file_groups[$key]}"
                echo
            } >> "${CONFIG["duplicate_file"]}"
        fi
    done
    
}

###
# Display message to show progression of process
###
function show_process(){
    message="${1:-"<PROCESS>"}"
    total="${2:-"<TOTAL>"}"
    processed="${3:-"<PROCESSED>"}"
    last_print="${4:-"$(date +%s)"}"
    start="${5:-"$(date +%s)"}"
    interval=3
    now=$(date +%s)

    if (( now - last_print >= interval )); then
        percent=$(( processed * 100 / total ))
        elapsed=$(( now - start ))
        echo -ne "\r⏳ ${message} : ${processed} / ${total} files processed (${percent}%) - ${elapsed}s\r"
        last_print="${now}"
    fi
}

###
# Check on remote machine if folder exists in param $1
# $1 : [string] folder path to test
# Return: [bool] 1 file exists, 0 if not
###
function check_server_folder_exists {
    folder_path=$1
    sshpass -p "${SETTINGS[password]}" ssh -p "${SETTINGS[port]}" "${SETTINGS[user]}"@"${SETTINGS[ip]}" -q [[ -d "${folder_path}" ]] && echo 1 || echo 0
}

###
# Check on remote machine if file exists in param $1
# $1 : [string] file path to test
# Return: [bool] 1 file exists, 0 if not
###
function check_server_file_exists {
    filepath=$1
    sshpass -p "${SETTINGS[password]}" ssh -p "${SETTINGS[port]}" "${SETTINGS[user]}"@"${SETTINGS[ip]}" -q [[ -f "${filepath}" ]] && echo 1 || echo 0
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

    . "${settings_file}"
    log_debug "Configuration file $settings_file loaded"

    # Load data to get access to remote machine
    SETTINGS+=(
        [ip]="$(eval echo "${IP}")"
        [port]="$(eval echo "${PORT}")"
        [user]="$(eval echo "${USER}")"
        [password]="$(eval echo "${PASSWORD}")"
        [path]="$(eval echo "${DESTINATION_PATH}")"
        [source_folder]="$(eval echo "${SOURCE_FOLDER}")"
        [rclone_path]="$(eval echo "${RCLONE_PATH}")"
        [excluded_list]="$(eval echo "${EXCLUDED_DIRECTORIES}")"
    )

    error="false"
    # Check empty values
    if [ -z "${SETTINGS[port]}" ]; then
        log_color "ERROR: PORT is not defined into ${settings_file}" "red"
        error="true"
    fi
    if [ -z "${SETTINGS[user]}" ]; then
        log_color "ERROR: USER is not defined into ${settings_file}" "red"
        error="true"
    fi

    if [ "${error}" == true ];then
        log_color "Your settings file is invalid, you need to setup it" "red"
        setup_settings
        return
    fi

    # If folder doens't define in file config we define it here
    if [ -z "${CONFIG[folder_history]}" ]; then
        folder_history="${CONFIG[script_location]}/${CONFIG[default_folder_history]}"
        set_settings "folder_history" "$folder_history"
        log_debug "No folder history defined. Get default folder: $(log_color "$folder_history" "yellow")"
    fi

    log_debug "Dump: $(declare -p CONFIG)"
    log_debug "Dump: $(declare -p SETTINGS)"
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
    log "\t- Ip: $(log_color "${SETTINGS[ip]}" "yellow")"
    log "\t- Port: $(log_color "${SETTINGS[port]}" "yellow")"
    log "\t- User: $(log_color "${SETTINGS[user]}" "yellow")"
    log "\t- Password: $(log_color "${SETTINGS[password]}" "yellow")"
    log "\t- File where the history will be saved: $(log_color "${CONFIG[folder_history]}/${CONFIG[filename_history]}" "yellow")"
    log "\t- Source path : $(log_color "${SETTINGS[source_folder]}" "yellow")"
    log "\t- Destination path : $(log_color "${SETTINGS[path]}" "yellow")"
    log "\t- Rclone path : $(log_color "${SETTINGS[rclone_path]}" "yellow")"
    log "\t- Excluded folders : $(log_color "${SETTINGS[excluded_list]}" "yellow")"
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

    default_settings_file="settings.sample.conf"

    # DEFAULT VALUES
    typeset -A DEFAULT_VALUES=(
        [IP]=$(grep -Po "(?<=IP=).+" ${default_settings_file})
        [PORT]=$(grep -Po "(?<=PORT=).+" ${default_settings_file})
        [USER]=$(grep -Po "(?<=USER=).+" ${default_settings_file})
        [PASSWORD]=$(grep -Po "(?<=PASSWORD=).+" ${default_settings_file})
        [SOURCE_FOLDER]=$(grep -Po "(?<=SOURCE_FOLDER=).+" ${default_settings_file})
        [DESTINATION_PATH]=$(grep -Po "(?<=DESTINATION_PATH=).+" ${default_settings_file})
        [RCLONE_PATH]=$(grep -Po "(?<=RCLONE_PATH=).+" ${default_settings_file})
        [EXCLUDED_DIRECTORIES]=$(grep -Po "(?<=EXCLUDED_DIRECTORIES=).+" ${default_settings_file})
    )

    log_debug "Dump: $(declare -p DEFAULT_VALUES)"
 
    # Read value for the user
    ip=$(read_data "Ip of remote machine (default: $(log_color "${DEFAULT_VALUES[IP]}" yellow))" "number")
    port=$(read_data "Port of remote machine (default: $(log_color "${DEFAULT_VALUES[PORT]}" yellow))" "number")
    path=$(read_data "Destination path of remote machine to save history on your machine (default: $(log_color "${DEFAULT_VALUES[DESTINATION_PATH]}" yellow))" "text")
    user=$(read_data "User of remote machine (default: $(log_color "${DEFAULT_VALUES[USER]}" yellow))" "text" 1)
    password=$(read_data "Password of remote machine (default: $(log_color "${DEFAULT_VALUES[PASSWORD]}" yellow))" "password")
    source_folder=$(read_data "Path of source folder to sync with destination path (default: $(log_color "${DEFAULT_VALUES[SOURCE_FOLDER]}" yellow))" "text" 1)
    rclone_path=$(read_data "Path where rclone executable (default: $(log_color "${DEFAULT_VALUES[RCLONE_PATH]}" yellow))" "text" 1)
    excluded_directories=$(read_data "List of directories to exclude (default: $(log_color "${DEFAULT_VALUES[EXCLUDED_DIRECTORIES]}" yellow))" "text" 1)

    typeset -A INPUTS+=(
        [IP]="$ip"
        [PORT]="$port"
        [USER]="$user"
        [PASSWORD]="$password"
        [DESTINATION_PATH]="$path"
        [SOURCE_FOLDER]="$source_folder"
        [RCLONE_PATH]="$rclone_path"
        [EXCLUDED_DIRECTORIES]="$excluded_directories"
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

    log_color "You can now restart the script" "magenta"
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
        "USER" | "PORT" )
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
        echo USER="${DATA[USER]}"
        echo PASSWORD="${DATA[PASSWORD]}"
        echo SOURCE_FOLDER="${DATA[SOURCE_FOLDER]}"
        echo DESTINATION_PATH="${DATA[DESTINATION_PATH]}"
        echo RCLONE_PATH="${DATA[RCLONE_PATH]}"
        echo EXCLUDED_DIRECTORIES="${DATA[EXCLUDED_DIRECTORIES]}"
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
        "-h" | "--help")
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
        "--duplicate")
            set_option "duplicate" "true"
            ;;
        "--gzip")
            set_option "gzip" "true"
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
    log "Usage archange [OPTIONS]..."
    log "Version $PROJECT_VERSION"
    log "Save the history of a server with a ls command by creating a file history in the local machine"
    log
    log "Syntax: archange [-v|--no-details|--setup|--history][--sync][--bisync][--duplicate]"
    log "Options:"

    log "\t --sync \t Sync one of local source folder with destination folder"
    log "\t --bisync \t Bisync one of local source folder with destination folder"
    log "\t --erase-trace \t Erase trace on the server"
    log "\t --history=<N> \t Show history saved if where N is the number of history files to show"
    log "\t --no-details \t Get only the filename in your history file instead of (size, date, etc...)"
    log "\t --setup \t Setup configuration file"
    log "\t --show-settings Show configuration data with your file"
    log "\t -v, --verbose \t Verbose mode"
}

main "$@"
