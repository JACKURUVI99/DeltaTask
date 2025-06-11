#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

USERS_YAML="/scripts/users.yaml"
PROTECTED_USERS=(root harishannavisamy)
GROUPS=(g_user g_author g_mod g_admin)
CATEGORIES=(users authors mods admins)

[ "$(id -u)" = "0" ] || groups | grep -qw g_admin || { echo "Run as root or g_admin"; exit 1; }
command -v yq &>/dev/null || { echo "yq required"; exit 1; }
[ -f "$USERS_YAML" ] || { echo "Missing $USERS_YAML"; exit 1; }

is_protected() {
    [[ " ${PROTECTED_USERS[*]} " =~ " $1 " ]]
}

user_exists() {
    id "$1" &>/dev/null
}

delete_user() {
    local u=$1
    is_protected "$u" && { echo "Skipping protected: $u"; return; }
    user_exists "$u" || { echo "No such user: $u"; return; }

    echo "Locking and deleting $u"
    usermod -e 1 "$u" 2>/dev/null || echo "Cannot lock $u"
    home=$(getent passwd "$u" | cut -d: -f6)
    [ -d "$home" ] && rm -rf "$home" || echo "No home for $u"
    userdel "$u" 2>/dev/null || echo "Cannot delete $u"
}

delete_groups() {
    for g in "${GROUPS[@]}"; do
        getent group "$g" &>/dev/null && { groupdel "$g" || echo "⚠️ Cannot delete group $g"; }
    done
}

for cat in "${CATEGORIES[@]}"; do
    echo ">>$cat"
    while read -r u; do
        [ -n "$u" ] && delete_user "$u"
    done < <(yq e ".${cat}[]?.username" "$USERS_YAML" || true)
done

delete_groups

chmod 750 /scripts/deleteusers.sh
chown root:g_admin /scripts/deleteusers.sh

echo "done."
