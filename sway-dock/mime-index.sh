#!/bin/sh
# Prints what the dock needs to match dragged files against apps, one record per line:
#   A <tab> <desktop file path relative to applications/> <tab> <MimeType= value>
#   S <tab> <mime type> <tab> <parent type>      (shared-mime-info subclasses)
#   L <tab> <alias> <tab> <canonical type>       (shared-mime-info aliases)
# Directories are listed in XDG priority order, so the first record for a desktop ID wins.

data_home=${XDG_DATA_HOME:-$HOME/.local/share}
data_dirs=${XDG_DATA_DIRS:-/usr/local/share:/usr/share}
tab=$(printf '\t')

IFS=:
for dir in $data_home $data_dirs; do
    if [ -d "$dir/applications" ]; then
        grep -r -m1 --include='*.desktop' '^MimeType=' "$dir/applications" |
            while IFS= read -r line; do
                path=${line%%:MimeType=*}
                printf 'A\t%s\t%s\n' "${path#"$dir/applications/"}" "${line#*:MimeType=}"
            done
    fi
    [ -f "$dir/mime/subclasses" ] && sed "s/ /$tab/; s/^/S$tab/" "$dir/mime/subclasses"
    [ -f "$dir/mime/aliases" ] && sed "s/ /$tab/; s/^/L$tab/" "$dir/mime/aliases"
done
exit 0
