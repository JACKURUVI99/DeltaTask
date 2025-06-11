#!/bin/bash

# userFY.sh
# Generate FYI.yaml with 3 blog suggestions per user based on their preferences
# Only admins are allowed to run this script

set -e

# Paths
ROOT="/home/harishannavisamy/new_Deltask"
USER_PREF_FILE="$ROOT/userpref.yaml"
USERS_FILE="$ROOT/users.yaml"

# Check admin privileges
current_user=$(whoami)
is_admin=$(yq e '.admins[].username' "$USERS_FILE" | grep -w "$current_user" || true)

if [ -z "$is_admin" ]; then
    echo "Error: Only admins can run this script."
    exit 1
fi

declare -A BLOG_ASSIGN_COUNT
declare -A USER_BLOGS
declare -A BLOG_DATA

# Step 1: Load blog data from all authors
for author_dir in /home/authors/*; do
    [ -d "$author_dir" ] || continue
    author=$(basename "$author_dir")
    blogs_yaml="$author_dir/blogs.yaml"

    if [ ! -f "$blogs_yaml" ]; then
        continue
    fi

    count=$(yq e '.blogs | length' "$blogs_yaml")
    for ((i=0; i<count; i++)); do
        title=$(yq e ".blogs[$i].title" "$blogs_yaml")

        # Skip if title is null or empty
        if [[ -z "$title" || "$title" == "null" ]]; then
            continue
        fi

        categories=$(yq e ".blogs[$i].categories[]" "$blogs_yaml" | tr '\n' ',' | sed 's/,$//')
        path="$author_dir/public/$title"

        # Check if the actual blog file exists
        if [ ! -f "$path" ]; then
            continue
        fi

        key="${author}::${title}"
        BLOG_DATA["$key"]="$categories|$path"
        BLOG_ASSIGN_COUNT["$key"]=0
    done
done

# Step 2: Iterate through each user and assign blogs
user_count=$(yq e '.users | length' "$USERS_FILE")
for ((u=0; u<user_count; u++)); do
    username=$(yq e ".users[$u].username" "$USERS_FILE")
    pref1=$(yq e ".userprefs[] | select(.username == \"$username\") | .pref1" "$USER_PREF_FILE")
    pref2=$(yq e ".userprefs[] | select(.username == \"$username\") | .pref2" "$USER_PREF_FILE")
    pref3=$(yq e ".userprefs[] | select(.username == \"$username\") | .pref3" "$USER_PREF_FILE")

    selected=()
    selected_keys=()

    # Preference Matching - Strong match (pref1 & pref2)
    for key in "${!BLOG_DATA[@]}"; do
        IFS='|' read -r cats path <<< "${BLOG_DATA[$key]}"
        if [[ "$cats" == *"$pref1"* && "$cats" == *"$pref2"* ]]; then
            if [[ ! " ${selected_keys[*]} " =~ " $key " ]]; then
                selected+=("$path")
                selected_keys+=("$key")
                BLOG_ASSIGN_COUNT["$key"]=$((BLOG_ASSIGN_COUNT["$key"] + 1))
            fi
        fi
        [ "${#selected[@]}" -ge 3 ] && break
    done

    # Relax match to include pref3
    if [ "${#selected[@]}" -lt 3 ]; then
        for key in "${!BLOG_DATA[@]}"; do
            IFS='|' read -r cats path <<< "${BLOG_DATA[$key]}"
            if [[ "$cats" == *"$pref1"* || "$cats" == *"$pref2"* || "$cats" == *"$pref3"* ]]; then
                if [[ ! " ${selected_keys[*]} " =~ " $key " ]]; then
                    selected+=("$path")
                    selected_keys+=("$key")
                    BLOG_ASSIGN_COUNT["$key"]=$((BLOG_ASSIGN_COUNT["$key"] + 1))
                fi
            fi
            [ "${#selected[@]}" -ge 3 ] && break
        done
    fi

    # Fallback: least assigned blogs
    if [ "${#selected[@]}" -lt 3 ]; then
        for key in $(printf "%s\n" "${!BLOG_ASSIGN_COUNT[@]}" | sort -t: -k2 -n); do
            if [[ ! " ${selected_keys[*]} " =~ " $key " ]]; then
                IFS='|' read -r cats path <<< "${BLOG_DATA[$key]}"
                selected+=("$path")
                selected_keys+=("$key")
                BLOG_ASSIGN_COUNT["$key"]=$((BLOG_ASSIGN_COUNT["$key"] + 1))
            fi
            [ "${#selected[@]}" -ge 3 ] && break
        done
    fi

    # Write to FYI.yaml
    fyi_path="/home/users/$username/FYI.yaml"
    echo "username: $username" > "$fyi_path"
    echo "blogs:" >> "$fyi_path"
    for blog_path in "${selected[@]}"; do
        echo "  - $blog_path" >> "$fyi_path"
    done

    echo "✅ FYI list generated for $username."
done

echo -e "\n🎉 FYI assignment completed successfully."
