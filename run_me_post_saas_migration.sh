#!/bin/bash

# This script is meant to be run after the migration to saas has completed.
# It will modify all the scripts originally identified as requiring changes 
# as documented in the Script Conversion Plan document.
#
# The script will check of the identified repos are clean. You will be asked to 
# confirm you are okay with the test results.
# 
# If you select 'y' the script will call patchsed again, this time modifying 
# all the files and commiting them to the master branch.
# Backs of the files prior to modification can be found in /home/ilsdev/patchsed.20210212_172425.tar.
# all_scripts.patch.ilsdev1.edpl.sed, s.sirsi.eplapp.convert.ilsdev1.dedup.lst

cd ~
if [ -f ~/.ran_migration_update ]; then
    echo "The post migration changes made by $0 have already been done. Ask Andrew for assistance."
    exit 1
fi
echo "Testing post migration code fixes. patchsed.sh will run through a test and report if the"
echo "repos are clean. Review the changes making sure all the repos are on master branch and "
echo "there are no outstanding commits. You will then be asked to confirm the actual patches."
echo "If you select yes to commit the changes you will not be able to run this script again."
read -p "shall we start? y/[n]" test_changes < /dev/tty
case $test_changes in
    [yY])
        ./patchsed.sh --input_list=s.sirsi.eplapp.convert.ilsdev1.dedup.lst --sed_file=all_scripts.patch.ilsdev1.edpl.sed --comment="Migration day script changes"  --branch=master --dry_run 
        echo "=== Check results and hit 'q' to cancel. If you select 'y' DO NOT RE-RUN this script."
        less patchsed.results
        ;;
    *)
        echo "no selected." >&2
        echo "you can always run the test again. "
        exit 1
        ;;
esac

read -p "apply these changes? y/[n]" apply_changes < /dev/tty
case $apply_changes in
    [yY])
        echo "yes selected."
        ./patchsed.sh --input_list=s.sirsi.eplapp.convert.ilsdev1.dedup.lst --sed_file=all_scripts.patch.ilsdev1.edpl.sed --comment="Migration day script changes"  --branch=master
        touch ~/.ran_migration_update
        ;;
    *)
        echo "no selected." >&2
        echo "Backups of the originals can be found in /home/ilsdev/patchsed.20210212_172425.tar. "
        ;;
esac
