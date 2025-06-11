#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

YAML_FILE="../users.yaml"
MOD_HOME_BASE="/home/mods"
AUTH_HOME_BASE="/home/authors"
MANAGE_SCRIPT="/scripts/manageblogs.sh"

setfacl -m g:g_author:rwx "$MANAGE_SCRIPT"

mod_count=$(yq e '.mods | length' "$YAML_FILE")

for ((i = 0; i < mod_count; i++)); do
    mod_username=$(yq e ".mods[$i].username" "$YAML_FILE")
    mod_dir="$MOD_HOME_BASE/$mod_username"
    blacklist_file="$mod_dir/blacklist.txt"

    mkdir -p "$mod_dir"
    chown "$mod_username:g_mod" "$mod_dir"
    chmod 750 "$mod_dir"

    if [[ ! -f "$blacklist_file" ]]; then
        echo "# Add your blacklist words below" > "$blacklist_file"
        chown "$mod_username:g_mod" "$blacklist_file"
        chmod 640 "$blacklist_file"
    fi

    find "$mod_dir" -type l -delete

    author_count=$(yq e ".mods[$i].authors | length" "$YAML_FILE")
    for ((j = 0; j < author_count; j++)); do
        author_username=$(yq e ".mods[$i].authors[$j]" "$YAML_FILE")
        author_home="$AUTH_HOME_BASE/$author_username"
        author_public="$author_home/public"
        author_archive="$author_home/archive"
        blogs_yaml="$author_home/blogs.yaml"
        symlink_path="$mod_dir/$author_username"

        if [[ ! -d "$author_public" ]]; then
            continue
        fi

        ln -s "$author_public" "$symlink_path"

        chown -R "$author_username:g_author" "$author_home"
        chmod 750 "$author_home" "$author_public"
        setfacl -m g:g_mod:rx "$author_public"

        mkdir -p "$author_archive"
        chown -R "$author_username:g_author" "$author_archive"
        chmod 770 "$author_archive"
        setfacl -m g:g_mod:rwx "$author_archive"

        if [[ -f "$blogs_yaml" ]]; then
            chgrp g_mod "$blogs_yaml"
            chmod 664 "$blogs_yaml"
            setfacl -m u:"$mod_username":rw "$blogs_yaml"
        fi
    done
done

echo "blogfilter_setup.sh completed."
