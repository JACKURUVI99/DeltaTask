#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <author_username>"
    exit 1
fi

author="$1"
author_home="/home/authors/$author"
public_dir="$author_home/public"
mod_dir="/home/mods/$(whoami)"
blacklist_file="$mod_dir/blacklist.txt"
blogs_yaml="$author_home/blogs.yaml"

if [[ ! -d "$public_dir" ]]; then
    echo "Author public directory not found: $public_dir"
    exit 1
fi

if [[ ! -f "$blacklist_file" ]]; then
    echo "Blacklist file not found at $blacklist_file"
    exit 1
fi

if [[ ! -f "$blogs_yaml" ]]; then
    echo "blogs.yaml not found at $blogs_yaml"
    exit 1
fi

shopt -s nullglob
blog_files=("$public_dir"/*)
shopt -u nullglob

if [[ ${#blog_files[@]} -eq 0 ]]; then
    echo "No blog files found in $public_dir"
    exit 1
fi

for blog_path in "${blog_files[@]}"; do
    blogname=$(basename "$blog_path")
    censored_count=0
    tmpfile=$(mktemp)

    cp "$blog_path" "$tmpfile"

    # Process each blacklisted word
    while IFS= read -r word; do
        # Skip empty lines and comments
        [[ -z "$word" || "$word" =~ ^# ]] && continue

        # Escape regex special chars in word for grep/sed
        escaped_word=$(printf '%s\n' "$word" | sed -e 's/[][\/.^$*]/\\&/g')

        # Find all occurrences with line numbers (case-insensitive, whole word, partial allowed)
        # We will print each occurrence with line number
        while IFS= read -r line; do
            # Extract line number and content from grep
            line_no=$(echo "$line" | cut -d: -f1)
            line_text=$(echo "$line" | cut -d: -f2-)

            # Find all occurrences in this line (case-insensitive)
            # Use perl regex for global matching
            # For each match, print the message and replace in tmpfile

            # Generate asterisks string of same length as word (trim spaces)
            word_trimmed=$(echo -n "$word" | xargs)
            asterisks=$(printf '%*s' "${#word_trimmed}" '' | tr ' ' '*')

            # Count how many times the word appears in this line (case-insensitive)
            count_in_line=$(echo "$line_text" | grep -oi "$escaped_word" | wc -l)

            for ((i=0; i<count_in_line; i++)); do
                echo "Found blacklisted word '$word_trimmed' in $blogname at line $line_no"
                censored_count=$((censored_count+1))
            done
        done < <(grep -in -w -i -- "$word" "$tmpfile")

        # Replace all occurrences of the word in tmpfile with asterisks (case-insensitive)
        # Use perl for safe replacement with exact length asterisks
        perl -i -pe "s/\\b\Q$word_trimmed\E\\b/\$asterisks/ig" "$tmpfile"

    done < "$blacklist_file"

    if (( censored_count > 0 )); then
        # Overwrite original blog with censored version
        mv "$tmpfile" "$blog_path"
        echo "$blogname: $censored_count blacklisted word(s) censored."

        if (( censored_count > 5 )); then
            # Remove moderator symlink to this author's public dir
            symlink="$mod_dir/$author"
            if [ -L "$symlink" ]; then
                rm "$symlink"
                echo "Symlink $symlink removed due to excessive blacklisted words."
            fi

            # Archive blog: create archive dir if not exists
            archive_dir="$author_home/archive"
            mkdir -p "$archive_dir" || { echo "Failed to create archive directory: $archive_dir"; exit 1; }

            # Move blog file to archive dir
            mv "$blog_path" "$archive_dir/" || { echo "Failed to archive blog $blogname"; exit 1; }
            echo "Blog $blogname is archived due to excessive blacklisted words."

            # Update blogs.yaml publish_status and mod_comments (no sudo, so user must have permission)
            # Using yq 4.x syntax
            yq e -i \
              '(.blogs[] | select(.file_name == "'"$blogname"'")).publish_status = false |
               (.blogs[] | select(.file_name == "'"$blogname"'")).mod_comments = "found '"$censored_count"' blacklisted words"' \
               "$blogs_yaml"
        fi

    else
        rm "$tmpfile"
        echo "$blogname: no blacklisted words found."
    fi

done
