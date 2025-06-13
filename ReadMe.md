# 🚀 Blog Management and Subscription System

Welcome to the **Blog Management and Subscription System** – a Linux-based platform for managing blogs, subscriptions, user preferences, and moderation. Built entirely with Bash scripts, YAML files, MySQL, and Linux ACLs.

> 🧪 **Tested On:**  
> OS: Arch Linux 6.15.1  
> Shell: zsh 5.9  
> Repo: [DeltaTask](https://github.com/JACKURUVI99/DeltaTask)

---

## 🛠️ How to Setup

### 1️⃣ Clone the Repo

```bash
git clone https://github.com/JACKURUVI99/DeltaTask.git
cd DeltaTask/DeltaTask/scripts
```

### 2️⃣ Install Required Tools

Make sure the following are installed:

- bash  
- yq (v4+)  
- setfacl  
- perl  
- mysql  

### 3️⃣ Configure Files

- `users.yaml` → All users and roles  
- `userpref.yaml` → Blog preferences per user  
- `subscriptions.yaml` → Author followings  
- MySQL database `blogdb` with username `root` and password `arch`

### 4️⃣ Run Setup Scripts

```bash
sudo ./setup.sh
sudo ./initusers.sh
```

---

## 📁 Directory Layout

user → `/home/users/<username>`  
    `all_blogs/`, `subscribed_blogs/`, `notifications.log`

author → `/home/authors/<author>`  
    `blogs/`, `public/`, `subscribers_only/`

moderator → `/home/mods/<mod>`  
    `blacklist.txt`, author symlinks

system → `/scripts`  
    All logic and YAML configs

reports → `/scripts/reports`  
    Admin-generated reports

---

## 📜 Scripts and Usage

### 🔑 initusers.sh

user → Create users, set up home, permissions  
use → `sudo ./initusers.sh`

### ✍️ manageblogs.sh

author → Manage blogs: create, publish, archive, delete, edit  
use → `./manageblogs.sh [option] <filename>`  
options → `-n` (new), `-p` (publish), `-a` (archive), `-d` (delete), `-e` (edit), `-s` (subscriber toggle), `-h` (help)

### 📂 manage_blogs_setup.sh

author → Setup folders and `blogs.yaml`  
use → `sudo ./manage_blogs_setup.sh`

### 👁️ mod_permission_setup.sh

moderator → Grant moderators access to all authors  
use → `sudo ./mod_permission_setup.sh`

### ❌ deleteusers.sh

admin → Delete non-protected users  
use → `sudo ./deleteusers.sh`

### 🔓 renuewusers.sh

admin → Unlock user accounts  
use → `sudo ./renuewusers.sh <username>`

### 🔐 permissions.sh

admin → Set directory ACLs and access  
use → `sudo ./permissions.sh`

### ⚙️ setup.sh

admin → Full system setup (groups, directories, perms)  
use → `sudo ./setup.sh`

### 🛡️ setup_author_permission.sh

admin → Set ACLs for author directories  
use → `sudo ./setup_author_permission.sh`

### 🤝 subscriptionmodel.sh

user → Subscribe/unsubscribe to authors  
use → `./subscriptionmodel.sh <authorname>`

### 📊 adminpanel.sh

admin → Generate blog activity reports  
use → `sudo ./adminpanel.sh`

### 🧱 adminpanel_setup.sh

admin → Setup reports folder  
use → `sudo ./adminpanel_setup.sh`

### ⛔ blacklist_setup.sh

moderator → Create `blacklist.txt` files  
use → `sudo ./blacklist_setup.sh`

### 🪪 blogfilter_setup.sh

moderator → Setup access to author blogs  
use → `sudo ./blogfilter_setup.sh`

### 🧹 blogfilter.sh

moderator → Censor blacklisted words in blogs  
use → `./blogfilter.sh <author_username>`

### 🎯 userFY.sh

admin → Personalized blog feed per user  
use → `sudo ./userFY.sh`

---

## 📘 Configuration Files

`users.yaml` → User roles and usernames  
`userpref.yaml` → Blog interest tags per user  
`subscriptions.yaml` → Maps users to followed authors  
`blogs.yaml` → Each author’s blog metadata

---

## 🔐 Notes

- MySQL password `arch` is hardcoded — replace with env variables for production
- Clean up duplicate subscriptions in `subscriptions.yaml` to avoid errors
- All features work offline (Netcat-based notifications, bash-only logic)

---

Happy blogging! 🚀  
For issues or contributions, contact the system administrator or raise a pull request in the GitHub repo.
