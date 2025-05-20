#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: Please run this script as root."
    exit 1
fi

yamlFileUH="../users.yaml"
if [ ! -f "$yamlFileUH" ]; then
    echo "Error: users.yaml file uh $yamlFileUH inga ila baa!"
    exit 1
fi

delete_users_by_role() {
    rolename="$1"
    yamlkey="$2"

    echo ""
    echo "Removing $rolename users 😬"

    for username in $(yq -r ".${yamlkey}[]?.username" "$yamlFileUH"); do
        if id "$username" &>/dev/null; then
            userdel -r "$username"
            echo "  - User '$username' remove pannitom."
        else
            echo "  - User '$username' illa so, skip uh!."
        fi
    done
}

delete_users_by_role "Admin"     "admins"
delete_users_by_role "Regular"   "users"
delete_users_by_role "Author"    "authors"
delete_users_by_role "Moderator" "mods"

echo ""
echo "All users remove aayiduchu."
exit 0
