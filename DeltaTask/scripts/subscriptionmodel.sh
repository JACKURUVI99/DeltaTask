#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SUBSCRIPTIONS_FILE="/scripts/subscriptions.yaml"

if ! command -v yq &>/dev/null; then
  echo "Error: yq not found."
  exit 1
fi

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <authorname>"
  exit 1
fi

author="$1"

if [[ ! -d "/home/authors/$author" ]]; then
  echo "Author does not exist: $author"
  exit 1
fi

username="$(whoami)"
USER_SUBSCRIBED_DIR="/home/users/$username/subscribed_blogs"
TARGET_LINK="$USER_SUBSCRIBED_DIR/$author"
AUTHOR_SUBSCRIBERS_DIR="/home/authors/$author/subscribers_only"

if [[ ! -w "$SUBSCRIPTIONS_FILE" ]]; then
  echo "Error: No write permission to $SUBSCRIPTIONS_FILE."
  echo "Please contact admin to adjust permissions."
  exit 1
fi

mkdir -p "$USER_SUBSCRIBED_DIR"

if ! yq e "has(\"$author\")" "$SUBSCRIPTIONS_FILE" | grep -q 'true'; then
  yq e -i ".\"$author\" = []" "$SUBSCRIPTIONS_FILE"
fi

if [[ -L "$TARGET_LINK" ]] || [[ -d "$TARGET_LINK" ]]; then
  yq e -i "del(.\"$author\"[] | select(. == \"$username\"))" "$SUBSCRIPTIONS_FILE"
  rm -f "$TARGET_LINK"
  echo "Unsubscribed from $author."
  exit 0
fi

if yq e ".\"$author\"[] | select(. == \"$username\")" "$SUBSCRIPTIONS_FILE" | grep -q "$username"; then
  echo "Already subscribed to $author."
  exit 0
fi

yq e -i ".\"$author\" += [\"$username\"]" "$SUBSCRIPTIONS_FILE"

if [[ -d "$AUTHOR_SUBSCRIBERS_DIR" ]]; then
  ln -sfn "$AUTHOR_SUBSCRIBERS_DIR" "$TARGET_LINK"
else
  echo "Warning: Author's subscribers_only directory not found: $AUTHOR_SUBSCRIBERS_DIR"
fi

echo "Subscribed to $author."
