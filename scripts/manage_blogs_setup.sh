#!/bin/bash
# File: manage_blogs_setup.sh
#
# Initialize each author's blog directory and blogs.yaml metadata with default categories.
# Run as root or with permissions to create directories under /home/authors.
# Requires: yq v4+

set -euo pipefail
IFS=$'\n\t'

# Use absolute paths to avoid confusion
USERS_YAML_FILE="/home/harishannavisamy/new_Deltask/users.yaml"
BASE_AUTHORS_DIR="/home/authors"

# Category map
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
  local dest_file="$1"
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
    echo "    subscribers_only: false"
  } > "$dest_file"
}

get_author_usernames() {
  yq e -r '.authors[].username' "$USERS_YAML_FILE" 2>/dev/null || true
}

# Main loop
for author in $(get_author_usernames); do
  AUTHOR_DIR="$BASE_AUTHORS_DIR/$author"
  BLOGS_DIR="$AUTHOR_DIR/blogs"
  PUBLIC_DIR="$AUTHOR_DIR/public"
  SUBS_DIR="$AUTHOR_DIR/subscribers_only"
  BLOGS_YAML="$AUTHOR_DIR/blogs.yaml"

  echo "Setting up author: $author"

  # Create blog directories
  mkdir -p "$BLOGS_DIR" "$PUBLIC_DIR" "$SUBS_DIR"

  # Set correct ownership and permissions
  chown -R "$author:$author" "$AUTHOR_DIR"
  chmod 700 "$AUTHOR_DIR"
  chmod 700 "$BLOGS_DIR"
  chmod 755 "$PUBLIC_DIR"
  chmod 700 "$SUBS_DIR"

  # Create blogs.yaml if not exists
  if [[ ! -f "$BLOGS_YAML" ]]; then
    echo "Creating default blogs.yaml for $author"
    create_default_blogs_yaml "$BLOGS_YAML"
    chown "$author:$author" "$BLOGS_YAML"
    chmod 600 "$BLOGS_YAML"
  else
    echo "blogs.yaml already exists for $author — skipping."
  fi
done

echo "✅ Author blog directories and metadata setup complete."
