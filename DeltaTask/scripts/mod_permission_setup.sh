#!/bin/bash
# File: mod_permission_setup.sh
#
# Grants full permissions to all moderators for all authors' blog directories.
# Requires: setfacl and yq v4+

set -euo pipefail
IFS=$'\n\t'

USERS_YAML_FILE="/home/harishannavisamy/new_Deltask/users.yaml"
BASE_AUTHORS_DIR="/home/authors"

# Ensure required tools exist
command -v setfacl >/dev/null || { echo "setfacl not found. Install it and retry."; exit 1; }
command -v yq >/dev/null || { echo "yq not found. Install yq v4+ and retry."; exit 1; }

# Get list of moderators and authors
get_moderators() {
  yq e -r '.mods[].username' "$USERS_YAML_FILE" 2>/dev/null || true
}

get_authors() {
  yq e -r '.authors[].username' "$USERS_YAML_FILE" 2>/dev/null || true
}

# Grant ACL permissions
echo "Applying moderator ACLs to authors' directories..."

for author in $(get_authors); do
  AUTHOR_DIR="$BASE_AUTHORS_DIR/$author"
  if [[ -d "$AUTHOR_DIR" ]]; then
    for mod in $(get_moderators); do
      echo "Granting rwx access to moderator '$mod' on $AUTHOR_DIR"
      setfacl -R -m u:"$mod":rwx "$AUTHOR_DIR"
      setfacl -R -d -m u:"$mod":rwx "$AUTHOR_DIR"
    done
  else
    echo "Author directory not found: $AUTHOR_DIR (skipping)"
  fi
done

echo "Moderator permissions applied."
