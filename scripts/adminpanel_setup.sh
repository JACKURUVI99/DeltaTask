#!/bin/bash

# adminpanel_setup.sh
# This script sets up the reports directory for admin panel usage.

REPORT_DIR="/scripts/reports"
ADMIN_GROUP="g_admin"

echo "Setting up admin panel reports directory..."

# Step 1: Create the reports directory if it doesn't exist
if [ ! -d "$REPORT_DIR" ]; then
    echo "Creating $REPORT_DIR..."
    sudo mkdir -p "$REPORT_DIR"
else
    echo "$REPORT_DIR already exists."
fi

# Step 2: Change group ownership to g_admin
echo "Assigning group '$ADMIN_GROUP' to $REPORT_DIR..."
sudo chown -R root:"$ADMIN_GROUP" "$REPORT_DIR"

# Step 3: Give group read/write/execute permissions
echo "Setting permissions to 770..."
sudo chmod 770 "$REPORT_DIR"

# Step 4: Set setgid bit so files inherit group
echo "Setting setgid so new files inherit group..."
sudo chmod g+s "$REPORT_DIR"

echo "Admin panel setup completed. Group '$ADMIN_GROUP' can now write to $REPORT_DIR."
