#!/bin/bash

INDENT_STRING="  "

# function to print indentation
print_indent() {
    local level=$1
    local i
    for ((i=0; i<level; i++)); do
        printf "%s" "$INDENT_STRING"
    done
}

main() {
    if [ $# -lt 1 ]; then
        echo "Usage: $0 <html_file>" >&2
        exit 1
    fi

    local file="$1"

    if [ ! -f "$file" ]; then
        echo "Error: File '$file' not found" >&2
        exit 1
    fi

    local indent_level=0

    # read file, normalize whitespace, put each tag on its own line
    cat "$file" \
        | tr '\n\r' '  ' \
        | sed 's/>[[:space:]]*</>\n</g' \
        | sed 's/>\([^<]\)/>\n\1/g' \
        | sed 's/\([^>]\)</\1\n</g' \
        | while IFS= read -r line; do
            # skip empty lines
            [ -z "$line" ] && continue

            # trim whitespace
            line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [ -z "$line" ] && continue

            # check if it's a closing tag
            if [[ "$line" =~ ^\</ ]]; then
                # closing tag - decrease indent first
                ((indent_level--))
                [ $indent_level -lt 0 ] && indent_level=0
                print_indent $indent_level
                echo "$line"
            # check if it's an opening tag
            elif [[ "$line" =~ ^\< ]]; then
                # opening tag - print then increase indent
                print_indent $indent_level
                echo "$line"
                ((indent_level++))
            else
                # text content
                print_indent $indent_level
                echo "$line"
            fi
        done
}

main "$@"