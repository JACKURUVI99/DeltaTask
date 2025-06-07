#!/bin/bash
# File: manage_blogs_setup.sh
#
# Script to initialize each author’s blog directory and blogs.yaml metadata file 
# based on a global categories list, setting up default structure and example metadata.
#
# Must be run as root or with appropriate permissions.
# Assumes authors’ home dirs are under /home/authors/<username>
# Uses 'yq' command for YAML manipulation.
#
# This script scans all authors listed in the users.yaml file and initializes their blog dirs.

set -euo pipefail
IFS=$'\n\t'

USERS_YAML_FILE="../users.yaml"    # Adjust path if needed
BASE_AUTHORS_DIR="/home/authors"

# Hardcoded categories map; or load from a central config if you prefer
declare -A GLOBAL_CATEGORIES=(
  [1]="Sports"
  [2]="Cinema"
  [3]="Technology"
  [4]="Travel"
  [5]="Food"
  [6]="Lifestyle"
  [7]="Finance"
)

create_default_blogs_yaml() {
  local dest_file=$1

  {
    echo "categories:"
    for key in "${!GLOBAL_CATEGORIES[@]}"; do
      echo "  $key: \"${GLOBAL_CATEGORIES[$key]}\""
    done
    echo
    echo "blogs:"
    echo "  - file_name: \"example_blog.txt\""
    echo "    publish_status: false"
    echo "    cat_order: []"
  } > "$dest_file"
}

# Extract author usernames from YAML (the Linux usernames)
get_author_usernames() {
  yq e -r '.authors[].username' "$USERS_YAML_FILE" 2>/dev/null || true
}

for author in $(get_author_usernames); do
  AUTHOR_DIR="$BASE_AUTHORS_DIR/$author"
  BLOGS_DIR="$AUTHOR_DIR/blogs"
  PUBLIC_DIR="$AUTHOR_DIR/public"
  BLOGS_YAML="$AUTHOR_DIR/blogs.yaml"

  echo "Setting up author: $author"

  # Create directories
  mkdir -p "$BLOGS_DIR" "$PUBLIC_DIR"

  # Set ownership and permissions
  chown -R "$author:$author" "$AUTHOR_DIR"
  chmod 700 "$AUTHOR_DIR"
  chmod 700 "$BLOGS_DIR"
  chmod 755 "$PUBLIC_DIR"

  # Create default blogs.yaml if missing
  if [[ ! -f "$BLOGS_YAML" ]]; then
    echo "Creating default blogs.yaml for $author"
    create_default_blogs_yaml "$BLOGS_YAML"
    chown "$author:$author" "$BLOGS_YAML"
    chmod 600 "$BLOGS_YAML"
  else
    echo "blogs.yaml already exists for $author, skipping creation."
  fi
done

echo "Author blog directories and metadata setup complete."
