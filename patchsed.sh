#!/bin/bash
###########################################################################
#
# Uses sed scripts to make edits on regular files and files in git repos.
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
VERSION=4.01.01
APP_NAME="patchsed"
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
 
Modifies scripts en masse using sed scripts. The motivation is to automate many similar changes on large numbers of files.
The modifications are made by arbitrary sed scripts specified on the command line with the -s switch.

Scripts are first tested for membership in a Git repo. If the file tests to belong to a Git repo, 
the script started with –branch=’SAAS’ and the current branch is, say ‘FixBug’, the script checks 
out the master branch, creates or checks out a SAAS branch, makes modifications with sed, commits 
the changes with a message from the first comment line in the sed script, then changes back to 
‘FixBug’ branch. If an error occurs the script will exit without changing branches.

The restore feature has no effect on files monitored by Git as the changes are isolated in their 
own branch, but to make the changes permanent the branch will need to be merged with the master 
branch. This is left as an exercise to the reader since version numbers may need to be updated, 
and some projects have complicated histories. Just be sure to merge the ‘SAAS’ branch before 
pushing to production.  

If the file is not part of a repo, the pre-modified script, the transaction log, the sed script 
will be saved to a timestamped tarball for use by the --restore function. Restore will replace 
any file in reverse chronological order back to the first modification. You also have the 
option to exit at any stage of restore.

Notes on input files.
* This script will use the first commented line from the sed script file as a commit message.
* The input file list lists files relative to $HOME. The list is also used to tar the files
  so restore will work in a consistent manner. Use 'egrep -l "<search>"' >files.lst 

Flags: 

-b, -branch, --branch [git_branch]: If any file in the input list turns out to be managed by Git, 
    make a new branch named git_branch, make the changes, commit it, then return to the original
    branch. If you do not use the --branch switch changes file changes are made to the master branch.  
-h, -help, --help: This help message. 
-i, -input_list, --input_list [file]: Required. Specifies the list scripts to target for patching. 
    File names should include the relative path to the $HOME directory. For example, if you want the file 
    $HOME/foo/bar.sh to be patched, add foo/bar.sh as a line to the input list file. All files in this 
    list will be modified in the same way. See -s for more information. 
-r, -restore, --restore: Rolls back script changes to any checkpoint.  
    Restores all the files in all the patch.*.tar files in reverse chronological order. 
    You will be asked to confirm each tarball restore. The log file is unaffected by restores. 
    If there are no patchsaas.*.tar files to restore from, ls will emit an error that  
    it could not find a file called 'patchsaas.*.tar'.
    Files that end in .sed are excluded from restore since the restore is often because of a mistake
    in the sed file itself. If you do want the sed script restored, take note of the tarball and 
    extract it manually.
-s, -sed_file, --sed_file [file]: Required. File that contaiins the sed commands used to modify scripts. 
    The sed commands should be thoroughly tested before modifying scripts as complex sed commands  
    are notoriously tricky. 
-v, -version, --version: Print script version and exits. 

 Example:
    ./${APP_NAME}.sh --input_list ./scripts_to_change.txt -s sed_commands.sed
    
    
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

# Actually applies the sed patch file.
# param:  name of the sed file script to run.
# param:  file name with path relative to $HOME. Exmaple: foo/bar/baz.sh
apply_patch()
{
    local sed_file="$1"
    local original="$2"
    local temp="$original.bak"
    # Can fail if disk full or what ever.
    if cp "$original" "$temp"; then
        # we don't use sed's -i so if it fails we can compare the original to the copy.
        if sed -f "$sed_file" < "$temp" > "$original"; then
            rm "$temp"
            return $TRUE
        else
            logit "**error, sed error!"
        fi
    else
        logit "**error, failed to create copy of '$original' before patching! Is this partition full?"
        exit 1
    fi
    return $FALSE
}

# Use the tarball strategy. Tarball original for rollback, then patch the file.
# param:  name of the sed file script to run.
# param:  file name with path relative to $HOME. Exmaple: foo/bar/baz.sh
use_non_git_strategy()
{
    local sed_file="$1"
    local original="$2"
    # Backup the original to a timestamped tarball
    if ! tar rvf "$TARBALL" "${original}"; then
        logit "**error: failed to back up $original skipping..."
        return $FALSE
    fi
    # Apply the patch.
    if apply_patch "$sed_file" "$original"; then
        return $TRUE
    fi
    return $FALSE
}

# Tests if a file is managed by Git and returns $TRUE if it is and $FALSE otherwise, but the
# script exits if the file's directory does not exist.
# param:  Qualified path (relative to $HOME) of the file that is the target of the modifications.
is_not_repo_managed()
{
    local original="$1"
    # Test if git is even available to the user.
    if ! which git >/dev/null 2>&1; then
        return $TRUE
    fi
    # We do all the operations in the git repo directory.
    local script_file_name=$(basename "$original")
    # test if git is available, and if so test if 
    # the file is part of a git repo. If it is, it will checkout the project as a new branch before 
    # makeing changes. Make the changes, commit the files, and then change back to the previous branch.
    #1 cd into directory, so find the directory.
    local git_dir=$(dirname "$original")
    if [ ! -d "$git_dir" ]; then
        logit "**error, $original, in $git_dir is not a directory. Remove it from the file list and re-run."
        exit 1
    fi
    ## DO NOT forget to return $HOME when applying the patch.
    cd "$git_dir"
    #2 test if this directory is under git management. If it isn't use the tarball method and return.
    if ! git status >/dev/null 2>&1; then
        cd $HOME
        return $TRUE
    fi
    if ! git ls-files --error-unmatch "$script_file_name" >/dev/null 2>&1; then
        cd $HOME
        return $TRUE    
    fi
    cd $HOME
    return $FALSE
}

# Patches a file using sed file, and logs the results.
#
# param:  name of the sed file script to run.
# param:  file name with path relative to $HOME. Exmaple: foo/bar/baz.sh
patch_file()
{
    local sed_file="$1"
    local original="$2"
    local log_message=""
    if is_not_repo_managed "$original"; then
        log_message="$original does not use git, using $TARBALL for backup strategy."
        if use_non_git_strategy "$1" "$2"; then
            logit "SUCCESS: $log_message"
            return $TRUE
        else
            logit "FAIL: $log_message"
            return $FALSE
        fi
    fi
    log_message="$original using git strategy."
    # We do all the operations in the git repo directory.
    local script_file_name=$(basename "$original")
    # Take the message for the commit from the comment line of the sed file. 
    # This only looks at the first line of the sed script, but it is good policy
    # to only have a comment on that line as different versions of sed _may_ not
    # allow comments on other lines. This will quit after finding the first comment string.
    local message=$(sed -e 's/^#//;q' <"$sed_file")
    local l_date=$(date +"%Y-%m-%d %H:%M:%S")
    # reasonable message even if sed didn't get anything useful from the script.
    message="Commit: $l_date $message by $0"
    local git_dir=$(dirname "$original")
    ## DO NOT forget to return $HOME when applying the patch.
    cd "$git_dir"
    #3) get the current branch and save it.
    local original_branch=$(git rev-parse --abbrev-ref HEAD) 
    #4) checkout the branch supplied with --git, or create a new branch.
    if ! git checkout "$git_branch" >/dev/null 2>&1; then
        # There was no branch names $git_branch, let's make one.
        if ! git checkout -b "$git_branch" >/dev/null 2>&1; then
            cd "$HOME"
            logit "FAIL: $log_message"
            logit "**error, failed to checkout '$git_branch' branch while attempting to patch $original."
            # leave us in the directory where things went south so we can inspect.
            exit 1
        else
            log_message="$log_message Created branch '$git_branch'."
        fi
    else
        log_message="$log_message Checked out '$git_branch'."
    fi
    #5) patch the files.
    if ! apply_patch "$HOME/$sed_file" "$script_file_name"; then
        logit "FAIL: $log_message"
        logit "**error, failed to patch $original. Exiting leaving branch as $git_branch."
        exit 1
    else
        log_message="$log_message Applied patch in '$sed_file' successfully."
    fi
    #6) commit the changes to this branch.
    git commit -a -m"$message" >/dev/null 2>&1
    log_message="$log_message committed '$git_branch'."
    #7) change back to $original_branch.
    git checkout "$original_branch" >/dev/null 2>&1
    log_message="SUCCESS: $log_message Returned to '$original_branch'."
    logit "$log_message"
    cd "$HOME" 
    return $TRUE
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
            if confirm "restore files from '$tarball'"; then
                # Extract all the files except the log file since 
                # that would wipe the on-going history of events.
                if tar xvf "$tarball" --exclude="${APP_NAME}.log" --exclude="*.sed" 2>&1 >>"$LOG_FILE"; then
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
export git_branch="master"

# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "branch:,help,input_list:,restore,sed_file:,version" -o "b:hi:rs:v" -a -- "$@")
if [ $? != 0 ] ; then echo "Failed to parse options...exiting." >&2 ; exit 1 ; fi
# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters 
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"

while true
do
    case $1 in
    -b|--branch)
        shift
        export git_branch="$1"
        ;;
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
# Sed file, input file names, and git branch name are all required.
: ${sed_script_file:?Missing -s,--sed_file} ${target_script_patching_file:?Missing -i,--input_list}
### Actual work happens here.
# Test if the input script is readable.
if [ -r "$target_script_patching_file" ]; then
    logit "===  $APP_NAME: $VERSION"
    logit "===  input file list: $target_script_patching_file"
    logit "===       sed script: $sed_script_file"
    logit "=== branch (if repo): $git_branch"
    attempts=0
    lines=0
    patched=0
    while IFS= read -r script_name; do
        lines=$((lines+1))
        if [ -r "$script_name" ]; then
            if [ -r "$sed_script_file" ]; then
                attempts=$((attempts+1))
                if patch_file "$sed_script_file" "$script_name"; then
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
    tar rvf "$TARBALL" "${APP_NAME}.log" "$target_script_patching_file" "$sed_script_file" >/dev/null
    exit 0
else
    logit "**error, the target script file was either missing, empty, or unreadable."
    usage
    exit 1
fi
