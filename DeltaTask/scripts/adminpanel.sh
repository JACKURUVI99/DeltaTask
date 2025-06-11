#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

YQ="/usr/local/bin/yq"
REPORT_DIR="/scripts/reports"
AUTHORS_DIR="/home/authors"
USERS_DIR="/home/users"
ADMIN_GROUP="g_admin"

# make shure only users in g_admin can run
if ! id -nG "$USER" | grep -qw "$ADMIN_GROUP"; then
    echo "Error: Only users in group '$ADMIN_GROUP' can run this script."
    exit 1
fi

mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/$(date +%s).yaml"
tmpfile=$(mktemp)
declare -a blogs=()
declare -A categories_count=()

for author_dir in "$AUTHORS_DIR"/*; do
    [[ -d "$author_dir" ]] || continue
    author=$(basename "$author_dir")
    blogs_file="$author_dir/blogs.yaml"
    [[ -f "$blogs_file" ]] || continue

    blog_count=$($YQ e '.blogs | length' "$blogs_file" 2>/dev/null || echo 0)
    (( blog_count > 0 )) || continue

    for ((i=0; i<blog_count; i++)); do
        file=$($YQ e ".blogs[$i].file_name" "$blogs_file" || echo "")
        [[ -n "$file" ]] || continue

        blog_path="$author/$file"
        reads=0

        for log in "$USERS_DIR"/*/blog_reads.log; do
            [[ -f "$log" ]] && (( reads += $(grep -cF "$blog_path" "$log" || echo 0) ))
        done

        cat_len=$($YQ e ".blogs[$i].cat_order | length" "$blogs_file" || echo 0)
        tags=()

        for ((j=0; j<cat_len; j++)); do
            idx=$($YQ e ".blogs[$i].cat_order[$j]" "$blogs_file")
            tag=$($YQ e ".categories[$idx]" "$blogs_file")
            tags+=("$tag")
            ((categories_count["$tag"]++))
        done

        tag_yaml=$(printf '  - "%s"\n' "${tags[@]}")
        blog=$($YQ e ".blogs[$i]" "$blogs_file")
        blog_yaml=$(echo "$blog" | $YQ e ".reads = $reads | .cats = []" -)
        blog_yaml=$(echo "$blog_yaml" | sed "/cats:/a\\
$tag_yaml
")
        blogs+=("$blog_yaml")
    done
done

if [[ ${#blogs[@]} -eq 0 ]]; then
    echo "No valid blogs found. Exiting."
    rm -f "$tmpfile"
    exit 0
fi

{
    echo "blogs:"
    printf '%s\n' "${blogs[@]}"
    echo "categories:"
    for c in "${!categories_count[@]}"; do
        echo "  \"$c\": ${categories_count[$c]}"
    done
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

echo "Report generated: $REPORT_FILE"
