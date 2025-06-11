#!/bin/bash
# permission_setup.sh
# Set ownership and permissions for DeltaTask project located at /scripts

set -e

echo "Starting permission setup for /scripts DeltaTask project..."

# Ensure groups exist
groups=(g_user g_author g_mod g_admin)
for grp in "${groups[@]}"; do
    if ! getent group "$grp" > /dev/null; then
        echo "Creating group $grp"
        groupadd "$grp"
    else
        echo "Group $grp already exists"
    fi
done
#this
# 1) Set ownership and permissions on /scripts and its files
echo "Setting /scripts ownership to root:root and permissions 755"
chown root:root /scripts
chmod 755 /scripts

echo "Setting all scripts (*.sh) and folders inside /scripts to executable 755"
find /scripts -type f -name "*.sh" -exec chmod 755 {} \;

# 2) Set ownership and permissions on your project home dirs

# Users home dirs: /home/users/*
echo "Setting ownership and permissions for /home/users/*"
for udir in /home/users/*; do
    [ -d "$udir" ] || continue
    uname=$(basename "$udir")
    echo "User home: $udir owned by $uname:g_user with 750"
    chown -R "$uname":g_user "$udir"
    chmod -R 750 "$udir"
done

# Authors home dirs: /home/authors/*
echo "Setting ownership and permissions for /home/authors/* and subdirs"
for adir in /home/authors/*; do
    [ -d "$adir" ] || continue
    aname=$(basename "$adir")
    echo "Author home: $adir owned by $aname:g_author"
    chown -R "$aname":g_author "$adir"

    # blogs - private to author
    if [ -d "$adir/blogs" ]; then
        chmod -R 700 "$adir/blogs"
    fi

    # public - readable/executable by all, writable by author and mods
    if [ -d "$adir/public" ]; then
        chmod -R 755 "$adir/public"
    fi
done

# Mods home dirs: /home/mods/*
echo "Setting ownership and permissions for /home/mods/*"
formdir=/home/mods
for mdir in "$formdir"/*; do
    [ -d "$mdir" ] || continue
    mname=$(basename "$mdir")
    echo "Moderator home: $mdir owned by $mname:g_mod"
    chown -R "$mname":g_mod "$mdir"
    chmod -R 750 "$mdir"
done

# Admins home dirs: /home/admin/*
echo "Setting ownership and permissions for /home/admin/*"
for admdir in /home/admin/*; do
    [ -d "$admdir" ] || continue
    adminname=$(basename "$admdir")
    echo "Admin home: $admdir owned by $adminname:g_admin"
    chown -R "$adminname":g_admin "$admdir"
    chmod -R 750 "$admdir"
done

# 3) Fix symlink ownership and permissions for moderators to authors' public dirs
echo "Fixing symlink ownerships and ACL for mods -> authors' public dirs"
for mdir in /home/mods/*; do
    [ -d "$mdir" ] || continue
    mname=$(basename "$mdir")

    find "$mdir" -type l | while read -r symlink; do
        # symlink target path
        target=$(readlink -f "$symlink")
        if [[ "$target" == /home/authors/*/public* ]]; then
            author_public_dir=$(dirname "$target")
            echo "Setting ACL for mod group on $author_public_dir for mod $mname"
            # Give mod group read/write/execute on author public dir
            setfacl -m g:g_mod:rwx "$author_public_dir"
            setfacl -d -m g:g_mod:rwx "$author_public_dir"
        fi
        # Change symlink ownership to mod user and group
        chown -h "$mname":g_mod "$symlink"
    done
done

# 4) Fix symlink permissions for users all_blogs dir (read-only)
echo "Fixing symlink ownerships in users' all_blogs directories (read-only)"
for udir in /home/users/*/all_blogs/*; do
    if [ -L "$udir" ]; then
        userdir=$(dirname "$(dirname "$udir")")
        uname=$(basename "$userdir")
        chown -h "$uname":g_user "$udir"
        chmod 755 "$udir"
    fi
done

# 5) Give admins full access to /home and /scripts recursively using ACL
echo "Setting full recursive ACL permissions for g_admin group on /home and /scripts"

paths=( "/home" "/scripts" )

for p in "${paths[@]}"; do
    if [ -d "$p" ]; then
        echo "Setting ACL for $p"
        setfacl -R -m g:g_admin:rwx "$p"
        setfacl -R -d -m g:g_admin:rwx "$p"
    fi
done

echo "Permission setup complete."
