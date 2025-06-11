#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

USERS_YAML_FILE="/home/harishannavisamy/new_Deltask/users.yaml"
BASE_AUTHORS_DIR="/home/authors"

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
  local dest="$1"
  {
    echo "categories:"
    for key in $(printf "%s\n" "${!GLOBAL_CATEGORIES[@]}" | sort -n); do
      echo "  $key: \"${GLOBAL_CATEGORIES[$key]}\""
    done
    echo
    echo "blogs:"
    echo "  - file_name: \"example_blog.txt\""
    echo "    publish_status: false"
    echo "    cat_order: []"
    echo "    subscribers_only: false"
  } > "$dest"
}

get_author_usernames() {
  yq e -r '.authors[].username' "$USERS_YAML_FILE" 2>/dev/null || true
}

for author in $(get_author_usernames); do
  AUTHOR_DIR="$BASE_AUTHORS_DIR/$author"
  BLOGS_DIR="$AUTHOR_DIR/blogs"
  PUBLIC_DIR="$AUTHOR_DIR/public"
  SUBS_DIR="$AUTHOR_DIR/subscribers_only"
  BLOGS_YAML="$AUTHOR_DIR/blogs.yaml"

  echo "Setting up author: $author"

  mkdir -p "$BLOGS_DIR" "$PUBLIC_DIR" "$SUBS_DIR"

  chown -R "$author:$author" "$AUTHOR_DIR"

  chmod 700 "$AUTHOR_DIR" "$BLOGS_DIR" "$SUBS_DIR"
  chmod 755 "$PUBLIC_DIR"

  if [[ ! -f "$BLOGS_YAML" ]]; then
    echo "Creating default blogs.yaml for $author"
    create_default_blogs_yaml "$BLOGS_YAML"
    chown "$author:$author" "$BLOGS_YAML"
    chmod 600 "$BLOGS_YAML"
  else
    echo "blogs.yaml already exists for $author — skipping."
  fi
done

echo "Author blog directories and metadata setup complete."
