#!/bin/bash
###########################################################################
#
# Bash shell script that patches other scripts to make them portable 
# across other Linux systems that use bash as their SHELL.
#
#    Copyright (C) 2021  Andrew Nisbet, Edmonton Public Library
# The Edmonton Public Library respectfully acknowledges that we sit on
# Treaty 6 territory, traditional lands of First Nations and Metis people.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
#########################################################################
VERSION=2.00.06
APP_NAME="patchsaas"
TRUE=0
FALSE=1
# Make sure $HOME is set to a directory, and this script is running from it.
[ -z "$HOME" ] && { echo "\$HOME not set??" >&2 ; exit 1 ; }
[ -d "$HOME" ] || { echo "$HOME not a directory." >&2 ; exit 1 ; }
if [[ "$HOME" != $(pwd) ]]; then echo "Script must be run from $HOME. Move it there and try again." >&2; exit 1; fi
WORK_DIR="$HOME"
BAK=$(date +"%Y%m%d_%H%M%S")
TARBALL="$WORK_DIR/${APP_NAME}.${BAK}.tar"
LOG_FILE="$WORK_DIR/${APP_NAME}.log"


# Displays the usage for this product.
# param:  none
# return: none
usage()
{
    cat << EOFU!
    
    
 Usage: ${APP_NAME}.sh [flags]
 
 Modifies scripts en masse. This script is meant to help with porting multiple scripts to run in a 
 new Linux environment. The modifications are done through sed commands which are read from a file 
 specified with the -s switch.
 
 If the script successfully modifies a single file, the log of transactions, the sed script of commands
 and the original unmodified script are backed up in a timestamped tarball. The timestamp reads as 
 YYYYMMDD_HHMMSS. For example, if run now, the backup file would be "$TARBALL".
 
 This means that every time you run the script you create a mile stone of modifications. To roll back
 simply untar the files in reverse chronological order.

Flags:
 -h, -help, --help: This help message.
 -i, -input_list, --input_list [file]: Required. Specifies the list scripts to target for patching.
    File names should include the relative path to the $HOME directory. For example, if you want the file
    $HOME/foo/bar.sh to be patched, add foo/bar.sh as a line to the input list file. All files in this
    list will be modified in the same way. See -s for more information.
 -r, -restore, --restore: Rolls back script changes to any checkpoint. 
    Restores all the files in all the patch.*.tar files in reverse chronological order.
    You will be asked to confirm each transaction. The log file is unaffected by restores.
    If there are no patchsaas.*.tar files to restore from, ls will emit an error that 
    it could not find a file called 'patchsaas.*.tar'.
 -s, -sed_file, --sed_file [file]: Required. File that contaiins the sed commands used to modify scripts.
    The sed commands should be thoroughly tested before modifying scripts as complex sed commands 
    are notoriously tricky.
 -v, -version, --version: Print script version and exits.
   
 Example:
    ./${APP_NAME}.sh --input_list ./scripts_to_port.txt -s sed_commands.sed
    
    
EOFU!
}

# Logs messages to STDERR and $LOG file.
# param:  Log file name. The file is expected to be a fully qualified path or the output
#         will be directed to a file in the directory the script's running directory.
# param:  Message to put in the file.
# param:  (Optional) name of a operation that called this function.
logit()
{
    local message="$1"
    local time=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$time] $message" >>$LOG_FILE
    echo "[$time] $message" >&2
}

# Asks if user would like to do what the message says.
# param:  message string.
# return: 0 if the answer was yes and 1 otherwise.
confirm()
{
	if [ -z "$1" ]; then
		echo "** error, confirm_yes requires a message." >&2
		exit $FALSE
	fi
	local message="$1"
	echo -n "$message? y/[n]: " >&2
	read answer
	case "$answer" in
		[yY])
			echo "yes selected." >&2
			return $TRUE
			;;
		*)
			echo "no selected." >&2
			return $FALSE
			;;
	esac
}

# Takes a relative path as argument patches it. Saves a timestamped version of the file so 
# running it multiple times doesn't overwrite any backups in the tarball.
# param:  name of the sed file script to run.
# param:  file name with path relative to $HOME. Exmaple: foo/bar/baz.sh
patch_file()
{
    local sed_file="$1"
    local original="$2"
    local temp="$original.bak"
    # Can fail if disk full or what ever.
    if cp "$original" "$temp"; then
        # Backup the original to a timestamped tarball
        if ! tar rvf "$TARBALL" "${original}"; then
            logit "**error: failed to back up $original skipping..."
            return $FALSE
        fi
        # overwrite original with modifications.
        if sed -f "$sed_file" < "$temp" > "$original"; then
            # get rid of the temp file.
            rm "$temp"
            return $TRUE
        fi
    else
        logit "**error, $original failed to be copied prior to editing, skipping."
        return $FALSE
    fi
    return $FALSE
}

# Restores all the files in all the patch.*.tar files in reverse chronological order.
# You will be asked to confirm each transaction. The log file is unaffected by restores.
#
# If there are no patchsaas.*.tar files to restore from, ls will emit an error that 
# it could not find a file called 'patchsaas.*.tar'. 
# param:  none.
restore()
{
    local tarball=""
    local last_tarball=""
    # list the tarballs in reverse chronological order to undo the most recent first.
    for tarball in $(ls -tc1 ${APP_NAME}.*.tar); do
        if [ -f "$tarball" ]; then
            if $(confirm "restore files from '$tarball'"); then
                # Extract all the files except the log file since 
                # that would wipe the on-going history of events.
                if tar xvf "$tarball" --exclude="${APP_NAME}.log" 2>&1 >>"$LOG_FILE"; then
                    logit "restored files from '$tarball'"
                    last_tarball="$tarball"
                else
                    logit "**error, failed to restore files from $tarball."
                    return $FALSE
                fi
            else
                [[ -z "$last_tarball" ]] || logit "restore complete"
                return $FALSE
            fi
        else
            logit "*warn, expected $tarball to be a regular file. Skipping."
        fi
    done
    return $TRUE
}

export target_script_patching_file=$FALSE
export sed_script_file=$FALSE

# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "help,input_list:,restore,sed_file:,version" -o "hi:rs:v" -a -- "$@")
if [ $? != 0 ] ; then echo "Failed to parse options...exiting." >&2 ; exit 1 ; fi
# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters 
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"

while true
do
    case $1 in
    -h|--help) 
        usage
        exit 0
        ;;
    -i|--input_list)
        shift
        export target_script_patching_file="$1"
        ;;
    -r|--restore)
        if restore; then exit 0; else exit 1; fi
        ;;
    -s|--sed_file)
        shift
        export sed_script_file="$1"
        ;;
    -v|--version) 
        echo "$APP_NAME version: $VERSION"
        exit 0
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done
: ${sed_script_file:?Missing -s,--sed_file} ${target_script_patching_file:?Missing -i,--input_list}
### Actual work happens here.
# Test if the input script is readable.
if [ -r "$target_script_patching_file" ]; then
    logit "processng files found in $target_script_patching_file with commands found in $sed_script_file"
    attempts=0
    lines=0
    patched=0
    while IFS= read -r script_name; do
        lines=$((lines+1))
        if [ -r "$script_name" ]; then
            if [ -r "$sed_script_file" ]; then
                attempts=$((attempts+1))
                if patch_file "$sed_script_file" "$script_name"; then
                    logit "patched: $script_name"
                    patched=$((patched+1))
                else
                    logit "patch_file() refused to patch $script_name"
                fi
            else
                logit "**error, sed script file was not found, was empty, or could not be read."
                exit 1
            fi
        else
            logit "*warn: skipping $script_name because it could not be found, was empty, or could not be read."
        fi
    done < "$target_script_patching_file"
    logit "---"
    logit "read: $lines, analysed: $attempts, patched: $patched"
    if [ -r "$TARBALL" ]; then
        tar rvf "$TARBALL" "${APP_NAME}.log" "$target_script_patching_file" "$sed_script_file" >/dev/null
    fi
    exit 0
else
    logit "**error, the target script file was either missing, empty, or unreadable."
    usage
    exit 1
fi
