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
# tar --extract --file=archive.tar file1.txt
VERSION=0.0
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


# Displays the usage for this product.
# param:  none
# return: none
usage()
{
    cat << EOFU!
 Usage: ${APP_NAME}.sh [flags]
 
 Runs load tests on the ILS.

Flags:
 -h, -help, --help: This help message.
 -i, -input_list, --input_list [file]: specifies the list scripts to target for patching.
    File names should include the relative path to the $HOME directory.
 -v, -version, --version: Print script version.
   
 Example:
    ./${APP_NAME}.sh --input_list "./broken_scripts.txt"
EOFU!
}

# Logs messages to STDERR and $LOG file.
# param:  Log file name. The file is expected to be a fully qualified path or the output
#         will be directed to a file in the directory the script's running directory.
# param:  Message to put in the file.
# param:  (Optional) name of a operation that called this function.
logit()
{
    local log_file="$WORK_DIR/${APP_NAME}.log"
    local message="$1"
    local time=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$time] $message" >>$log_file
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
# param:  file name with path relative to $HOME. Exmaple: foo/bar/baz.sh
patch_file()
{
    local original="$1"
    # Backup the original to a timestamped tarball
    if ! tar rvf "$TARBALL" "${original}"; then
        logit "**error: failed to back up $original skipping..."
        return $FALSE
    fi
    # copy the file to the script run time. All files done in the same pass must have the same time stamp.
    local temp="$original.bak"
    # Can fail if disk full or what ever.
    if cp "$original" "$temp"; then 
        # overwrite original with modifications.
        if sed -e 's/\/s\/sirsi/\$HOME/g' < "$temp" > "$original"; then
            # get rid of the temp file.
            rm "$temp"
            return $TRUE
        fi
    else
        logit "**error, failed to make backup copy of original script."
        return $FALSE
    fi
    return $FALSE
}

export target_script_patching_file=$FALSE

# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "help,input_list:,version" -o "hi:v" -a -- "$@")

# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters 
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"

while true
do
    case $1 in
    -h|--help) 
        usage
        ;;
    -i|--input_list)
        shift
        export target_script_patching_file="$1"
        ;;
    -v|--version) 
        echo "$APP_NAME version: $VERSION"
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done
### Actual work happens here.
# Test if the input script is readable.
if [ -r "$target_script_patching_file" ]; then
    logit "processng files found in $target_script_patching_file"
    attempts=0
    lines=0
    patched=0
    while IFS= read -r script_name; do
        lines=$((lines+1))
        if [ -r "$script_name" ]; then
            attempts=$((attempts+1))
            if patch_file "$script_name"; then
                logit "patched: $script_name"
                patched=$((patched+1))
            else
                logit "patch_file() refused to patch $script_name"
            fi
        else
            logit "*warn: file $script_name wasn't found"
        fi
    done < "$target_script_patching_file"
    logit "---"
    logit "read: $lines, analysed: $attempts, patched: $patched"
    exit 0
else
    logit "**error, the target script file was either missing, empty, or unreadable."
    usage
    exit 1
fi
