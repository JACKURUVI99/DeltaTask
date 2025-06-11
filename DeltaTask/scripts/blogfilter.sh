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

if [[ ! -d "$public_dir" || ! -f "$blacklist_file" || ! -f "$blogs_yaml" ]]; then
    echo "Missing required files or directories."
    exit 1
fi

shopt -s nullglob
blog_files=("$public_dir"/*)
shopt -u nullglob

[[ ${#blog_files[@]} -eq 0 ]] && echo "No blog files found." && exit 1

censor_blog() {
    blog_path="$1"
    blogname=$(basename "$blog_path")
    tmpfile=$(mktemp)
    cp "$blog_path" "$tmpfile"
    count=0

    while IFS= read -r word; do
        [[ -z "$word" || "$word" =~ ^# ]] && continue
        clean_word=$(echo "$word" | xargs)
        stars=$(printf '%*s' "${#clean_word}" | tr ' ' '*')

        matches=$(grep -inw -i "$clean_word" "$tmpfile")
        while IFS= read -r line; do
            line_no="${line%%:*}"
            echo "Found '$clean_word' in $blogname at line $line_no"
            ((count++))
        done <<< "$matches"

        perl -i -pe "s/\\b\Q$clean_word\E\\b/$stars/ig" "$tmpfile"
    done < "$blacklist_file"

    if (( count > 0 )); then
        mv "$tmpfile" "$blog_path"
        echo "$blogname: $count word(s) censored."
        (( count > 5 )) && archive_blog "$blog_path" "$blogname" "$count"
    else
        rm "$tmpfile"
        echo "$blogname: no blacklisted words found."
    fi
}

archive_blog() {
    path="$1"
    name="$2"
    count="$3"
    symlink="$mod_dir/$author"
    archive_dir="$author_home/archive"

    [[ -L "$symlink" ]] && rm "$symlink" && echo "Removed symlink: $symlink"
    mkdir -p "$archive_dir" && mv "$path" "$archive_dir/"
    echo "$name archived due to $count blacklisted words."

    yq e -i \
      '(.blogs[] | select(.file_name == "'$name'")).publish_status = false |
       (.blogs[] | select(.file_name == "'$name'")).mod_comments = "found '$count' blacklisted words"' \
      "$blogs_yaml"
}

for blog in "${blog_files[@]}"; do
    censor_blog "$blog"
done
