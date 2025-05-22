#!/bin/bash

ACTION=$1
FILENAME=$2
AUTHOR=$(whoami)
BLOGS_DIR="/home/authors/$AUTHOR/blogs"
PUBLIC_DIR="/home/authors/$AUTHOR/public"
YAML_FILE="/home/authors/$AUTHOR/blogs.yaml"
publish_article() {
    echo "Enter category preferences (e.g., 2,1 for Cinema and Sports):"
    read -r categories
    mkdir -p "$BLOGS_DIR"
    mkdir -p "$PUBLIC_DIR"
    if [[ ! -f "$BLOGS_DIR/$FILENAME" ]]; then
        echo "Blog file not found in $BLOGS_DIR"
        exit 1
    fi
    ln -s "$BLOGS_DIR/$FILENAME" "$PUBLIC_DIR/$FILENAME"
    yq eval ".blogs += [{name: \"$FILENAME\", status: \"published\", categories: [$categories]}]" -i "$YAML_FILE"
    chmod o+r "$BLOGS_DIR/$FILENAME"
    setfacl -m u::r-- "$BLOGS_DIR/$FILENAME"
    setfacl -m o::r-- "$BLOGS_DIR/$FILENAME"
    echo "Blog '$FILENAME' published successfully."
}
archive_article() {
    rm -f "$PUBLIC_DIR/$FILENAME"
    yq eval "(.blogs[] | select(.name == \"$FILENAME\") ).status = \"archived\"" -i "$YAML_FILE"
    setfacl -x o "$BLOGS_DIR/$FILENAME"
    chmod o-r "$BLOGS_DIR/$FILENAME"
    echo "Blog '$FILENAME' archived successfully."
}
delete_article() {
    rm -f "$PUBLIC_DIR/$FILENAME"
    rm -f "$BLOGS_DIR/$FILENAME"
    yq eval "del(.blogs[] | select(.name == \"$FILENAME\"))" -i "$YAML_FILE"
    echo "Blog '$FILENAME' deleted successfully."
}
edit_article() {
    echo "Enter new category preferences (e.g., 3,1):"
    read -r new_categories
    yq eval "(.blogs[] | select(.name == \"$FILENAME\")).categories = [$new_categories]" -i "$YAML_FILE"
    echo "Blog '$FILENAME' categories updated."
}
case "$ACTION" in
    -p)
        publish_article
        ;;
    -a)
        archive_article
        ;;
    -d)
        delete_article
        ;;
    -e)
        edit_article
        ;;
    *)
        echo "Usage: $0 -p|-a|-d|-e <filename>"
        ;;
esac
