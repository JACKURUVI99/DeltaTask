#!/bin/bash
set -euo pipefail

BASE_AUTHORS_DIR="/home/authors"

for author_dir in "$BASE_AUTHORS_DIR"/*; do
  if [[ -d "$author_dir" ]]; then
    author=$(basename "$author_dir")
    chown -R "$author:$author" "$author_dir" || echo "Warning: user $author may not exist"
    chmod 700 "$author_dir"
    chmod 700 "$author_dir/blogs"
    chmod 755 "$author_dir/public"
    find "$author_dir/blogs" -type f -exec chmod 600 {} \; || echo "No blog files for $author"
    if [[ -f "$author_dir/blogs.yaml" ]]; then
      chmod 600 "$author_dir/blogs.yaml"
    fi
  fi
done
