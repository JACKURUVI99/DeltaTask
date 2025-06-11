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
    echo "❌ Error: Only users in group '$ADMIN_GROUP' can run this script."
    exit 1
fi

mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/$(date +%s).yaml"
tmpfile=$(mktemp)

blogs=()
declare -A categories_count=()

echo "📦 Starting blog report generation..."

# Collect blogs
for author_dir in "$AUTHORS_DIR"/*; do
    [[ -d "$author_dir" ]] || continue
    author=$(basename "$author_dir")
    blogs_file="$author_dir/blogs.yaml"
    [[ -f "$blogs_file" ]] || {
        echo "⚠️  No blogs.yaml found for $author, skipping."
        continue
    }

    echo "🔍 Reading blogs for author: $author"

    blog_count=$($YQ e '.blogs | length' "$blogs_file" 2>/dev/null || echo 0)

    if [[ "$blog_count" -eq 0 ]]; then
        echo "⚠️  No blogs found for $author."
        continue
    fi

    for ((i=0; i<blog_count; i++)); do
        file_name=$($YQ e ".blogs[$i].file_name" "$blogs_file" 2>/dev/null || echo "")
        publish_status=$($YQ e ".blogs[$i].publish_status" "$blogs_file" 2>/dev/null || echo "false")
        cat_order_len=$($YQ e ".blogs[$i].cat_order | length" "$blogs_file" 2>/dev/null || echo 0)
        blog_path="$author/$file_name"

        if [[ -z "$file_name" ]]; then
            echo "⚠️  Skipping blog $i for $author: missing file_name."
            continue
        fi

        reads=0
        for log in "$USERS_DIR"/*/blog_reads.log; do
            [[ -f "$log" ]] || continue
            count=$(grep -cF "$blog_path" "$log" || echo 0)
            reads=$((reads + count))
        done

        tags=()
        for ((j=0; j<cat_order_len; j++)); do
            idx=$($YQ e ".blogs[$i].cat_order[$j]" "$blogs_file" || echo "0")
            tag=$($YQ e ".categories[$idx]" "$blogs_file" || echo "unknown")
            tags+=("$tag")
            ((categories_count["$tag"]++))
        done

        tags_yaml=$(printf '  - "%s"\n' "${tags[@]}")
        blog=$($YQ e ".blogs[$i]" "$blogs_file")
        blog_yaml=$(echo "$blog" | $YQ e ".reads = $reads | .cats = []" -)
        blog_yaml=$(echo "$blog_yaml" | sed "/cats:/a\\
$tags_yaml
")

        blogs+=("$blog_yaml")
        echo "✅ Processed blog: $file_name (Reads: $reads)"
    done
done

if [[ ${#blogs[@]} -eq 0 ]]; then
    echo "⚠️  No valid blogs found. Exiting."
    rm -f "$tmpfile"
    exit 0
fi

categories_yaml=""
for cat in "${!categories_count[@]}"; do
    categories_yaml+="  \"$cat\": ${categories_count[$cat]}"$'\n'
done

blogs_yaml=$(printf '%s\n---\n' "${blogs[@]}")

{
echo "blogs:"
echo "$blogs_yaml" | sed '/^---$/d'
echo "categories:"
echo "$categories_yaml"
} > "$tmpfile"

$YQ e '
  .total_published = (.blogs | map(select(.publish_status == true)) | length) |
  .total_deleted = (.blogs | map(select(.publish_status == false)) | length) |
  .blogs = (.blogs | sort_by(.reads) | reverse) |
  .top_3 = (.blogs[0:3])
' "$tmpfile" > "$REPORT_FILE"

rm -f "$tmpfile"

chown "$USER:$ADMIN_GROUP" "$REPORT_FILE"
chmod 660 "$REPORT_FILE"

echo "✅ Report generated successfully: $REPORT_FILE"
