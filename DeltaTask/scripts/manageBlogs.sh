#!/bin/bash

# Set variables
BLOG_DIR="/home/for authors/DeltaTask"
PUBLIC_DIR="/home/public"
YAML_FILE="$BLOG_DIR/blogs.yaml"
CATEGORIES=("Sports" "Cinema" "Technology" "Politics" "Travel")

# Function to show usage
usage() {
    echo "Usage: $0 [-p|-a|-d|-e] <filename>"
    echo "  -p   Publish an article"
    echo "  -a   Archive an article"
    echo "  -d   Delete an article"
    echo "  -e   Edit an article's categories"
    exit 1
}

# Ensure correct arguments
if [ $# -ne 2 ]; then
    usage
fi

COMMAND=$1
FILENAME=$2

# Function to find article path
find_article() {
    find "$BLOG_DIR" -type f -name "$FILENAME" 2>/dev/null | grep -v "blogs.yaml"
}

# Function to prompt category selection
prompt_categories() {
    echo "Select categories by number (comma-separated):"
    for i in "${!CATEGORIES[@]}"; do
        echo "$((i+1)). ${CATEGORIES[$i]}"
    done
    read -p "Enter category numbers (e.g., 2,1): " category_input

    IFS=',' read -ra CATEGORY_ORDER <<< "$category_input"
    SELECTED_CATEGORIES=()
    for index in "${CATEGORY_ORDER[@]}"; do
        SELECTED_CATEGORIES+=("\"${CATEGORIES[$((index-1))]}\"")
    done
    echo "${SELECTED_CATEGORIES[@]}"
}

# Publish article
publish_article() {
    ARTICLE_PATH=$(find_article)
    [ ! -f "$ARTICLE_PATH" ] && echo "❌ Article not found!" && exit 1

    SELECTED=$(prompt_categories)
    ln -sf "$ARTICLE_PATH" "$PUBLIC_DIR/$FILENAME"
    chmod o+r "$ARTICLE_PATH"

    # Add or update in YAML
    if yq e ".articles[] | select(.filename == \"$FILENAME\")" "$YAML_FILE" >/dev/null; then
        yq e "(.articles[] | select(.filename == \"$FILENAME\")).status = \"published\"" -i "$YAML_FILE"
        yq e "(.articles[] | select(.filename == \"$FILENAME\")).categories = [${SELECTED}]" -i "$YAML_FILE"
    else
        yq e ".articles += [{filename: \"$FILENAME\", status: \"published\", categories: [${SELECTED}]}]" -i "$YAML_FILE"
    fi

    echo "✅ Published '$FILENAME' with categories: ${SELECTED[*]}"
}

# Archive article
archive_article() {
    rm -f "$PUBLIC_DIR/$FILENAME"
    ARTICLE_PATH=$(find_article)
    [ ! -f "$ARTICLE_PATH" ] && echo "❌ Article not found!" && exit 1
    chmod o-r "$ARTICLE_PATH"

    yq e "(.articles[] | select(.filename == \"$FILENAME\")).status = \"archived\"" -i "$YAML_FILE"
    echo "📦 Archived '$FILENAME'"
}

# Delete article
delete_article() {
    rm -f "$PUBLIC_DIR/$FILENAME"
    ARTICLE_PATH=$(find_article)
    [ -f "$ARTICLE_PATH" ] && rm "$ARTICLE_PATH"

    yq e "del(.articles[] | select(.filename == \"$FILENAME\"))" -i "$YAML_FILE"
    echo "🗑️ Deleted '$FILENAME' completely"
}

# Edit categories
edit_categories() {
    ARTICLE_PATH=$(find_article)
    [ ! -f "$ARTICLE_PATH" ] && echo "❌ Article not found!" && exit 1

    NEW_CATEGORIES=$(prompt_categories)
    yq e "(.articles[] | select(.filename == \"$FILENAME\")).categories = [${NEW_CATEGORIES}]" -i "$YAML_FILE"
    echo "✏️ Updated categories for '$FILENAME'"
}

# Dispatcher
case "$COMMAND" in
    -p) publish_article ;;
    -a) archive_article ;;
    -d) delete_article ;;
    -e) edit_categories ;;
    *) usage ;;
esac
