#!/bin/bash

BLOG_DIR="/home/for authors/DeltaTask"
PUBLIC_DIR="/home/public"
CATEGORIES=("Sports" "Cinema" "Technology" "Politics" "Travel")

YAML_FILE="$BLOG_DIR/blogs.yaml"

usage() {
    echo "Usage: $0 [-p|-a|-d|-e] <filename>"
    exit 1
}

if [ $# -ne 2 ]; then
    usage
fi

COMMAND=$1
FILENAME=$2
