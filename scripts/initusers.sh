#!/bin/bash

# Ensure the script is run by root or an admin (g_admin group)
if [ "$(id -u)" != "0" ] && ! groups | grep -q '\bg_admin\b'; then
    echo "Error: This script must be run by root or an admin (g_admin group)."
    exit 1
fi

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "Error: yq is required but not installed."
    exit 1
fi

# Define YAML file location
USERS_YAML_FILE="/scripts/users.yaml"
if [ ! -f "$USERS_YAML_FILE" ]; then
    echo "Error: users.yaml not found at $USERS_YAML_FILE"
    exit 1
fi

# Groups & base dirs for each category
GROUPS=(g_user g_author g_mod g_admin)
BASEDIRS=("/home/users" "/home/authors" "/home/mods" "/home/admin")
CATEGORIES=(users authors mods admins)

default_password="123"

# Create groups if they don't exist
for grp in "${GROUPS[@]}"; do
    if ! getent group "$grp" >/dev/null; then
        groupadd "$grp"
    fi
done

# Add root to g_admin if not already a member
if [ "$(id -u)" = "0" ] && ! groups root | grep -q '\bg_admin\b'; then
    usermod -aG g_admin root
fi

get_group() {
    case "$1" in
        users) echo "g_user" ;;
        authors) echo "g_author" ;;
        mods) echo "g_mod" ;;
        admins) echo "g_admin" ;;
        *) echo "" ;;
    esac
}

get_basedir() {
    case "$1" in
        users) echo "/home/users" ;;
        authors) echo "/home/authors" ;;
        mods) echo "/home/mods" ;;
        admins) echo "/home/admin" ;;
        *) echo "" ;;
    esac
}

get_usernames() {
    local category=$1
    yq e ".${category}[] | .username" "$USERS_YAML_FILE" 2>/dev/null || echo ""
}

get_fullnames() {
    local category=$1
    local username=$2
    yq e ".${category}[] | select(.username==\"$username\") | .name" "$USERS_YAML_FILE"
}

create_or_unlock_users() {
    local category=$1
    local usernames=$2
    local group
    local homedirs

    group=$(get_group "$category")

    homedirs=()
    for username in $usernames; do
        if [ "$username" != "harishannavisamy" ] && [ "$username" != "root" ]; then
            local fullname=$(get_fullnames "$category" "$username")
            local homedir="$(get_basedir "$category")/$username"

            if id "$username" >/dev/null 2>&1; then
                usermod -e -1 "$username" 2>/dev/null || true
            else
                useradd -m -d "$homedir" -c "$fullname" -G "$group" "$username"
                echo -e "${default_password}\n${default_password}" | passwd "$username" >/dev/null 2>&1
            fi
            homedirs+=("$homedir")
        fi
    done
}

setup_home_dirs() {
    local category=$1
    local usernames=$2

    for username in $usernames; do
        if [ "$username" != "harishannavisamy" ] && [ "$username" != "root" ]; then
            local homedir="$(get_basedir "$category")/$username"
            mkdir -p "$homedir"
            chown "$username:$username" "$homedir"

            case "$category" in
                users|authors) chmod 700 "$homedir" ;;
                mods) chmod 750 "$homedir" ;;
                admins) chmod 700 "$homedir" ;;
            esac

            if [[ "$category" == "authors" ]]; then
                mkdir -p "$homedir/blogs" "$homedir/public"
                chown -R "$username:$username" "$homedir/blogs" "$homedir/public"
                chmod 700 "$homedir/blogs"
                chmod 755 "$homedir/public"
                # Initialize blogs.yaml if not exists
                if [ ! -f "$homedir/blogs.yaml" ]; then
                    echo "articles: []" > "$homedir/blogs.yaml"
                    chown "$username:$username" "$homedir/blogs.yaml"
                    chmod 600 "$homedir/blogs.yaml"
                fi
            fi
        fi
    done
}

lock_removed_users() {
    local category=$1
    local base_dir
    base_dir=$(get_basedir "$category")

    for user_dir in "$base_dir"/*; do
        [[ -d "$user_dir" ]] || continue
        local username=$(basename "$user_dir")
        if [[ "$username" == "root" || "$username" == "harishannavisamy" ]]; then
            continue
        fi

        if ! grep -qw "$username" <(get_usernames "$category"); then
            usermod -e 1 "$username" 2>/dev/null || true
            echo "Locked removed $category user: $username"
        fi
    done
}

grant_admin_accesses() {
    local admins_usernames=$1
    for admin in $admins_usernames; do
        if [ "$admin" != "harishannavisamy" ] && [ "$admin" != "root" ]; then
            for d in /home/users /home/authors /home/mods /home/admin; do
                setfacl -R -m u:"$admin":rwx "$d" 2>/dev/null || true
                setfacl -R -d -m u:"$admin":rwx "$d" 2>/dev/null || true
            done
        fi
    done
}

setup_users_all_blogs() {
    local usernames=$1

    for username in $usernames; do
        if [ "$username" != "harishannavisamy" ] && [ "$username" != "root" ]; then
            local user_dir="/home/users/$username"
            local all_blogs_dir="$user_dir/all_blogs"

            mkdir -p "$all_blogs_dir"
            chown "$username:$username" "$all_blogs_dir"
            chmod 700 "$all_blogs_dir"
            find "$all_blogs_dir" -maxdepth 1 -type l -exec rm -f {} +

            for author_dir in /home/authors/*; do
                [[ -d "$author_dir/public" ]] || continue
                local author=$(basename "$author_dir")
                if [ "$author" != "harishannavisamy" ] && [ "$author" != "root" ]; then
                    ln -s "/home/authors/$author/public" "$all_blogs_dir/$author"
                    setfacl -m u:"$username":r-x "/home/authors/$author/public"
                    setfacl -d -m u:"$username":r-x "/home/authors/$author/public"
                fi
            done

            chown -R "$username:$username" "$all_blogs_dir"
        fi
    done
}

setup_moderator_access() {
    local mods_usernames
    mods_usernames=$(get_usernames mods)

    for mod in $mods_usernames; do
        if [ "$mod" != "harishannavisamy" ] && [ "$mod" != "root" ]; then
            local mod_dir="/home/mods/$mod"
            mkdir -p "$mod_dir/authors"
            chown "$mod:$mod" "$mod_dir/authors"
            chmod 750 "$mod_dir/authors"
            find "$mod_dir/authors" -maxdepth 1 -type l -exec rm -f {} +

            # Get assigned authors for the moderator
            local assigned_authors
            assigned_authors=$(yq e ".mods[] | select(.username==\"$mod\") | .assigned_authors[]" "$USERS_YAML_FILE" 2>/dev/null)
            for author in $assigned_authors; do
                if [ "$author" != "harishannavisamy" ] && [ "$author" != "root" ] && [ -d "/home/authors/$author/public" ]; then
                    ln -s "/home/authors/$author/public" "$mod_dir/authors/$author"
                    setfacl -m u:"$mod":rwX "/home/authors/$author/public"
                    setfacl -d -m u:"$mod":rwX "/home/authors/$author/public"
                fi
            done
        fi
    done
}

# --- MAIN EXECUTION ---

# Lock removed users
lock_removed_users users
lock_removed_users authors

# Process users for each category
for category in "${CATEGORIES[@]}"; do
    usernames=$(get_usernames "$category")
    create_or_unlock_users "$category" "$usernames"
    setup_home_dirs "$category" "$usernames"
done

# Setup user access to all blogs
usernames=$(get_usernames users)
setup_users_all_blogs "$usernames"

# Grant admin access
admins_usernames=$(get_usernames admins)
grant_admin_accesses "$admins_usernames"

# Setup moderator access to assigned authors
setup_moderator_access

# Set script permissions
chown root:g_admin /scripts/*
chmod 750 /scripts/initUsers.sh
chmod 750 /scripts/userFY.sh
chmod 750 /scripts/adminpannel.sh
chmod 740 /scripts/manageblogs.sh
chmod 740 /scripts/blogfilter.sh
chmod 700 /scripts/*.sh  # Default for setup scripts

# Run setup scripts
bash /scripts/manage_blogs_setup.sh
bash /scripts/blogfilter_setup.sh
bash /scripts/blacklist_setup.sh
bash /scripts/mod_permission_setup.sh
bash /scripts/adminpannel_setup.sh
bash users_permission.sh

echo "initusers: Done."
exit 0