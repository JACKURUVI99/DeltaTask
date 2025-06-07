#!/bin/bash

USERS_YAML_FILE="../users.yaml"

# Fix permissions on important project files/folders for current user
fix_permissions() {
  # Get current user running the script
  local current_user
  current_user=$(whoami)

  # Base project directory - adjust if needed
  local base_dir="/home/harishannavisamy/new_Deltask"

  echo "Fixing permissions in $base_dir for user $current_user..."

  # Change ownership recursively to current user
  sudo chown -R "$current_user":"$current_user" "$base_dir"

  # Fix permissions - readable and writable by owner
  sudo chmod -R u+rw "$base_dir"

  # Make sure directories are executable for user
  find "$base_dir" -type d -exec chmod u+rwx {} +

  echo "Permissions fixed."
}

# Groups & base dirs for each category
GROUPS=(g_user g_author g_mod g_admin)
BASEDIRS=("/home/users" "/home/authors" "/home/mods" "/home/admin")
CATEGORIES=(users authors mods admins)

default_password="123"

# Create groups if missing
for grp in "${GROUPS[@]}"; do
  if ! getent group "$grp" >/dev/null; then
    groupadd "$grp"
  fi
done

# Function to get group by category
get_group() {
  case "$1" in
    users) echo "g_user" ;;
    authors) echo "g_author" ;;
    mods) echo "g_mod" ;;
    admins) echo "g_admin" ;;
    *) echo "" ;;
  esac
}

# Function to get base dir by category
get_basedir() {
  case "$1" in
    users) echo "/home/users" ;;
    authors) echo "/home/authors" ;;
    mods) echo "/home/mods" ;;
    admins) echo "/home/admin" ;;
    *) echo "" ;;
  esac
}

#Read usernames from YAML for a category
get_usernames() {
  local category=$1
  yq e ".${category}[] | .username" "$USERS_YAML_FILE" 2>/dev/null || echo ""
}

# Read full name for user from YAML
get_fullname() {
  local category=$1
  local username=$2
  yq e ".${category}[] | select(.username==\"$username\") | .name" "$USERS_YAML_FILE"
}

# Create or unlock user
create_or_unlock_user() {
  local category=$1
  local username=$2
  local fullname=$3
  local group
  local homedir

  group=$(get_group "$category")
  homedir="$(get_basedir "$category")/$username"

  if id "$username" >/dev/null 2>&1; then
    # Unlock user (expire date -1)
    usermod -e -1 "$username" 2>/dev/null || true
  else
    # Create user with home, comment(fullname), primary group and add to group
    useradd -m -d "$homedir" -c "$fullname" -G "$group" "$username"
    echo -e "${default_password}\n${default_password}" | passwd "$username" >/dev/null 2>&1
  fi
}

# Setup home directory and permissions for a user
setup_home_dir() {
  local category=$1
  local username=$2
  local homedir

  homedir="$(get_basedir "$category")/$username"

  # Create home dir if missing
  mkdir -p "$homedir"

  # Set ownership
  chown "$username:$username" "$homedir"

  # Set permissions
  case "$category" in
    users|authors)
      chmod 700 "$homedir"
      ;;
    mods)
      chmod 750 "$homedir"
      ;;
    admins)
      chmod 700 "$homedir"
      ;;
  esac

  # For authors: create blogs and public directories only
  if [[ "$category" == "authors" ]]; then
    mkdir -p "$homedir/blogs" "$homedir/public"
    chown -R "$username:$username" "$homedir/blogs" "$homedir/public"
    chmod 700 "$homedir/blogs"
    chmod 755 "$homedir/public"
  fi
}

# Lock users removed from YAML, except root and harishannavisamy
lock_removed_users() {
  local category=$1
  local base_dir
  base_dir=$(get_basedir "$category")

  for user_dir in "$base_dir"/*; do
    [[ -d "$user_dir" ]] || continue
    username=$(basename "$user_dir")
    # Skip root and harishannavisamy
    if [[ "$username" == "root" || "$username" == "harishannavisamy" ]]; then
      continue
    fi

    # Check if user is in YAML
    if ! grep -qw "$username" <(get_usernames "$category"); then
      # Lock user account
      usermod -e 1 "$username" 2>/dev/null || true
      echo "Locked removed $category user: $username"
    fi
  done
}

# Give admin full access to all home directories
grant_admin_access() {
  local admin=$1
  for d in /home/users /home/authors /home/mods /home/admin; do
    # Use setfacl to give rwx to admin on all dirs recursively
    setfacl -R -m u:"$admin":rwx "$d" 2>/dev/null || true
    setfacl -R -d -m u:"$admin":rwx "$d" 2>/dev/null || true
  done
}

# Create all_blogs symlinks for users to authors' public dirs (read-only)
setup_user_all_blogs() {
  local username=$1
  local user_dir="/home/users/$username"
  local all_blogs_dir="$user_dir/all_blogs"

  mkdir -p "$all_blogs_dir"
  chown "$username:$username" "$all_blogs_dir"

  # Clear old symlinks
  find "$all_blogs_dir" -maxdepth 1 -type l -exec rm -f {} +

  # Link each author's public dir
  for author_dir in /home/authors/*; do
    [[ -d "$author_dir/public" ]] || continue
    author=$(basename "$author_dir")
    ln -s "/home/authors/$author/public" "$all_blogs_dir/$author"
    setfacl -m u:"$username":r-x "/home/authors/$author/public"
    setfacl -d -m u:"$username":r-x "/home/authors/$author/public"
  done

  chown -R "$username:$username" "$all_blogs_dir"
}

# Main script starts here

# Fix permissions before doing anything else
fix_permissions

# Lock removed users first for users and authors only
lock_removed_users users
lock_removed_users authors

# For each category, create or unlock users, and setup home dirs
for category in "${CATEGORIES[@]}"; do
  for username in $(get_usernames "$category"); do
    fullname=$(get_fullname "$category" "$username")
    create_or_unlock_user "$category" "$username" "$fullname"
    setup_home_dir "$category" "$username"
  done
done

# Setup all_blogs for users3
for username in $(get_usernames users); do
  setup_user_all_blogs "$username"
done

# Grant admins full access
for admin in $(get_usernames admins); do
  grant_admin_access "$admin"
done
bash manage_blogs_setup.sh
bash blogfilter_setup.sh
echo "initusers: Done."
exit 0
