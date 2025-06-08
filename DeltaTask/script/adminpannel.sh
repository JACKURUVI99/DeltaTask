#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

YQ="/usr/local/bin/yq"
JQ="/usr/bin/jq"  # assuming jq is installed; required to handle arrays cleanly

REPORT_DIR="/home/harishannavisamy/new_Deltask/scripts/reports"
mkdir -p "$REPORT_DIR"
REPORT_OUTPUT_PATH="$REPORT_DIR/$(date +%s).yaml"
touch "$REPORT_OUTPUT_PATH"

AUTHORS_DIR="/home/authors"
TMP_BLOG=$(mktemp)

# Initialize report.yaml
$YQ e -n '.blogs = [] | .categories = {} | .total_published = 0 | .total_deleted = 0' > "$REPORT_OUTPUT_PATH"

for author in $(ls "$AUTHORS_DIR"); do
    blogs_data_file="$AUTHORS_DIR/$author/blogs.yaml"
    [[ -f "$blogs_data_file" ]] || continue

    blog_count=$($YQ e '.blogs | length' "$blogs_data_file")
    for ((i=0; i<blog_count; i++)); do
        file_name=$($YQ e ".blogs[$i].file_name" "$blogs_data_file")
        publish_status=$($YQ e ".blogs[$i].publish_status" "$blogs_data_file")
        blogpath="$author/$file_name"

        # Count reads from all users
        reads=0
        for log in /home/users/*/blog_reads.log; do
            [[ -f "$log" ]] || continue
            ((reads += $(grep -cF "$blogpath" "$log" || echo 0)))
        done

        # Get categories
        cat_order_len=$($YQ e ".blogs[$i].cat_order | length" "$blogs_data_file")
        cats_yaml=""
        for ((j=0; j<cat_order_len; j++)); do
            index=$($YQ e ".blogs[$i].cat_order[$j]" "$blogs_data_file")
            name=$($YQ e ".categories[$index]" "$blogs_data_file")
            cats_yaml+=$'\n- '"$name"

            # Increment category count in report
            count=$($YQ e ".categories.\"$name\" // 0" "$REPORT_OUTPUT_PATH")
            ((count++))
            $YQ e -i ".categories.\"$name\" = $count" "$REPORT_OUTPUT_PATH"
        done

        # Extract full blog object, inject reads and cats
        $YQ e ".blogs[$i]" "$blogs_data_file" > "$TMP_BLOG"
        echo "reads: $reads" >> "$TMP_BLOG"
        echo "cats: [$(
            echo "$cats_yaml" | sed '/^$/d' | sed 's/^ *- */"/;s/$/"/' | paste -sd ',' -
        )]" >> "$TMP_BLOG"

        # Append updated blog to report
        $YQ e -i ".blogs += [load(\"$TMP_BLOG\")]" "$REPORT_OUTPUT_PATH"
    done
done

# Sort blogs by reads descending
$YQ e -i '.blogs |= sort_by(.reads) | .blogs |= reverse' "$REPORT_OUTPUT_PATH"

# Count published/deleted
published=$($YQ e '[.blogs[] | select(.publish_status == true)] | length' "$REPORT_OUTPUT_PATH")
deleted=$($YQ e '[.blogs[] | select(.publish_status == false)] | length' "$REPORT_OUTPUT_PATH")
$YQ e -i ".total_published = $published | .total_deleted = $deleted" "$REPORT_OUTPUT_PATH"

rm "$TMP_BLOG"
echo "✅ Report generated: $REPORT_OUTPUT_PATH"
