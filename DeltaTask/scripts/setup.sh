#!/bin/bash
set -e

groups=(g_user g_author g_mod g_admin)
for grp in "${groups[@]}"; do
    getent group "$grp" > /dev/null || groupadd "$grp"
done

chown root:root /scripts
chmod 755 /scripts
find /scripts -type f -name "*.sh" -exec chmod 755 {} \;

for udir in /home/users/*; do
    [ -d "$udir" ] || continue
    uname=$(basename "$udir")
    chown -R "$uname":g_user "$udir"
    chmod -R 750 "$udir"
done

for adir in /home/authors/*; do
    [ -d "$adir" ] || continue
    aname=$(basename "$adir")
    chown -R "$aname":g_author "$adir"
    [ -d "$adir/blogs" ] && chmod -R 700 "$adir/blogs"
    [ -d "$adir/public" ] && chmod -R 755 "$adir/public"
done

for mdir in /home/mods/*; do
    [ -d "$mdir" ] || continue
    mname=$(basename "$mdir")
    chown -R "$mname":g_mod "$mdir"
    chmod -R 750 "$mdir"
done

for admdir in /home/admin/*; do
    [ -d "$admdir" ] || continue
    adminname=$(basename "$admdir")
    chown -R "$adminname":g_admin "$admdir"
    chmod -R 750 "$admdir"
done

for mdir in /home/mods/*; do
    [ -d "$mdir" ] || continue
    mname=$(basename "$mdir")
    find "$mdir" -type l | while read -r symlink; do
        target=$(readlink -f "$symlink")
        if [[ "$target" == /home/authors/*/public* ]]; then
            author_public_dir=$(dirname "$target")
            setfacl -m g:g_mod:rwx "$author_public_dir"
            setfacl -d -m g:g_mod:rwx "$author_public_dir"
        fi
        chown -h "$mname":g_mod "$symlink"
    done
done

for udir in /home/users/*/all_blogs/*; do
    if [ -L "$udir" ]; then
        userdir=$(dirname "$(dirname "$udir")")
        uname=$(basename "$userdir")
        chown -h "$uname":g_user "$udir"
        chmod 755 "$udir"
    fi
done

paths=( "/home" "/scripts" )
for p in "${paths[@]}"; do
    [ -d "$p" ] && setfacl -R -m g:g_admin:rwx "$p" && setfacl -R -d -m g:g_admin:rwx "$p"
done

bash permissions.sh
echo "Permission setup complete."
