#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

REPORT_DIR="/scripts/reports"
ADMIN_GROUP="g_admin"

echo "Setting up admin panel reports directory..."

[ -d "$REPORT_DIR" ] || { echo "Creating $REPORT_DIR..."; mkdir -p "$REPORT_DIR"; }

echo "Assigning group '$ADMIN_GROUP' to $REPORT_DIR..."
chown -R root:"$ADMIN_GROUP" "$REPORT_DIR"

echo "Setting permissions to 770..."
chmod 770 "$REPORT_DIR"

echo "Setting setgid so new files inherit group..."
chmod g+s "$REPORT_DIR"

echo "Admin panel setup completed. Group '$ADMIN_GROUP' can now write to $REPORT_DIR."
