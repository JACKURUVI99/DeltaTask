#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

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

PROTECTED_USERS=("root" "harishannavisamy")
GROUP_KEYS=("users" "authors" "mods" "admins")
GROUPS=("g_user" "g_author" "g_mod" "g_admin")

# Check if user is protected
is_protected_user() {
    local u=$1
    for p in "${PROTECTED_USERS[@]}"; do
        if [[ "$u" == "$p" ]]; then
            return 0
        fi
    done
    return 1
}

# Check if user exists on system
user_exists() {
    id "$1" &>/dev/null
}

# Lock and delete user safely
lock_and_delete_user() {
    local user=$1
    if is_protected_user "$user"; then
        echo "Skipping protected user: $user"
        return
    fi

    if ! user_exists "$user"; then
        echo "User $user does not exist on system, skipping."
        return
    fi

    echo "Locking user: $user"
    usermod -e 1 "$user" 2>/dev/null || echo "Warning: failed to lock $user"

    local homedir
    homedir=$(getent passwd "$user" | cut -d: -f6)
    if [[ -d "$homedir" ]]; then
        echo "Removing home directory of $user: $homedir"
        rm -rf "$homedir"
    else
        echo "Home directory for $user not found, skipping removal"
    fi

    echo "Deleting user: $user"
    userdel "$user" 2>/dev/null || echo "Warning: failed to delete $user"
}

# Extract usernames from YAML category using yq
get_users_from_yaml() {
    local category=$1
    yq e ".${category}[]?.username" "$USERS_YAML_FILE" 2>/dev/null || echo ""
}

# Delete groups if they exist
delete_groups() {
    for group in "${GROUPS[@]}"; do
        if getent group "$group" >/dev/null; then
            echo "Deleting group: $group"
            groupdel "$group" 2>/dev/null || echo "Warning: failed to delete group $group"
        fi
    done
}

main() {
    for category in "${GROUP_KEYS[@]}"; do
        echo "Processing category: $category"
        mapfile -t yaml_users < <(get_users_from_yaml "$category")

        for user in "${yaml_users[@]}"; do
            lock_and_delete_user "$user"
        done
    done

    # Delete groups after users
    delete_groups

    # Set script permissions
    chown root:g_admin /scripts/deleteusers.sh
    chmod 750 /scripts/deleteusers.sh

    echo "deleteusers.sh completed."
}

main