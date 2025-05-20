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
add_users_by_role() {
    rolename="$1"
    yamlkey="$2"

    echo ""
    echo "Processing $rolename users '>_<'"

    for username in $(yq -r ".${yamlkey}[]?.username" "$yamlFileUH"); do
        if id "$username" &>/dev/null; then
            echo "  - User '$username' already irukaaru so, Skipping."
        else
            useradd -m -s /bin/bash "$username"
            echo "  - User '$username' create Panniyachu."
        fi
    done
}
add_users_by_role "Admin"     "admins"
add_users_by_role "Regular"   "users"
add_users_by_role "Author"    "authors"
add_users_by_role "Moderator" "mods"

echo ""
echo "Mudijitu!:]"
exit 0
