#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

# --- Check yq ---
if ! command -v yq &> /dev/null; then
    echo "Error: yq is required but not installed."
    exit 1
fi

# --- Constants ---
USERS_YAML_FILE="/scripts/users.yaml"
DEFAULT_PASSWORD="123"

GROUPS=(g_user g_author g_mod g_admin)
CATEGORIES=(users authors mods admins)

# --- Create groups if missing ---
for group in "${GROUPS[@]}"; do
    getent group "$group" > /dev/null || groupadd "$group"
done

# --- Ensure root is part of g_admin ---
if [ "$(id -u)" = "0" ] && ! groups root | grep -q '\\bg_admin\\b'; then
    usermod -aG g_admin root
fi

# --- Helper functions ---
get_group() {
    case "$1" in
        users) echo "g_user" ;;
        authors) echo "g_author" ;;
        mods) echo "g_mod" ;;
        admins) echo "g_admin" ;;
    esac
}

get_basedir() {
    echo "/home/$1"
}

get_usernames() {
    yq e ".${1}[] | .username" "$USERS_YAML_FILE" 2>/dev/null || echo ""
}

get_fullname() {
    yq e ".${1}[] | select(.username==\"$2\") | .name" "$USERS_YAML_FILE"
}

create_or_unlock_users() {
    local category=$1 group=$(get_group "$category")
    for username in $(get_usernames "$category"); do
        [[ "$username" =~ ^(root|harishannavisamy)$ ]] && continue

        local fullname=$(get_fullname "$category" "$username")
        local homedir="$(get_basedir "$category")/$username"

        if id "$username" &> /dev/null; then
            usermod -e -1 "$username" || true
        else
            useradd -m -d "$homedir" -c "$fullname" -G "$group" "$username"
            echo -e "$DEFAULT_PASSWORD\n$DEFAULT_PASSWORD" | passwd "$username" > /dev/null 2>&1
        fi
    done
}

setup_home_dirs() {
    local category=$1
    for username in $(get_usernames "$category"); do
        [[ "$username" =~ ^(root|harishannavisamy)$ ]] && continue

        local homedir="$(get_basedir "$category")/$username"
        mkdir -p "$homedir"
        chown "$username:$username" "$homedir"

        [[ "$category" == "mods" ]] && chmod 750 "$homedir" || chmod 700 "$homedir"

        if [[ "$category" == "authors" ]]; then
            mkdir -p "$homedir/blogs" "$homedir/public"
            chown -R "$username:$username" "$homedir/blogs" "$homedir/public"
            chmod 700 "$homedir/blogs"
            chmod 755 "$homedir/public"

            [[ -f "$homedir/blogs.yaml" ]] || {
                echo "articles: []" > "$homedir/blogs.yaml"
                chown "$username:$username" "$homedir/blogs.yaml"
                chmod 600 "$homedir/blogs.yaml"
            }
        fi
    done
}

lock_removed_users() {
    local category=$1 base_dir=$(get_basedir "$category")
    for user_dir in "$base_dir"/*; do
        [[ -d "$user_dir" ]] || continue
        local username=$(basename "$user_dir")
        [[ "$username" =~ ^(root|harishannavisamy)$ ]] && continue

        get_usernames "$category" | grep -qw "$username" || {
            usermod -e 1 "$username" 2>/dev/null || true
            echo "Locked removed $category user: $username"
        }
    done
}

setup_users_all_blogs() {
    for username in $(get_usernames users); do
        [[ "$username" =~ ^(root|harishannavisamy)$ ]] && continue
        local blog_dir="/home/users/$username/all_blogs"
        mkdir -p "$blog_dir"
        chown "$username:$username" "$blog_dir"
        chmod 700 "$blog_dir"
        find "$blog_dir" -maxdepth 1 -type l -exec rm -f {} +

        for author_dir in /home/authors/*/public; do
            [[ -d "$author_dir" ]] || continue
            local author=$(basename "$(dirname "$author_dir")")
            [[ "$author" =~ ^(root|harishannavisamy)$ ]] && continue

            ln -s "$author_dir" "$blog_dir/$author"
            setfacl -m u:"$username":r-x "$author_dir"
            setfacl -d -m u:"$username":r-x "$author_dir"
        done
    done
}

grant_admin_accesses() {
    for admin in $(get_usernames admins); do
        [[ "$admin" =~ ^(root|harishannavisamy)$ ]] && continue
        for dir in /home/{users,authors,mods,admin}; do
            setfacl -R -m u:"$admin":rwx "$dir" || true
            setfacl -R -d -m u:"$admin":rwx "$dir" || true
        done
    done
}

setup_moderator_access() {
    for mod in $(get_usernames mods); do
        [[ "$mod" =~ ^(root|harishannavisamy)$ ]] && continue

        local mod_dir="/home/mods/$mod/authors"
        mkdir -p "$mod_dir"
        chown "$mod:$mod" "$mod_dir"
        chmod 750 "$mod_dir"
        find "$mod_dir" -maxdepth 1 -type l -exec rm -f {} +

        local authors=$(yq e ".mods[] | select(.username==\"$mod\") | .assigned_authors[]" "$USERS_YAML_FILE")
        for author in $authors; do
            [[ "$author" =~ ^(root|harishannavisamy)$ ]] && continue
            local pub="/home/authors/$author/public"
            [[ -d "$pub" ]] || continue

            ln -s "$pub" "$mod_dir/$author"
            setfacl -m u:"$mod":rwX "$pub"
            setfacl -d -m u:"$mod":rwX "$pub"
        done
    done
}

# --- Execution ---
lock_removed_users users
lock_removed_users authors

for category in "${CATEGORIES[@]}"; do
    create_or_unlock_users "$category"
    setup_home_dirs "$category"
done

setup_users_all_blogs

grant_admin_accesses
setup_moderator_access

# Secure scripts
chown root:g_admin /scripts/*
chmod 750 /scripts/initUsers.sh /scripts/userFY.sh /scripts/adminpannel.sh
chmod 740 /scripts/manageblogs.sh /scripts/blogfilter.sh
chmod 700 /scripts/*.sh

# Run setup scripts
for script in /scripts/manage_blogs_setup.sh /scripts/blogfilter_setup.sh \
              /scripts/blacklist_setup.sh /scripts/mod_permission_setup.sh \
              /scripts/adminpannel_setup.sh /scripts/users_permission.sh; do
    bash "$script"
done

echo "initusers: Done."
exit 0
