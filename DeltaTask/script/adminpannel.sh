#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

YQ="/usr/local/bin/yq"
REPORT_DIR="/scripts/reports"
AUTHORS_DIR="/home/authors"
USERS_DIR="/home/users"
ADMIN_GROUP="g_admin"

# Check admin group membership
if ! id -nG "$USER" | grep -qw "$ADMIN_GROUP"; then
    echo "Error: Only users in group '$ADMIN_GROUP' can run this script."
    exit 1
fi

mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/$(date +%s).yaml"

# Temporary file for intermediate data
tmpfile=$(mktemp)

# Initialize empty arrays
blogs=()
declare -A categories_count=()

# Collect blogs
for author_dir in "$AUTHORS_DIR"/*; do
    [[ -d "$author_dir" ]] || continue
    author=$(basename "$author_dir")
    blogs_file="$author_dir/blogs.yaml"
    [[ -f "$blogs_file" ]] || continue

    blog_count=$($YQ e '.blogs | length' "$blogs_file")

    for ((i=0; i<blog_count; i++)); do
        blog=$($YQ e ".blogs[$i]" "$blogs_file")
        file_name=$($YQ e ".blogs[$i].file_name" "$blogs_file")
        publish_status=$($YQ e ".blogs[$i].publish_status" "$blogs_file")
        cat_order_len=$($YQ e ".blogs[$i].cat_order | length" "$blogs_file")
        blog_path="$author/$file_name"

        # Count reads manually (no external tools)
        reads=0
        for log in "$USERS_DIR"/*/blog_reads.log; do
            [[ -f "$log" ]] || continue
            count=$(grep -cF "$blog_path" "$log" || echo 0)
            reads=$((reads + count))
        done

        # Gather tags and update category counts
        tags=()
        for ((j=0; j<cat_order_len; j++)); do
            idx=$($YQ e ".blogs[$i].cat_order[$j]" "$blogs_file")
            tag=$($YQ e ".categories[$idx]" "$blogs_file")
            tags+=("$tag")

            # Increment category count in Bash associative array
            ((categories_count["$tag"]++))
        done

        # Convert tags array to YAML array string
        tags_yaml=$(printf '  - "%s"\n' "${tags[@]}")

        # Construct the blog YAML fragment with extra fields
        blog_yaml=$(
            echo "$blog" | $YQ e ".reads = $reads | .cats = []" -
        )

        # Insert tags under .cats manually with sed (since yq does not easily insert arrays from strings)
        blog_yaml=$(echo "$blog_yaml" | sed "/cats:/a\\
$tags_yaml
")

        blogs+=("$blog_yaml")
    done
done

# Compose categories YAML block
categories_yaml=""
for cat in "${!categories_count[@]}"; do
    categories_yaml+="  \"$cat\": ${categories_count[$cat]}"$'\n'
done

# Compose blogs YAML block
blogs_yaml=$(printf '%s\n---\n' "${blogs[@]}")

# Write full YAML report with yq
{
echo "blogs:"
echo "$blogs_yaml" | sed '/^---$/d'  # remove --- separators between docs
echo "categories:"
echo "$categories_yaml"
} > "$tmpfile"

# Use yq to add total_published, total_deleted, and top_3 fields

$YQ e '
  .total_published = (.blogs | map(select(.publish_status == true)) | length) |
  .total_deleted = (.blogs | map(select(.publish_status == false)) | length) |
  .blogs = (.blogs | sort_by(.reads) | reverse) |
  .top_3 = (.blogs[0:3])
' "$tmpfile" > "$REPORT_FILE"

rm -f "$tmpfile"

chown "$USER:$ADMIN_GROUP" "$REPORT_FILE"
chmod 660 "$REPORT_FILE"

echo "✅ Report generated at: $REPORT_FILE"
