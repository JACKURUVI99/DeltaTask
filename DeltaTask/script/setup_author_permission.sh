#!/bin/bash
# setup_author_permissions.sh
# Fix ownership and permissions for author directories and blog files

set -euo pipefail

BASE_AUTHORS_DIR="/home/authors"

echo "Fixing permissions under $BASE_AUTHORS_DIR..."

for author_dir in "$BASE_AUTHORS_DIR"/*; do
  if [[ -d "$author_dir" ]]; then
    author=$(basename "$author_dir")
    echo "Processing author: $author"

    # Change ownership recursively to author user
    chown -R "$author:$author" "$author_dir" || echo "Warning: user $author may not exist"

    # Permissions
    chmod 700 "$author_dir"
    chmod 700 "$author_dir/blogs"
    chmod 755 "$author_dir/public"

    # Make sure blog files are writable by owner
    find "$author_dir/blogs" -type f -exec chmod 600 {} \; || echo "No blog files for $author"
    # Make blogs.yaml readable and writable only by owner
    if [[ -f "$author_dir/blogs.yaml" ]]; then
      chmod 600 "$author_dir/blogs.yaml"
    fi
  fi
done

echo "Permission fix complete."
