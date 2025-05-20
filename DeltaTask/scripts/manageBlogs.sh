#!/bin/bash
blog_folder="/home/for authors/DeltaTask"
public_folder="/home/public"
yaml_file="$blog_folder/blogs.yaml"
categories="Sports Cinema Technology Politics Travel"

show_help() {
    echo "This script helps manage blog articles."
    echo ""
    echo "Options:"
    echo "  -p <file>  Put article on website"
    echo "  -a <file>  Move article to storage"
    echo "  -d <file>  Remove article completely"
    echo "  -e <file>  Change article topics"
    exit 1
}
if [ $# -ne 2 ]; then
    show_help
fi
action=$1
filename=$2
find_article() {
    find "$blog_folder" -type f -name "$filename" | grep -v "blogs.yaml"
}
get_topics() {
    echo "Choose topics for this article (enter numbers separated by commas):"
    i=1
    for topic in $categories; do
        echo "$i. $topic"
        i=$((i+1))
    done
    read -p "Your choices (example: 2,1): " choices
    
    selected_topics=""
    for num in $(echo $choices | tr ',' ' '); do
        counter=1
        for topic in $categories; do
            if [ $counter -eq $num ]; then
                selected_topics="$selected_topics \"$topic\""
                break
            fi
            counter=$((counter+1))
        done
    done
    echo $selected_topics
}
publish_article() {
    article_location=$(find_article)
    if [ ! -f "$article_location" ]; then
        echo "Couldn't find that article!"
        exit 1
    fi
    chosen_topics=$(get_topics)
    ln -sf "$article_location" "$public_folder/$filename"
    chmod o+r "$article_location"
    if grep -q "filename: \"$filename\"" "$yaml_file"; then
        sed -i "/filename: \"$filename\"/ {n; s/status:.*/status: \"published\"/}" "$yaml_file"
        sed -i "/filename: \"$filename\"/ {n;n; s/categories:.*/categories: [$chosen_topics]/}" "$yaml_file"
    else
        echo "- filename: \"$filename\"" >> "$yaml_file"
        echo "  status: \"published\"" >> "$yaml_file"
        echo "  categories: [$chosen_topics]" >> "$yaml_file"
    fi
    echo "Success! '$filename' is now live with topics: $chosen_topics"
}
archive_article() {
    rm -f "$public_folder/$filename"
    article_location=$(find_article)
    if [ ! -f "$article_location" ]; then
        echo "Couldn't find that article!"
        exit 1
    fi
    chmod o-r "$article_location"
    sed -i "/filename: \"$filename\"/ {n; s/status:.*/status: \"archived\"/}" "$yaml_file"
    echo "Moved '$filename' to storage"
}
delete_article() {
    rm -f "$public_folder/$filename"
    article_location=$(find_article)
    if [ -f "$article_location" ]; then
        rm "$article_location"
    fi
    sed -i "/filename: \"$filename\"/d" "$yaml_file"
    echo "Removed '$filename' permanently"
}
change_topics() {
    article_location=$(find_article)
    if [ ! -f "$article_location" ]; then
        echo "Couldn't find that article!"
        exit 1
    fi
    new_topics=$(get_topics)
    sed -i "/filename: \"$filename\"/ {n;n; s/categories:.*/categories: [$new_topics]/}" "$yaml_file"
    echo "Updated topics for '$filename'"
}
case "$action" in
    -p) publish_article ;;
    -a) archive_article ;;
    -d) delete_article ;;
    -e) change_topics ;;
    *) show_help ;;
esac
