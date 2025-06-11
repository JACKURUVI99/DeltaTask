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

# Define key paths
SCRIPTS_DIR="/scripts"
USERS_YAML="/scripts/users.yaml"
USERPREF_YAML="/scripts/userpref.yaml"
REPORTS_DIR="/home/reports"

# Ensure groups exist
GROUPS=("g_user" "g_author" "g_mod" "g_admin")
for group in "${GROUPS[@]}"; do
    if ! getent group "$group" >/dev/null; then
        groupadd "$group"
    fi
done

# Add root to g_admin if not already a member
if [ "$(id -u)" = "0" ] && ! groups root | grep -q '\bg_admin\b'; then
    usermod -aG g_admin root
fi

# Set permissions for /scripts/ directory and files
set_scripts_permissions() {
    echo "Setting permissions for $SCRIPTS_DIR..."
    chown root:g_admin "$SCRIPTS_DIR"
    chmod 750 "$SCRIPTS_DIR"

    # Grant harishannavisamy full permissions on /scripts/
    setfacl -m u:harishannavisamy:rwx "$SCRIPTS_DIR" 2>/dev/null || true
    setfacl -d -m u:harishannavisamy:rwx "$SCRIPTS_DIR" 2>/dev/null || true

    # Admin scripts (initUsers, userFY, adminpannel, deleteusers, subscriptionModel, rolePromotion)
    ADMIN_SCRIPTS=("initUsers.sh" "userFY.sh" "adminpannel.sh" "deleteusers.sh" "subscriptionModel.sh" "rolePromotion.sh")
    for script in "${ADMIN_SCRIPTS[@]}"; do
        if [ -f "$SCRIPTS_DIR/$script" ]; then
            chown root:g_admin "$SCRIPTS_DIR/$script"
            chmod 750 "$SCRIPTS_DIR/$script"
            setfacl -m u:harishannavisamy:rwx "$SCRIPTS_DIR/$script" 2>/dev/null || true
        fi
    done

    # Author script (manageblogs)
    if [ -f "$SCRIPTS_DIR/manageblogs.sh" ]; then
        chown root:g_author "$SCRIPTS_DIR/manageblogs.sh"
        chmod 740 "$SCRIPTS_DIR/manageblogs.sh"
        setfacl -m u:harishannavisamy:rwx "$SCRIPTS_DIR/manageblogs.sh" 2>/dev/null || true
    fi

    # Moderator script (blogfilter)
    if [ -f "$SCRIPTS_DIR/blogfilter.sh" ]; then
        chown root:g_mod "$SCRIPTS_DIR/blogfilter.sh"
        chmod 740 "$SCRIPTS_DIR/blogfilter.sh"
        setfacl -m u:harishannavisamy:rwx "$SCRIPTS_DIR/blogfilter.sh" 2>/dev/null || true
    fi

    # Setup scripts (not directly executable by users)
    SETUP_SCRIPTS=("manage_blogs_setup.sh" "blogfilter_setup.sh" "blacklist_setup.sh" "mod_permission_setup.sh" "adminpannel_setup.sh" "setup_author_permission.sh" "setup.sh")
    for script in "${SETUP_SCRIPTS[@]}"; do
        if [ -f "$SCRIPTS_DIR/$script" ]; then
            chown root:g_admin "$SCRIPTS_DIR/$script"
            chmod 700 "$SCRIPTS_DIR/$script"
            setfacl -m u:harishannavisamy:rwx "$SCRIPTS_DIR/$script" 2>/dev/null || true
        fi
    done

    # YAML files
    for yaml in "$USERS_YAML" "$USERPREF_YAML"; do
        if [ -f "$yaml" ]; then
            chown root:g_admin "$yaml"
            chmod 640 "$yaml"
            setfacl -m u:harishannavisamy:rwx "$yaml" 2>/dev/null || true
        fi
    done
}

# Set permissions for home directories
set_home_permissions() {
    echo "Setting permissions for home directories..."
    BASE_DIRS=("/home/users" "/home/authors" "/home/mods" "/home/admin")
    for dir in "${BASE_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            chown root:g_admin "$dir"
            chmod 755 "$dir"
        fi
    done

    # Users
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

    # Authors
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

    # Moderators
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

    # Admins
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

# Grant admin access to all home directories
grant_admin_access() {
    echo "Granting admin access to all home directories..."
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
    # Grant harishannavisamy full access to all home directories
    for d in /home/users /home/authors /home/mods /home/admin; do
        if [ -d "$d" ]; then
            setfacl -R -m u:harishannavisamy:rwx "$d" 2>/dev/null || true
            setfacl -R -d -m u:harishannavisamy:rwx "$d" 2>/dev/null || true
        fi
    done
}

# Set moderator access to assigned authors' public directories
set_moderator_access() {
    echo "Setting moderator access to assigned authors' public directories..."
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

# Set user access to all authors' public directories
set_user_access() {
    echo "Setting user access to authors' public directories..."
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

# Set permissions for reports directory
set_reports_permissions() {
    echo "Setting permissions for $REPORTS_DIR..."
    if [ -d "$REPORTS_DIR" ]; then
        chown root:g_admin "$REPORTS_DIR"
        chmod 770 "$REPORTS_DIR"
        setfacl -m u:harishannavisamy:rwx "$REPORTS_DIR" 2>/dev/null || true
        setfacl -d -m u:harishannavisamy:rwx "$REPORTS_DIR" 2>/dev/null || true
    fi
}

# Add /scripts/ to system PATH
add_to_path() {
    echo "Adding $SCRIPTS_DIR to system PATH..."
    if ! grep -q "$SCRIPTS_DIR" /etc/profile; then
        echo "export PATH=\$PATH:$SCRIPTS_DIR" >> /etc/profile
        echo "Added $SCRIPTS_DIR to /etc/profile"
    fi
}

main() {
    echo "Configuring permissions for DeltaTask project..."
    set_scripts_permissions
    set_home_permissions
    grant_admin_access
    set_moderator_access
    set_user_access
    set_reports_permissions
    add_to_path
    echo "permissions.sh completed."
}

main
