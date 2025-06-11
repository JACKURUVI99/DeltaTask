#!/bin/bash

# blogfilter_setup.sh
# Sets up moderator directories, author symlinks, blacklist.txt file, 
# author permissions and ACLs for blog filtering without needing sudo later.

YAML_FILE="../users.yaml"
MOD_HOME_BASE="/home/mods"
AUTH_HOME_BASE="/home/authors"

# Check if yq is installed
if ! command -v yq &>/dev/null; then
    echo "Error: 'yq' is not installed. Please install it (https://github.com/mikefarah/yq)."
    exit 1
fi

echo "🔧 Starting moderator folder, symlink, and permission setup..."

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
        author_home="$AUTH_HOME_BASE/$author_username"
        author_public_dir="$author_home/public"
        symlink_path="$mod_dir/$author_username"
        author_archive_dir="$author_home/archive"
        author_blogsyaml="$author_home/blogs.yaml"

        if [ -d "$author_public_dir" ]; then
            ln -s "$author_public_dir" "$symlink_path"
            echo "    🔗 Linked author $author_username → $symlink_path"

            # Set ownership and permissions on author's home and public dir
            chown -R "$author_username:g_author" "$author_home"
            chmod 750 "$author_home"
            chmod 750 "$author_public_dir"

            # Give read and execute permissions to mods group on public dir
            setfacl -m g:g_mod:rx "$author_public_dir"

            # Create archive dir if missing, with proper group and permissions
            if [ ! -d "$author_archive_dir" ]; then
                mkdir -p "$author_archive_dir"
                echo "    📁 Created archive directory for author: $author_archive_dir"
            fi
            chown -R "$author_username:g_author" "$author_archive_dir"
            chmod 770 "$author_archive_dir"
            setfacl -m g:g_mod:rwx "$author_archive_dir"

            # Set blogs.yaml group to g_mod and give group write permission
            if [ -f "$author_blogsyaml" ]; then
                chgrp g_mod "$author_blogsyaml"
                chmod 664 "$author_blogsyaml"
                setfacl -m u:$mod_username:rw "$author_blogsyaml"
                echo "    📝 Set permissions on blogs.yaml for mod access: $author_blogsyaml"
            else
                echo "    ⚠ Warning: blogs.yaml not found for author $author_username"
            fi

            # Ensure mod user owns the symlink dir and has execute permission
            chown -R "$mod_username:g_mod" "$mod_dir"
            chmod 750 "$mod_dir"
        else
            echo "    ⚠ Warning: Public directory for $author_username not found at $author_public_dir"
        fi
    done
done

echo "✅ blogfilter_setup.sh completed successfully."
