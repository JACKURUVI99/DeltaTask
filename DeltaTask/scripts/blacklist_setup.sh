#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

YQ_BIN=$(command -v yq || true)
if [[ -z "$YQ_BIN" ]]; then
    echo "Error: yq is not installed." >&2
    exit 1
fi

MODS_DIR="/home/mods"
AUTHORS_DIR="/home/authors"
USERS_YAML="/home/harishannavisamy/new_Deltask/users.yaml"

# Read moderator usernames
moderators=$("$YQ_BIN" '.mods[].username' "$USERS_YAML")

for mod in $moderators; do
    mod_home="$MODS_DIR/$mod"
    blacklist="$mod_home/blacklist.txt"

    mkdir -p "$mod_home"
    chown "$mod:$mod" "$mod_home"
    chmod 750 "$mod_home"

    if [[ ! -f "$blacklist" ]]; then
        echo "# Add your blacklist words below" > "$blacklist"
        chown "$mod:$mod" "$blacklist"
        chmod 660 "$blacklist"
    fi
done

# Give g_mod group write access to author blogs
for author_dir in "$AUTHORS_DIR"/*; do
    [[ -d "$author_dir/blogs" ]] || continue
    setfacl -Rm g:g_mod:rwx "$author_dir/blogs"
    setfacl -Rm g:g_mod:rwx "$author_dir/public"
done

echo "Blacklist setup complete. Moderators can now run blogfilter.sh without sudo."
