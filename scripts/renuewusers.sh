#!/bin/bash

# renew_user.sh
# Unlocks user account(s). Supports single username or '@everyone' to unlock all regular users.

# --- Usage Help ---
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <username>"
  echo "       $0 @everyone    # to renew all users"
  echo "Example: $0 aarav01"
  exit 1
fi

renew_user() {
  local username="$1"
  if id "$username" &>/dev/null; then
    sudo usermod -e -1 "$username"
    sudo passwd -u "$username" &>/dev/null
    echo "✅ Renewed user: $username"
  else
    echo "⚠️  Skipped: User '$username' does not exist"
  fi
}

if [[ "$1" == "@everyone" ]]; then
  echo "🔁 Renewing all regular users..."
  for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" { print $1 }' /etc/passwd); do
    renew_user "$user"
  done
else
  renew_user "$1"
fi
