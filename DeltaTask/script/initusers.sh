#!/bin/bash

USERS_YAML_FILE="../users.yaml"

# Fix permissions on important project files/folders for current user
fix_permissions() {
  local current_user
  current_user=$(whoami)
  local base_dir="/home/harishannavisamy/new_Deltask"

  echo "Fixing permissions in $base_dir for user $current_user..."

  sudo chown -R "$current_user:$current_user" "$base_dir"
  sudo chmod -R u+rw "$base_dir"
  find "$base_dir" -type d -exec chmod u+rwx {} +

  echo "Permissions fixed."
}

# Groups & base dirs for each category
GROUPS=(g_user g_author g_mod g_admin)
BASEDIRS=("/home/users" "/home/authors" "/home/mods" "/home/admin")
CATEGORIES=(users authors mods admins)

default_password="123"

for grp in "${GROUPS[@]}"; do
  if ! getent group "$grp" >/dev/null; then
    groupadd "$grp"
  fi
done

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

get_fullname() {
  local category=$1
  local username=$2
  yq e ".${category}[] | select(.username==\"$username\") | .name" "$USERS_YAML_FILE"
}

create_or_unlock_user() {
  local category=$1
  local username=$2
  local fullname=$3
  local group
  local homedir

  group=$(get_group "$category")
  homedir="$(get_basedir "$category")/$username"

  if id "$username" >/dev/null 2>&1; then
    usermod -e -1 "$username" 2>/dev/null || true
  else
    useradd -m -d "$homedir" -c "$fullname" -G "$group" "$username"
    echo -e "${default_password}\n${default_password}" | passwd "$username" >/dev/null 2>&1
  fi
}

setup_home_dir() {
  local category=$1
  local username=$2
  local homedir

  homedir="$(get_basedir "$category")/$username"
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
  fi
}

lock_removed_users() {
  local category=$1
  local base_dir
  base_dir=$(get_basedir "$category")

  for user_dir in "$base_dir"/*; do
    [[ -d "$user_dir" ]] || continue
    username=$(basename "$user_dir")
    if [[ "$username" == "root" || "$username" == "harishannavisamy" ]]; then
      continue
    fi

    if ! grep -qw "$username" <(get_usernames "$category"); then
      usermod -e 1 "$username" 2>/dev/null || true
      echo "Locked removed $category user: $username"
    fi
  done
}

grant_admin_access() {
  local admin=$1
  for d in /home/users /home/authors /home/mods /home/admin; do
    setfacl -R -m u:"$admin":rwx "$d" 2>/dev/null || true
    setfacl -R -d -m u:"$admin":rwx "$d" 2>/dev/null || true
  done
}

setup_user_all_blogs() {
  local username=$1
  local user_dir="/home/users/$username"
  local all_blogs_dir="$user_dir/all_blogs"

  mkdir -p "$all_blogs_dir"
  chown "$username:$username" "$all_blogs_dir"
  find "$all_blogs_dir" -maxdepth 1 -type l -exec rm -f {} +

  for author_dir in /home/authors/*; do
    [[ -d "$author_dir/public" ]] || continue
    author=$(basename "$author_dir")
    ln -s "/home/authors/$author/public" "$all_blogs_dir/$author"
    setfacl -m u:"$username":r-x "/home/authors/$author/public"
    setfacl -d -m u:"$username":r-x "/home/authors/$author/public"
  done

  chown -R "$username:$username" "$all_blogs_dir"
}

# --- MAIN EXECUTION ---

fix_permissions

lock_removed_users users
lock_removed_users authors

for category in "${CATEGORIES[@]}"; do
  for username in $(get_usernames "$category"); do
    fullname=$(get_fullname "$category" "$username")
    create_or_unlock_user "$category" "$username" "$fullname"
    setup_home_dir "$category" "$username"
  done
done

for username in $(get_usernames users); do
  setup_user_all_blogs "$username"
done

for admin in $(get_usernames admins); do
  grant_admin_access "$admin"
done

# --- 👇 FINAL STEP: Ensure harishannavisamy can edit /scripts without sudo ---
echo "Fixing write permissions for harishannavisamy in /scripts..."
sudo chown -R harishannavisamy:harishannavisamy /home/harishannavisamy/new_Deltask/scripts
sudo chmod -R u+rwX /home/harishannavisamy/new_Deltask/scripts

# Run setup scripts
bash manage_blogs_setup.sh
bash blogfilter_setup.sh

echo "initusers: Done."
exit 0
#d
