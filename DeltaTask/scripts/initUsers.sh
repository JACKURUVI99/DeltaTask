#!/bin/bash
[ "$(id -u)" -ne 0 ] && { echo "Run as root"; exit 1; }

yamlFile="../users.yaml"
[ ! -f "$yamlFile" ] && { echo "Missing users.yaml"; exit 1; }

groupadd -f g_admin
groupadd -f g_user
groupadd -f g_author
groupadd -f g_mod

create_user() {
  useradd -m -s /bin/bash -g "$2" -d "/home/$3/$1" "$1" 2>/dev/null || true
}

yq eval '.admins[].username' "$yamlFile" 2>/dev/null | while read -r user; do
  [ -n "$user" ] && create_user "$user" g_admin admin
done

yq eval '.users[].username' "$yamlFile" 2>/dev/null | while read -r user; do
  if [ -n "$user" ]; then
    create_user "$user" g_user users
    mkdir -p "/home/users/$user/all_blogs"
  fi
done

yq eval '.authors[].username' "$yamlFile" 2>/dev/null | while read -r user; do
  if [ -n "$user" ]; then
    create_user "$user" g_author authors
    mkdir -p "/home/authors/$user/"{blogs,public}
  fi
done

yq eval '.mods[] | .username + " " + (.assigned_authors | join(" "))' "$yamlFile" 2>/dev/null | while read -r mod authors; do
  if [ -n "$mod" ]; then
    create_user "$mod" g_mod mods
    rm -f "/home/mods/$mod/"*
    for author in $authors; do
      [ -n "$author" ] && ln -sf "/home/authors/$author/public" "/home/mods/$mod/$author"
    done
  fi
done

yq eval '.authors[].username' "$yamlFile" 2>/dev/null | while read -r author; do
  if [ -n "$author" ]; then
    yq eval '.users[].username' "$yamlFile" 2>/dev/null | while read -r user; do
      [ -n "$user" ] && ln -sf "/home/authors/$author/public" "/home/users/$user/all_blogs/$author"
    done
  fi
done
