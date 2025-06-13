# Blog Management and Subscription System

Welcome to the Blog Management and Subscription System! This is a Linux-based system for managing blogs, subscriptions, user preferences, and content moderation. It uses Bash scripts, YAML configuration files, and MySQL for data persistence, with fine-grained permissions via Linux ACLs (setfacl).

## System Overview

- **Purpose**: Allows users to subscribe to authors, authors to manage blogs, moderators to filter content, and admins to generate reports and manage users.
- **Key Features**:
  - User subscription to authors' exclusive content.
  - Blog creation, publishing, archiving, and deletion.
  - Content moderation using blacklists.
  - Personalized blog recommendations based on user preferences.
  - Admin reports on blog reads and categories.
- **Directory Structure**:
  - `/home/users/<username>`: User home directories with all_blogs and subscribed_blogs.
  - `/home/authors/<author>`: Author directories with blogs, public, and subscribers_only.
  - `/home/mods/<mod>`: Moderator directories with blacklist.txt and author symlinks.
  - `/scripts`: Contains all scripts and YAML configs (users.yaml, subscriptions.yaml, etc.).
  - `/scripts/reports`: Stores admin-generated reports.

## Scripts

### 1. `initusers.sh`
- **Purpose**: Initializes user accounts, groups, and home directories based on `users.yaml`.
- **Usage**: `sudo /scripts/initusers.sh`
- **Logic**: Creates users, sets up directories, and configures permissions.

### 2. `manageblogs.sh`
- **Purpose**: Allows authors to manage their blogs.
- **Usage**: `manageblogs.sh [option] <filename>`
- **Options**: `-n`, `-p`, `-a`, `-d`, `-e`, `-s`, `-h`
- **Logic**: Handles blog creation, publishing, archiving, and permissions.

### 3. `manage_blogs_setup.sh`
- **Purpose**: Sets up author directories and `blogs.yaml` files.
- **Usage**: `sudo /scripts/manage_blogs_setup.sh`
- **Logic**: Creates necessary directories and permissions.

### 4. `mod_permission_setup.sh`
- **Purpose**: Grants moderators full access to all authors' directories.
- **Usage**: `sudo /scripts/mod_permission_setup.sh`
- **Logic**: Uses `setfacl` to grant access.

### 5. `deleteusers.sh`
- **Purpose**: Deletes users and their directories, except protected users.
- **Usage**: `sudo /scripts/deleteusers.sh`
- **Logic**: Locks accounts and removes directories.

### 6. `renuewusers.sh`
- **Purpose**: Unlocks user accounts.
- **Usage**: `sudo /scripts/renuewusers.sh <username>`
- **Logic**: Removes expiration and password locks.

### 7. `permissions.sh`
- **Purpose**: Configures permissions for scripts, directories, and reports.
- **Usage**: `sudo /scripts/permissions.sh`
- **Logic**: Sets ownership and permissions.

### 8. `setup.sh`
- **Purpose**: Initializes groups, permissions, and directory structures.
- **Usage**: `sudo /scripts/setup.sh`
- **Logic**: Creates necessary groups and sets permissions.

### 9. `setup_author_permission.sh`
- **Purpose**: Sets permissions for authors' directories.
- **Usage**: `sudo /scripts/setup_author_permission.sh`
- **Logic**: Configures permissions for author directories.

### 10. `subscriptionmodel.sh`
- **Purpose**: Manages user subscriptions to authors' content.
- **Usage**: `subscriptionmodel.sh <authorname>`
- **Logic**: Handles subscription and unsubscription actions.

### 11. `adminpanel.sh`
- **Purpose**: Generates reports on blog activity for admins.
- **Usage**: `sudo /scripts/adminpanel.sh`
- **Logic**: Collects data and generates reports.

### 12. `adminpanel_setup.sh`
- **Purpose**: Sets up the reports directory.
- **Usage**: `sudo /scripts/adminpanel_setup.sh`
- **Logic**: Creates and configures the reports directory.

### 13. `blacklist_setup.sh`
- **Purpose**: Initializes moderators' blacklist.txt files.
- **Usage**: `sudo /scripts/blacklist_setup.sh`
- **Logic**: Creates blacklist files for moderators.

### 14. `blogfilter_setup.sh`
- **Purpose**: Configures moderators' access to authors' directories.
- **Usage**: `sudo /scripts/blogfilter_setup.sh`
- **Logic**: Sets up access for moderators.

### 15. `blogfilter.sh`
- **Purpose**: Censors blacklisted words in blogs.
- **Usage**: `blogfilter.sh <author_username>`
- **Logic**: Filters content based on blacklisted words.

### 16. `userFY.sh`
- **Purpose**: Generates personalized blog recommendations.
- **Usage**: `sudo /scripts/userFY.sh`
- **Logic**: Matches blogs to user preferences.

## Configuration Files
- `users.yaml`: Defines user roles and information.
- `userpref.yaml`: Stores user preferences.
- `subscriptions.yaml`: Maps authors to subscribers.
- `blogs.yaml`: Contains blog metadata.

## Dependencies
- **Tools**: bash, yq (v4+), setfacl, perl, mysql, nc (netcat).
- **Database**: MySQL (blogdb with root:kali credentials).
- **System**: Linux with ACL support.

## Setup Instructions
1. Clone the repository and place scripts in `/scripts`.
2. Install necessary tools.
3. Configure `users.yaml`, `userpref.yaml`, and MySQL.
4. Run `setup.sh` as root: `sudo /scripts/setup.sh`
5. Run `initusers.sh` to create users: `sudo /scripts/initusers.sh`

## Notes
- **Security**: Hardcoded MySQL passwords are a risk; consider using environment variables.
- **Redundancy**: Consolidate similar scripts if possible.
- **Duplicates**: Clean up `subscriptions.yaml` to avoid issues.

Happy blogging! 🚀 For issues or enhancements, contact the system admin.
