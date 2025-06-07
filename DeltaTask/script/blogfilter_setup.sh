#!/bin/bash

# blogfilter_setup.sh
# Sets up moderator directories, author symlinks, and blacklist.txt file for blog filtering.

YAML_FILE="../users.yaml"
MOD_HOME_BASE="/home/mods"
AUTH_HOME_BASE="/home/authors"

# Check if yq is installed
if ! command -v yq &>/dev/null; then
    echo "Error: 'yq' is not installed. Please install it (https://github.com/mikefarah/yq)."
    exit 1
fi

echo "🔧 Starting moderator folder and symlink setup..."

mod_count=$(yq e '.mods | length' "$YAML_FILE")

for ((i = 0; i < mod_count; i++)); do
    mod_username=$(yq e ".mods[$i].username" "$YAML_FILE")
    mod_dir="$MOD_HOME_BASE/$mod_username"
    blacklist_file="$mod_dir/blacklist.txt"

    echo "▶ Setting up for moderator: $mod_username"

    # Create moderator directory if not exists
    if [ ! -d "$mod_dir" ]; then
        mkdir -p "$mod_dir"
        chown "$mod_username:g_mod" "$mod_dir"
        chmod 750 "$mod_dir"
        echo "  📁 Created moderator directory: $mod_dir"
    fi

    # Create blacklist.txt if not exists
    if [ ! -f "$blacklist_file" ]; then
        touch "$blacklist_file"
        chown "$mod_username:g_mod" "$blacklist_file"
        chmod 640 "$blacklist_file"
        echo "  📄 Created empty blacklist file: $blacklist_file"
    fi

    # Remove old symlinks
    find "$mod_dir" -type l -delete

    # Add symlinks to assigned authors' public dirs
    author_count=$(yq e ".mods[$i].authors | length" "$YAML_FILE")
    for ((j = 0; j < author_count; j++)); do
        author_username=$(yq e ".mods[$i].authors[$j]" "$YAML_FILE")
        author_public_dir="$AUTH_HOME_BASE/$author_username/public"
        symlink_path="$mod_dir/$author_username"

        if [ -d "$author_public_dir" ]; then
            ln -s "$author_public_dir" "$symlink_path"
            echo "    🔗 Linked author $author_username → $symlink_path"
        else
            echo "    ⚠ Warning: Public directory for $author_username not found at $author_public_dir"
        fi
    done
chmod g+rwx manageblogs.sh
sudo chgrp g_author manageblogs.sh

echo "blogfilter_setup.sh completed successfully."
