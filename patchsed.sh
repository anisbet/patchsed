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
VERSION="4.06.07"
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
branch if you used --branch. Restore will report on what change was in the tarball if possible.

If the file is not part of a repo, the pre-modified script, the transaction log, the sed script
will be saved to a timestamped tarball for use by the --restore function. Restore will replace
any file in reverse chronological order back to the first modification. You also have the
option to exit at any stage of restore.

Notes on input files.
* This script will use the first commented line from the sed script file as a commit message.
* The input file list lists files relative to $HOME. The list is also used to tar the files
  so restore will work in a consistent manner. Use 'egrep -l "<search>"' >files.lst
* Blank lines and lines that start with '#' are ignored.

Flags:

-b, -branch, --branch [git_branch]: If any file in the input list turns out to be managed by Git,
    make a new branch named git_branch, make the changes, commit it, then return to the original
    branch. If you do not use the --branch switch git will not be used as a strategy. Changes are
    not saved to $TARBALL because of the complexity over-writing other branch changes if restore
    is required.
    Tests are made to make sure you are on 'master' to start with, and that there are no unstaged
    or uncommited changes in the directory. If there are uncommitted changes, the file name is
    output to [input_file_name].rejects. You can then tidy up the directory and re-run the patch 
    with the rejects file as input.
-c, -comment, --comment "comment string": Adds a comment string to the log file in which you might log
    what the patches were and why you are doing them. Any comment lines in the sed script will be 
    added automatically and logged unless the --test switch is used.
-d, -dry_run, --dry_run: Go through the motions but do not apply the patch. Tests are not logged nor
    tarballs created, but a dry run is made on the files and the sed script and comparison changes
    are available $APP_NAME.results file.
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
    extract it manually. The input file list is restored.
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
    [[ "$is_test" == "$FALSE" ]] && echo -e "[$time] $message" >>$LOG_FILE
    echo -e "[$time] $message" >&2
}

# Asks if user would like to do what the message says.
# param:  message string.
# return: 0 if the answer was yes and 1 otherwise.
confirm()
{
	if [ -z "$1" ]; then
		echo "** error, confirm_yes requires a message." >&2
		exit 3
	fi
	local message="$1"
	echo "$message? " >&2
	read -p "y/[n]: " answer < /dev/tty
	case $answer in
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
    # If $git_branch is not set, treat is as if it is not a git repo, and carry on.
    if [ -z "$git_branch" ]; then
        return $TRUE
    fi
    local original="$1"
    # Test if git is even available to the user.
    if ! which git >/dev/null 2>&1; then
        return $TRUE
    fi
    # We do all the operations in the git repo directory.
    local modification_target_file=$(basename "$original")
    # the file is part of a git repo. If it is, it will checkout the project as a new branch before
    # makeing changes. Make the changes, commit the files, and then change back to the previous branch.
    #1) cd into directory, so find the directory.
    local repo_dir=$(dirname "$original")
    if [ ! -d "$repo_dir" ]; then
        logit "**error, $original, in $repo_dir is not a directory. Remove it from the file list and re-run."
        cd $HOME
        return $TRUE
    fi
    ## DO NOT forget to return $HOME when applying the patch.
    cd "$repo_dir"
    #2 test if this directory is under git management. If it isn't use the tarball method and return.
    if ! git status >/dev/null 2>&1; then
        cd $HOME
        return $TRUE
    fi
    if ! git ls-files --error-unmatch "$modification_target_file" >/dev/null 2>&1; then
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
    local modification_target_file=$(basename "$original")
    # Take the message for the commit from the comment line of the sed file.
    # This only looks at the first line of the sed script, but it is good policy
    # to only have a comment on that line as different versions of sed _may_ not
    # allow comments on other lines. This will quit after finding the first comment string.
    local message=$(sed -e 's/^#//;q' <"$sed_file")
    local l_date=$(date +"%Y-%m-%d %H:%M:%S")
    # reasonable message even if sed didn't get anything useful from the script.
    message="Commit: $l_date $message by $0"
    local repo_dir=$(dirname "$original")
    ## DO NOT forget to return $HOME when applying the patch.
    cd "$repo_dir"
    #2b) test if there are any uncommited files.
    if ! git diff --exit-code >/dev/null 2>&1; then
        logit "FAIL: $log_message Rejecting because of uncommited changes in '$repo_dir'."
        echo "$original" >>"$REJECTED_FILES"
        cd "$HOME"
        return $FALSE
    fi
    #2c) and just for good measure, test if there are any uncommited cached files.
    if ! git diff --cached --exit-code >/dev/null 2>&1; then
        logit "FAIL: $log_message Rejecting because of uncommited cached changes found in '$repo_dir'."
        echo "$original" >>"$REJECTED_FILES"
        cd "$HOME"
        return $FALSE
    fi
    #3) get the current branch and save it, but if the current branch is not 'master' warn the user.
    local original_branch=$(git rev-parse --abbrev-ref HEAD)
    if [[ "original_branch" != "master" ]]; then
        echo "current branch is $original_branch not 'master'."
        if confirm "Continue patching on this branch"; then
            log_message="$log_message *warning: changes in $git_branch will need to be merged with $original_branch"
        else
            logit "FAIL: $log_message $original patch rejected by user because repo is not on branch 'master'."
            echo "$original" >>"$REJECTED_FILES"
            cd "$HOME"
            return $FALSE
        fi
    fi
    #4a) checkout the branch supplied with --git, or create a new branch.
    if ! git checkout "$git_branch" >/dev/null 2>&1; then
        # There was no branch names $git_branch, let's make one.
        if ! git checkout -b "$git_branch" >/dev/null 2>&1; then
            cd "$HOME"
            logit "FAIL: $log_message"
            logit "**error, failed to checkout '$git_branch' branch while attempting to patch $original."
            # leave us in the directory where things went south so we can inspect.
            return $FALSE
        else
            log_message="$log_message Created branch '$git_branch'."
        fi
    else
        log_message="$log_message Checked out '$git_branch'."
    fi
    #4b) test if there are any uncommited files.
    if git diff --exit-code >/dev/null 2>&1; then
        log_message="$log_message branch $git_branch has no uncommited changes."
    else
        log_message="$log_message Uncommited changes on ${git_branch}. Commit and re-run the patch on $REJECTED_FILES"
        logit "FAIL: $log_message Returned to '$original_branch'."
        echo "$original" >>"$REJECTED_FILES"
        git checkout "$original_branch" >/dev/null 2>&1
        cd "$HOME"
        return $FALSE
    fi
    #4c) and just for good measure, test if there are any uncommited cached files.
    if git diff --cached --exit-code >/dev/null 2>&1; then
        log_message="$log_message Branch $git_branch has no cached changes."
    else
        log_message="$log_message Cached changes found on ${git_branch}. Commit and re-run the patch on $REJECTED_FILES"
        logit "FAIL: $log_message Returned to '$original_branch'."
        echo "$original" >>"$REJECTED_FILES"
        git checkout "$original_branch" >/dev/null 2>&1
        cd "$HOME"
        return $FALSE
    fi
    #5) patch the files.
    # There are cases where the file to patch is not in the branch requested.
    if [ -f "$modification_target_file" ]; then
        if ! apply_patch "$HOME/$sed_file" "$modification_target_file"; then
            logit "FAIL: $log_message Expected $original, but it is not part of this branch."
            logit "**error, failed to patch $original. Exiting leaving branch as $git_branch."
            echo "$original" >>"$REJECTED_FILES"
            # Go back home but do not commit or return to original branch. Branches with unmerged
            # changes will be rejected next time too.
            # git checkout "$original_branch" >/dev/null 2>&1
            cd "$HOME"
            return $FALSE
        else
            log_message="$log_message Applied patch successfully."
        fi
        #6) commit the changes to this branch.
        git commit -a -m"$message" >/dev/null 2>&1
        log_message="$log_message Committed '$git_branch'."
    else
        log_message="$modification_target_file not found perhaps it does not exist on this branch."
        logit "FAIL: $log_message Returned to '$original_branch'."
        echo "$original" >>"$REJECTED_FILES"
        git checkout "$original_branch" >/dev/null 2>&1
        cd "$HOME"
        return $FALSE
    fi
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
    logit "===  $APP_NAME: $VERSION"
    logit "===  restore requested."
    for tarball in $(ls -tc1 ${APP_NAME}.*.tar); do
        if [ -f "$tarball" ]; then
            local sed_file=$(egrep "BACKUP:" $LOG_FILE 2>/dev/null | egrep "$tarball" | cut -d, -f2 | sed '/^$/d;s/ //g')
            local message_string=$(egrep -e "^#" "$sed_file" 2>/dev/null)
            [ -z "$message_string" ] || echo -e "== extracting $tarball undoes:\n$message_string"
            if confirm "restore files from '$tarball'"; then
                # Extract all the files except the log file since
                # that would wipe the on-going history of events.
                if tar xvf "$tarball" --exclude="${APP_NAME}.log" --exclude="*.sed" 2>&1 >>"$LOG_FILE"; then
                    logit "restored files from '$tarball'"
                    last_tarball="$tarball"
                else
                    logit "**error, failed to restore files from $tarball."
                    continue
                fi
            else
                logit "$tarball not restored."
                continue
            fi
        else
            logit "*warn, expected $tarball to be a regular file. Skipping."
        fi
        [[ -z "$last_tarball" ]] || logit "restore complete"
    done
    return $TRUE
}

export target_script_patching_file=$FALSE
export sed_script_file=$FALSE
export git_branch=""
export comment_string=""
export is_test="$FALSE"

# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "branch:,comment:,dry_run,help,input_list:,restore,sed_file:,version" -o "b:c:dhi:rs:v" -a -- "$@")
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
    -c|--comment)
        shift
        export comment_string="$1"
        ;;
    -d|--dry_run)
        export is_test="$TRUE"
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
REJECTED_FILES="$HOME/$target_script_patching_file.rejects"
# Start with a fresh list for rejects so we do not re-patch files that were rejected, but later succeed.
[ -f "$REJECTED_FILES" ] && rm "$REJECTED_FILES"
### Actual work happens here.
# Test if the input script is readable.
if [ -r "$target_script_patching_file" ]; then
    logit "===  $APP_NAME: $VERSION"
    logit "===  input file list: $target_script_patching_file"
    logit "===       sed script: $sed_script_file"
    attempts=0
    lines=0
    patched=0
    unpatched_files=""
    test_file=".$APP_NAME.tst"
    test_results="$APP_NAME.results"
    # Empty the test results file.
    echo >"$test_results"
    # Clean the input file list of blank lines and commented scripts.
    clean_file_list="/tmp/.patch.clean.$$"
    egrep -ve '^#|^$' "$target_script_patching_file" >"$clean_file_list"
    if [ -r "$sed_script_file" ]; then
        sed_comment=$(egrep -e "^#" "$sed_script_file")
        export comment_string="$comment_string\n  sed comments: $sed_comment"
        logit "===          comment: $comment_string"
    else
        logit "**error, sed script file was not found, was empty, or could not be read."
        exit 1
    fi
    
    if [ -z "$git_branch" ]; then
        logit "=== branch (if repo): git not selected"
    else
        if [[ "$is_test" == "$TRUE" ]]; then
            logit "= Checking repo status start"
            while IFS= read -r target_patch_file; do 
                my_dir=$(dirname $target_patch_file)
                if [ ! -d "$my_dir" ]; then continue; fi
                cd "$my_dir"
                my_branch=$(git rev-parse --abbrev-ref HEAD)
                my_repo_cache_is_clean="okay"
                if git diff --cached --exit-code >/dev/null 2>&1; then my_repo_cache_is_clean="REJECT"; fi
                my_repo_commit_is_clean="okay"
                if git diff --exit-code >/dev/null 2>&1; then my_repo_commit_is_clean="REJECT"; fi
                my_repo_status="branch:'$my_branch' commits:$my_repo_commit_is_clean cache:$my_repo_cache_is_clean path:$my_dir"
                logit "$my_repo_status"
                cd $HOME
            done < "$clean_file_list"
            logit "= Checking repo status end"
        else # Make changes in the repo
            echo -e "*** warning ***\nAre you sure you want to make changes on branch '$git_branch'?" >&2
            if confirm "continue anyway"; then
                logit "=== branch (if repo): $git_branch"
            else
                logit "No changes. Exiting."
                exit 0
            fi
        fi
    fi
    
    # Patch or test patch files.
    while IFS= read -r target_patch_file; do
        lines=$((lines+1))
        if [ -r "$target_patch_file" ]; then
            attempts=$((attempts+1))
            if [[ "$is_test" == "$TRUE" ]]; then
                logit "TEST: apply patch in '$sed_script_file' to '$target_patch_file'."
                if sed -f "$sed_script_file" "$target_patch_file" >"$test_file"; then
                    echo "== $target_patch_file" >>"$test_results"
                    diff "$target_patch_file" "$test_file" >>"$test_results"
                else
                    logit "**error in sed file"
                    rm "$test_file" "$test_results" "$clean_file_list"
                    exit 1
                fi
                continue
            fi
            if patch_file "$sed_script_file" "$target_patch_file"; then
                patched=$((patched+1))
            else
                unpatched_files="$unpatched_files\n$target_patch_file"
            fi
        else
            logit "*warn: skipping $target_patch_file because it could not be found, was empty, or could not be read."
            unpatched_files="$unpatched_files\n$target_patch_file"
        fi
    done < "$clean_file_list"
    rm "$clean_file_list" >/dev/null 2>&1
    logit "---"
    logit "read: $lines, analysed: $attempts, patched: $patched"
    [ -z "$unpatched_files" ] || logit "The following files had errors:$unpatched_files"
    if [[ "$is_test" == "$TRUE" ]]; then
        logit "TEST: no tarball created."
        logit "Check $test_results for proposed changes."
        rm "$test_file" >/dev/null 2>&1
    else
        logit "BACKUP:$TARBALL, $sed_script_file, $target_script_patching_file"
        tar rvf "$TARBALL" "${APP_NAME}.log" "$target_script_patching_file" "$sed_script_file" >/dev/null
    fi
    exit 0
else
    logit "**error, the target script file was either missing, empty, or unreadable."
    usage
    exit 1
fi
