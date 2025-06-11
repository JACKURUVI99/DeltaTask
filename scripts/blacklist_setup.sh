#!/bin/bash

# Ensure the script is run by root to set up permissions
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# Setup mods directory and ensure all moderators have proper access
MODS_DIR="/home/mods"
USERS_YAML="/home/harishannavisamy/new_Deltask/users.yaml"

# Check if yq is installed
if ! command -v yq &>/dev/null; then
    echo "yq is not installed. Please install it first." >&2
    exit 1
fi

# Read moderator usernames from users.yaml
moderators=$(yq '.mods[].username' "$USERS_YAML")

for mod in $moderators; do
    mod_home="$MODS_DIR/$mod"
    blacklist_file="$mod_home/blacklist.txt"

    # Create mod home if missing
    mkdir -p "$mod_home"
    chown "$mod:$mod" "$mod_home"
    chmod 750 "$mod_home"

    # Create blacklist file if missing
    if [[ ! -f "$blacklist_file" ]]; then
        touch "$blacklist_file"
        echo "# Add your blacklist words below" > "$blacklist_file"
        chown "$mod:$mod" "$blacklist_file"
        chmod 660 "$blacklist_file"
    fi
done

# Allow moderators to write censored content back to author's blogs
AUTHORS_DIR="/home/authors"
for author in "$AUTHORS_DIR"/*; do
    [[ -d "$author/blogs" ]] || continue
    setfacl -Rm g:g_mod:rwx "$author/blogs"
    setfacl -Rm g:g_mod:rwx "$author/public"
done

echo "Blacklist setup completed. Moderators can now run blogfilter.sh without sudo."
