#!/bin/bash
################################################################################
#
# Run this on migration day. It will replace '/s/sirsi' with '/software/EDPL'
# and replace any references of edpl.library.ualberta.ca with 
# edpl.sirsidynix.net. It can be run repeatedly if necessary.
#
################################################################################
. ~/.bashrc
cd ~
declare -a file_types=("*.pl" "*.sh" "*.py")
declare -a locations=("Unicorn/EPLwork" "Unicorn/Bincustom" "Unicorn/Rptcustom")
echo >epl_to_saas_files.lst
for file_type in "${file_types[@]}"; do
  echo "searching for file type: "$file_type
  for location in "${locations[@]}"; do
    echo "  in location: $location... "
    find -H $location -name "$file_type" | xargs egrep -l '/s/sirsi|eplapp.library.ualberta.ca' >>epl_to_saas_files.lst
  done
done

echo "found "`wc -l epl_to_saas_files.lst`" files."


./patchsed.sh --input_list=epl_to_saas_files.lst --sed_file=all_scripts.patch.ilsdev1.edpl.sed --comment="Migration day script changes"  --dry_run
echo "=== Check results and hit 'q' to cancel. If you like what you see run this script again."
less patchsed.results
read -p "apply these changes? y/[n]" apply_changes < /dev/tty
case $apply_changes in
    [yY])
        echo "yes selected."
        ./patchsed.sh --input_list=epl_to_saas_files.lst --sed_file=all_scripts.patch.ilsdev1.edpl.sed --comment="Migration day script changes"
        ;;
    *)
        echo "no selected." >&2
        echo "You can restore the originals with patchsed.sh --restore. "
        ;;
esac
