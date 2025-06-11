#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

if [ "$(id -u)" != "0" ] && ! groups | grep -q '\bg_admin\b'; then
    echo "Error: This script must be run by root or an admin (g_admin group)."
    exit 1
fi

if ! command -v yq &> /dev/null; then
    echo "Error: yq is required but not installed."
    exit 1
fi

SCRIPTS_DIR="/scripts"
USERS_YAML="/scripts/users.yaml"
USERPREF_YAML="/scripts/userpref.yaml"
REPORTS_DIR="/home/reports"

GROUPS=("g_user" "g_author" "g_mod" "g_admin")
for group in "${GROUPS[@]}"; do
    if ! getent group "$group" >/dev/null; then
        groupadd "$group"
    fi
done

if [ "$(id -u)" = "0" ] && ! groups root | grep -q '\bg_admin\b'; then
    usermod -aG g_admin root
fi

set_scripts_permissions() {
    chown root:g_admin "$SCRIPTS_DIR"
    chmod 750 "$SCRIPTS_DIR"
    setfacl -m u:harishannavisamy:rwx "$SCRIPTS_DIR" 2>/dev/null || true
    setfacl -d -m u:harishannavisamy:rwx "$SCRIPTS_DIR" 2>/dev/null || true

    ADMIN_SCRIPTS=("initUsers.sh" "userFY.sh" "adminpannel.sh" "deleteusers.sh" "subscriptionModel.sh" "rolePromotion.sh")
    for script in "${ADMIN_SCRIPTS[@]}"; do
        if [ -f "$SCRIPTS_DIR/$script" ]; then
            chown root:g_admin "$SCRIPTS_DIR/$script"
            chmod 750 "$SCRIPTS_DIR/$script"
            setfacl -m u:harishannavisamy:rwx "$SCRIPTS_DIR/$script" 2>/dev/null || true
        fi
    done

    if [ -f "$SCRIPTS_DIR/manageblogs.sh" ]; then
        chown root:g_author "$SCRIPTS_DIR/manageblogs.sh"
        chmod 740 "$SCRIPTS_DIR/manageblogs.sh"
        setfacl -m u:harishannavisamy:rwx "$SCRIPTS_DIR/manageblogs.sh" 2>/dev/null || true
    fi

    if [ -f "$SCRIPTS_DIR/blogfilter.sh" ]; then
        chown root:g_mod "$SCRIPTS_DIR/blogfilter.sh"
        chmod 740 "$SCRIPTS_DIR/blogfilter.sh"
        setfacl -m u:harishannavisamy:rwx "$SCRIPTS_DIR/blogfilter.sh" 2>/dev/null || true
    fi

    SETUP_SCRIPTS=("manage_blogs_setup.sh" "blogfilter_setup.sh" "blacklist_setup.sh" "mod_permission_setup.sh" "adminpannel_setup.sh" "setup_author_permission.sh" "setup.sh")
    for script in "${SETUP_SCRIPTS[@]}"; do
        if [ -f "$SCRIPTS_DIR/$script" ]; then
            chown root:g_admin "$SCRIPTS_DIR/$script"
            chmod 700 "$SCRIPTS_DIR/$script"
            setfacl -m u:harishannavisamy:rwx "$SCRIPTS_DIR/$script" 2>/dev/null || true
        fi
    done

    for yaml in "$USERS_YAML" "$USERPREF_YAML"; do
        if [ -f "$yaml" ]; then
            chown root:g_admin "$yaml"
            chmod 640 "$yaml"
            setfacl -m u:harishannavisamy:rwx "$yaml" 2>/dev/null || true
        fi
    done
}

set_home_permissions() {
    BASE_DIRS=("/home/users" "/home/authors" "/home/mods" "/home/admin")
    for dir in "${BASE_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            chown root:g_admin "$dir"
            chmod 755 "$dir"
        fi
    done

    if [ -d "/home/users" ]; then
        for user_dir in /home/users/*; do
            if [ -d "$user_dir" ]; then
                local username=$(basename "$user_dir")
                if [ "$username" != "harishannavisamy" ] && [ "$username" != "root" ]; then
                    chown -R "$username:g_user" "$user_dir"
                    chmod -R 700 "$user_dir"
                    if [ -d "$user_dir/all_blogs" ]; then
                        chown "$username:g_user" "$user_dir/all_blogs"
                        chmod 700 "$user_dir/all_blogs"
                    fi
                fi
            fi
        done
    fi

    if [ -d "/home/authors" ]; then
        for author_dir in /home/authors/*; do
            if [ -d "$author_dir" ]; then
                local username=$(basename "$author_dir")
                if [ "$username" != "harishannavisamy" ] && [ "$username" != "root" ]; then
                    chown -R "$username:g_author" "$author_dir"
                    chmod -R 700 "$author_dir"
                    if [ -d "$author_dir/blogs" ]; then
                        chown "$username:g_author" "$author_dir/blogs"
                        chmod 700 "$author_dir/blogs"
                    fi
                    if [ -d "$author_dir/public" ]; then
                        chown "$username:g_author" "$author_dir/public"
                        chmod 755 "$author_dir/public"
                    fi
                    if [ -f "$author_dir/blogs.yaml" ]; then
                        chown "$username:g_author" "$author_dir/blogs.yaml"
                        chmod 600 "$author_dir/blogs.yaml"
                    fi
                fi
            fi
        done
    fi

    if [ -d "/home/mods" ]; then
        for mod_dir in /home/mods/*; do
            if [ -d "$mod_dir" ]; then
                local username=$(basename "$mod_dir")
                if [ "$username" != "harishannavisamy" ] && [ "$username" != "root" ]; then
                    chown -R "$username:g_mod" "$mod_dir"
                    chmod -R 750 "$mod_dir"
                    if [ -d "$mod_dir/authors" ]; then
                        chown "$username:g_mod" "$mod_dir/authors"
                        chmod 750 "$mod_dir/authors"
                    fi
                    if [ -f "$mod_dir/blacklist.txt" ]; then
                        chown "$username:g_mod" "$mod_dir/blacklist.txt"
                        chmod 600 "$mod_dir/blacklist.txt"
                    fi
                fi
            fi
        done
    fi

    if [ -d "/home/admin" ]; then
        for admin_dir in /home/admin/*; do
            if [ -d "$admin_dir" ]; then
                local username=$(basename "$admin_dir")
                if [ "$username" != "harishannavisamy" ] && [ "$username" != "root" ]; then
                    chown -R "$username:g_admin" "$admin_dir"
                    chmod -R 700 "$admin_dir"
                fi
            fi
        done
    fi
}

grant_admin_access() {
    if [ -f "$USERS_YAML" ]; then
        admins=$(yq e '.admins[]?.username' "$USERS_YAML" 2>/dev/null || echo "")
        for admin in $admins; do
            if [ "$admin" != "harishannavisamy" ] && [ "$admin" != "root" ]; then
                for d in /home/users /home/authors /home/mods /home/admin; do
                    if [ -d "$d" ]; then
                        setfacl -R -m u:"$admin":rwx "$d" 2>/dev/null || true
                        setfacl -R -d -m u:"$admin":rwx "$d" 2>/dev/null || true
                    fi
                done
            fi
        done
    fi
    for d in /home/users /home/authors /home/mods /home/admin; do
        if [ -d "$d" ]; then
            setfacl -R -m u:harishannavisamy:rwx "$d" 2>/dev/null || true
            setfacl -R -d -m u:harishannavisamy:rwx "$d" 2>/dev/null || true
        fi
    done
}

set_moderator_access() {
    if [ -f "$USERS_YAML" ]; then
        mods=$(yq e '.mods[]?.username' "$USERS_YAML" 2>/dev/null || echo "")
        for mod in $mods; do
            if [ "$mod" != "harishannavisamy" ] && [ "$mod" != "root" ]; then
                local mod_dir="/home/mods/$mod"
                if [ -d "$mod_dir" ]; then
                    assigned_authors=$(yq e ".mods[] | select(.username==\"$mod\") | .assigned_authors[]?" "$USERS_YAML" 2>/dev/null || echo "")
                    for author in $assigned_authors; do
                        if [ "$author" != "harishannavisamy" ] && [ "$author" != "root" ] && [ -d "/home/authors/$author/public" ]; then
                            setfacl -m u:"$mod":rwX "/home/authors/$author/public" 2>/dev/null || true
                            setfacl -d -m u:"$mod":rwX "/home/authors/$author/public" 2>/dev/null || true
                        fi
                    done
                fi
            fi
        done
    fi
}

set_user_access() {
    if [ -f "$USERS_YAML" ]; then
        users=$(yq e '.users[]?.username' "$USERS_YAML" 2>/dev/null || echo "")
        for user in $users; do
            if [ "$user" != "harishannavisamy" ] && [ "$user" != "root" ]; then
                local user_dir="/home/users/$user"
                if [ -d "$user_dir/all_blogs" ]; then
                    for author_dir in /home/authors/*; do
                        if [ -d "$author_dir/public" ]; then
                            local author=$(basename "$author_dir")
                            if [ "$author" != "harishannavisamy" ] && [ "$author" != "root" ]; then
                                setfacl -m u:"$user":r-x "$author_dir/public" 2>/dev/null || true
                                setfacl -d -m u:"$user":r-x "$author_dir/public" 2>/dev/null || true
                            fi
                        fi
                    done
                fi
            fi
        done
    fi
}

set_reports_permissions() {
    if [ -d "$REPORTS_DIR" ]; then
        chown root:g_admin "$REPORTS_DIR"
        chmod 770 "$REPORTS_DIR"
        setfacl -m u:harishannavisamy:rwx "$REPORTS_DIR" 2>/dev/null || true
        setfacl -d -m u:harishannavisamy:rwx "$REPORTS_DIR" 2>/dev/null || true
    fi
}

add_to_path() {
    if ! grep -q "$SCRIPTS_DIR" /etc/profile; then
        echo "export PATH=\$PATH:$SCRIPTS_DIR" >> /etc/profile
    fi
}

main() {
    set_scripts_permissions
    set_home_permissions
    grant_admin_access
    set_moderator_access
    set_user_access
    set_reports_permissions
    add_to_path
}

main
