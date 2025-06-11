#!/bin/bash
# File: mod_permission_setup.sh
#
# Grants full permissions to all moderators for all authors' blog directories.
# Requires: setfacl and yq v4+

set -euo pipefail
IFS=$'\n\t'

USERS_YAML_FILE="/home/harishannavisamy/new_Deltask/users.yaml"
BASE_AUTHORS_DIR="/home/authors"

# Ensure setfacl is available
command -v setfacl >/dev/null 2>&1 || { echo >&2 "setfacl is required but not installed. Aborting."; exit 1; }

# Get list of moderators and authors
get_moderators() {
  yq e -r '.mods[].username' "$USERS_YAML_FILE" 2>/dev/null || true
}

get_authors() {
  yq e -r '.authors[].username' "$USERS_YAML_FILE" 2>/dev/null || true
}

# Grant ACLs
for author in $(get_authors); do
  AUTHOR_DIR="$BASE_AUTHORS_DIR/$author"
  if [[ -d "$AUTHOR_DIR" ]]; then
    for mod in $(get_moderators); do
      echo "Granting $mod full access to $AUTHOR_DIR"
      setfacl -R -m u:"$mod":rwx "$AUTHOR_DIR"
      setfacl -R -d -m u:"$mod":rwx "$AUTHOR_DIR"
    done
  else
    echo "Author directory $AUTHOR_DIR does not exist, skipping."
  fi
done

echo "✅ Moderator permissions applied."
