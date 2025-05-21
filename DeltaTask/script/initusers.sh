#!/bin/bash 
#set -euo pipefail

groupadd g_user
echo "group g_user created"
groupadd g_author
echo "group g_author created"
groupadd g_admin
echo "group g_admin created"
groupadd g_mods
echo "group g_mod created"

YAML_DIR="/home/harishannavisamy/Deltask/users.yaml"

echo "folders created for users,authors,mods,admins - in /home dir"

for user in $(yq ".users[] | .username" $YAML_DIR); do 
    useradd -m -d /home/users/$user $user 
    usermod -aG g_user $user
done
for admin in $(yq ".admins[] | .username" $YAML_DIR); do 
    useradd -m -d /home/admins/$admin $admin 
    usermod -aG g_admin $admin
done
for mod in $(yq ".mods[] | .username" $YAML_DIR); do 
    useradd -m -d /home/mods/$mod $mod 
    usermod -aG g_mods $mod
done
for author in $(yq ".authors[] | .username" $YAML_DIR);do 
    useradd -m -d /home/authors/$author $author
    usermod -aG g_author $author
done

n=0
while true; do 
    modeh=$(yq ".mods[$n]" "$YAML_DIR")
    
    if [[ "$modeh" == "null" ]]; then
        break
    fi

    mod_username=$(echo "$modeh" | yq ".username" | sed 's/"//g')

    for auth in $(echo "$modeh" | yq ".authors[]" | sed 's/"//g'); do 
        setfacl -R -m u:$mod_username:rwx /home/authors/$auth
        setfacl -d -m u:$mod_username:rwx /home/authors/$auth
        echo "Permission set successfully for $mod_username on /home/authors/$auth"
    done

    ((n++))
done

for admin in $(yq ".admins[] | .username" $YAML_DIR | sed 's/"//g'); do
    for user_dir in /home/users/*; do
        setfacl -R -m u:$admin:rwx "$user_dir"
        setfacl -d -m u:$admin:rwx "$user_dir"
    done
    for author_dir in /home/authors/*; do 
        setfacl -R -m u:$admin:rwx "$author_dir"
        setfacl -d -m u:$admin:rwx "$author_dir"
    done
    for mod_dir in /home/mods/*;do
        setfacl -R -m u:$admin:rwx "$mod_dir"
        setfacl -d -m u:$admin:rwx "$mod_dir"
    done
    echo "Full access given to admin $admin on /home/users and /home/authors and /home/mods"
done

for author_d in $(yq '.authors[] | .username ' "$YAML_DIR" | sed 's/"//g');do
    mkdir -p /home/authors/$author_d/public
    chown $author_d:g_author /home/authors/$author_d/public
    mkdir -p /home/authors/$author_d/blogs
    chown $author_d:g_author /home/authors/$author_d/blogs
    chmod 750 /home/authors/$author_d/blogs

    BLOGS_YAML="/home/authors/$author_d/blogs.yaml"
    if [ ! -f "$BLOGS_YAML" ]; then
        cat > "$BLOGS_YAML" <<EOF
categories:
  1: "Sports"
  2: "Cinema"
  3: "Technology"
  4: "Travel"
  5: "Food"
  6: "Lifestyle"
  7: "Finance"

blogs:
  - file_name: "blog.txt"
    publish_status: true
    cat_order: [2,1,3]
EOF
        chown $author_d:g_author "$BLOGS_YAML"
        chmod 644 "$BLOGS_YAML"
        echo "Created blogs.yaml for $author_d"
    fi
done 

for user_d in $(yq '.users[] | .username' "$YAML_DIR" |sed 's/"//g');do
    mkdir -p /home/users/$user_d/all_blogs
    chown $user_d:g_user /home/users/$user_d/all_blogs

    for auth_sym  in $(yq '.authors[] | .username' "$YAML_DIR" | sed 's/"//g');do
        ln -sf /home/authors/$auth_sym/public /home/users/$user_d/all_blogs/$auth_sym
    done
done
#
for user in $(yq '.users[]  | .username' "$YAML_DIR" |sed 's/"//g');do
    for author in $(yq '.authors[] | .username' "$YAML_DIR" | sed 's/"//g');do
        setfacl -m u:$user:rx /home/authors/$author/public
        setfacl -d -m u:$user:rx /home/authors/$author/public
    done 
done

current_yaml_authors=$(yq '.authors[] | .username' "$YAML_DIR" | sed 's/"//g')
for author_dir in /home/authors/*; do
    author=$(basename "$author_dir")
    if ! echo "$current_yaml_authors" | grep -q "^$author$"; then
        echo "Revoking ACLs for removed author $author"
        setfacl --remove-all /home/authors/$author 2>/dev/null
    fi
done

current_yaml_users=$(yq '.users[] | .username' "$YAML_DIR" | sed 's/"//g')
for user_dir in /home/users/*; do
    user=$(basename "$user_dir")
    if ! echo "$current_yaml_users" | grep -q "^$user$"; then
        echo "Revoking ACLs for removed user $user"
        setfacl --remove-all /home/users/$user 2>/dev/null
    fi
done

for mod_entry in $(seq 0 $(($(yq '.mods | length' "$YAML_DIR") - 1))); do
    mod_username=$(yq ".mods[$mod_entry].username" "$YAML_DIR" | sed 's/"//g')
    mod_authors_dir="/home/mods/$mod_username/all_authors"

    mkdir -p "$mod_authors_dir"
    
    # Remove old symlinks
    find "$mod_authors_dir" -type l -delete

    # Recreate symlinks for current authors
    for author in $(yq ".mods[$mod_entry].authors[]" "$YAML_DIR" | sed 's/"//g'); do
        target="/home/authors/$author/public"
        link="$mod_authors_dir/$author"

        if [ -d "$target" ]; then
            ln -s "$target" "$link"
        fi
    done
done

for admin in $(yq ".admins[].username" "$YAML_DIR" | sed 's/"//g'); do
    for path in /home/users/* /home/authors/* /home/mods/*; do
        [ -d "$path" ] || continue
        setfacl -R -m u:$admin:rwx "$path"
        setfacl -d -m u:$admin:rwx "$path"
    done
done
