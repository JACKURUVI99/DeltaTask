#!/bin/bash

HELP_FILE="../blog.txt"

author=$(whoami)
blogname="$2"
blogpath="/home/authors/$author/blogs/$blogname"
blogs_data_file="/home/authors/$author/blogs.yaml"

mysql_command=""
mysql_comment=""

function init_blogs_yaml() {
    if [[ ! -f "$blogs_data_file" ]]; then
        cat <<EOF > "$blogs_data_file"
categories:
    1: "Sports"
    2: "Cinema"
    3: "Technology"
    4: "Travel"
    5: "Food"
    6: "Lifestyle"
    7: "Finance"
blogs: []
EOF
        echo "Initialized $blogs_data_file"
    fi

    # Add categories if missing
    if [[ "$(yq '.categories' "$blogs_data_file")" == "null" ]]; then
        echo "🛠️ Adding missing categories to $blogs_data_file"
        yq -i '
          .categories = {
            "1": "Sports",
            "2": "Cinema",
            "3": "Technology",
            "4": "Travel",
            "5": "Food",
            "6": "Lifestyle",
            "7": "Finance"
          }
        ' "$blogs_data_file"
    fi
}

function help() {
    cat "$HELP_FILE"
}

function notify_subs() {
    echo -e "$author\n$blogname" | nc localhost 3000 -q 2 -w 2
    if [[ $? == 0 ]]; then
        echo "Subscribers notified"
    else
        echo "Failed to send notifications"
    fi
}

function print_categories() {
    echo "Provide categories order separated by spaces like '1 2 3'. Possible categories are:"
    i=1
    while true; do
        cat_value=$(yq ".categories.$i" "$blogs_data_file")
        if [[ "$cat_value" == "null" ]]; then break; fi
        echo "$i. $cat_value"
        ((i++))
    done
}

function new() {
    if [[ -e "$blogpath" ]]; then
        echo "File already exists"
    else
        touch "$blogpath"
        echo "Created file"
    fi

    if [[ -z $(yq ".blogs[] | select(.file_name == \"$blogname\")" "$blogs_data_file") ]]; then
        yq -i ".blogs += [{\"file_name\": \"$blogname\", \"publish_status\": false, \"cat_order\": []}]" "$blogs_data_file"
        echo "Entry created"
    else
        echo "Entry already exists"
    fi

    mysql_command="INSERT INTO blogs(name, author) VALUES('$blogname', '$author');"
    mysql_comment="Inserting blog record"
}

function publish() {
    print_categories
    read -a categories
    for i in "${categories[@]}"; do
        if [[ "$(yq ".categories.$i" "$blogs_data_file")" == "null" ]]; then
            echo "Invalid category index: $i"
            exit 1
        fi
    done
    joined_categories=$(IFS=','; echo "[${categories[*]}]")

    if [[ -z $(yq ".blogs[] | select(.file_name == \"$blogname\")" "$blogs_data_file") ]]; then
        new
    fi

    blog_filter="(.blogs[] | select(.file_name == \"$blogname\"))"
    yq -i "$blog_filter.publish_status = true | $blog_filter.cat_order = $joined_categories | del($blog_filter.mod_comment)" "$blogs_data_file"

    setfacl -R -m "g:g_users:r" "$blogpath"

    sub_status=$(yq "$blog_filter.subscribers_only" "$blogs_data_file")

    if [[ "$sub_status" == "true" ]]; then
        ln -sf "$blogpath" "/home/authors/$author/subscribers_only/$blogname"
        setfacl -R -m "g:g_${author}_subs:r" "$blogpath"
        notify_subs
    else
        ln -sf "$blogpath" "/home/authors/$author/public/$blogname"
        setfacl -R -x "g:g_${author}_subs" "$blogpath"
    fi

    echo "Published"

    mysql_command="UPDATE blogs SET categories='${categories[*]}', is_published=true WHERE name='$blogname' AND author='$author';"
    mysql_comment="Updating blog to published"
}

function archive() {
    setfacl -R -x "g:g_users" "$blogpath"
    yq -i "(.blogs[] | select(.file_name == \"$blogname\")).publish_status = false" "$blogs_data_file"
    unlink "/home/authors/$author/public/$blogname" 2>/dev/null
    unlink "/home/authors/$author/subscribers_only/$blogname" 2>/dev/null
    setfacl -R -x "g:g_${author}_subs" "$blogpath"
    echo "Archived"

    mysql_command="UPDATE blogs SET is_published=false WHERE name='$blogname' AND author='$author';"
    mysql_comment="Archiving blog"
}

function delete() {
    yq -i "del(.blogs[] | select(.file_name == \"$blogname\"))" "$blogs_data_file"
    unlink "/home/authors/$author/public/$blogname" 2>/dev/null
    unlink "/home/authors/$author/subscribers_only/$blogname" 2>/dev/null
    rm -f "$blogpath"
    echo "Deleted"

    mysql_command="DELETE FROM blogs WHERE name='$blogname' AND author='$author';"
    mysql_comment="Deleting blog record"
}

function edit_cat() {
    print_categories
    read -a categories
    for i in "${categories[@]}"; do
        if [[ "$(yq ".categories.$i" "$blogs_data_file")" == "null" ]]; then
            echo "Invalid category index: $i"
            exit 1
        fi
    done
    joined_categories=$(IFS=','; echo "[${categories[*]}]")

    yq -i "(.blogs[] | select(.file_name == \"$blogname\")).cat_order = $joined_categories" "$blogs_data_file"

    echo "Updated categories"

    mysql_command="UPDATE blogs SET categories='${categories[*]}' WHERE name='$blogname' AND author='$author';"
    mysql_comment="Updated blog categories"
}

function toggle_subs() {
    yq -i "(.blogs[] | select(.file_name == \"$blogname\")).subscribers_only |= (. | not)" "$blogs_data_file"

    blog=$(yq ".blogs[] | select(.file_name == \"$blogname\")" "$blogs_data_file")
    if [[ -z "$blog" ]]; then new; fi

    subs_status=$(echo "$blog" | yq ".subscribers_only")
    publish_status=$(echo "$blog" | yq ".publish_status")

    if [[ $subs_status == "true" ]]; then
        if [[ $publish_status == "true" ]]; then
            ln -sf "$blogpath" "/home/authors/$author/subscribers_only/$blogname"
            setfacl -R -m "g:g_${author}_subs:r" "$blogpath"
            notify_subs
        fi
        unlink "/home/authors/$author/public/$blogname" 2>/dev/null
    else
        if [[ $publish_status == "true" ]]; then
            ln -sf "$blogpath" "/home/authors/$author/public/$blogname"
        fi
        unlink "/home/authors/$author/subscribers_only/$blogname" 2>/dev/null
        setfacl -R -x "g:g_${author}_subs" "$blogpath"
    fi

    echo "Subscribers Only is set to $subs_status"

    mysql_command="UPDATE blogs SET is_subscribers_only=$subs_status WHERE name='$blogname' AND author='$author';"
    mysql_comment="Toggled subscribers-only status"
}

# Entry point
init_blogs_yaml

if [[ $1 == "-h" ]]; then
    help
    exit 0
fi

if [[ $1 == "-n" ]]; then
    new
else
    if [[ -z $blogname ]] || [[ ! -f $blogpath ]]; then
        echo "File does not exist"
        exit 1
    fi

    case $1 in
        -p) publish ;;
        -a) archive ;;
        -d) delete ;;
        -e) edit_cat ;;
        -s) toggle_subs ;;
        *) help ;;
    esac
fi

if [[ -n "$mysql_command" ]]; then
    mysql_command="USE blogdb; $mysql_command"
    echo "$mysql_comment"
    echo "$mysql_command"
    echo "$mysql_command" | mysql -h db -uroot -pkali
    if [[ $? -eq 0 ]]; then echo "SUCCESS"; else echo "FAILED"; fi
fi
