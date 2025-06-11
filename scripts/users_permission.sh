#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

SCRIPTS_DIR="/scripts"
FULL_USER="harishannavisamy"
GROUPS=("g_author" "g_user" "g_mod" "g_admin")

# Must be run as root or user in g_admin
if [[ "$(id -u)" -ne 0 && -z "$(id -nG | grep -w g_admin)" ]]; then
    echo "❌ This script must be run as root or by a user in g_admin group."
    exit 1
fi

# Ensure /scripts exists
if [[ ! -d "$SCRIPTS_DIR" ]]; then
    echo "📁 Creating $SCRIPTS_DIR..."
    mkdir -p "$SCRIPTS_DIR"
    chown root:root "$SCRIPTS_DIR"
fi

# Create groups if they don't exist
for group in "${GROUPS[@]}"; do
    if ! getent group "$group" > /dev/null; then
        echo "➕ Creating missing group: $group"
        groupadd "$group"
    fi
done

# Set base permissions
echo "🔧 Setting ownership and base permissions..."
chown -R root:root "$SCRIPTS_DIR"
chmod -R 770 "$SCRIPTS_DIR"

# Grant full access to user
echo "👤 Granting full access to user: $FULL_USER"
setfacl -R -m u:"$FULL_USER":rwx "$SCRIPTS_DIR"
setfacl -R -d -m u:"$FULL_USER":rwx "$SCRIPTS_DIR"

# Grant full access to each group
for group in "${GROUPS[@]}"; do
    echo "👥 Granting full access to group: $group"
    setfacl -R -m g:"$group":rwx "$SCRIPTS_DIR"
    setfacl -R -d -m g:"$group":rwx "$SCRIPTS_DIR"
done

# Ensure files/directories have correct mode
echo "🛠 Normalizing permissions..."
find "$SCRIPTS_DIR" -type f -exec chmod 770 {} +
find "$SCRIPTS_DIR" -type d -exec chmod 770 {} +

echo "✅ Permissions applied to $SCRIPTS_DIR:"
echo "   - User: $FULL_USER (rwx)"
echo "   - Groups: ${GROUPS[*]} (rwx)"
sudo setfacl -m g:g_mod:rwx /scripts/blogfilter.sh
