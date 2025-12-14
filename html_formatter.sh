#!/bin/bash

INDENT_STRING="  "
VOID_ELEMENTS=(
    "area"
    "base"
    "br"
    "col"
    "embed"
    "hr"
    "img"
    "input"
    "link"
    "meta"
    "param"
    "source"
    "track"
    "wbr"
)

RAW_ELEMENTS=(
    "script"
    "style"
    "pre"
    "textarea"
)

# extract tag name from a tag string
# Ex: <div class="test"> -> div
#     </div> -> div
#     <br/> -> br
get_tag_name() {
    local tag="$1"
    # remove < and </ from the start
    local name="${tag#</}"
    name="${name#<}"
    # remove everything after the first space, > or /
    name="${name%% *}"
    name="${name%%>*}"
    name="${name%%/*}"
    # convert to lowercase for comparison
    echo "${name,,}"
}

# check if a tag is a void element
is_void_element() {
    local tag_name="$1"
    local elem
    for elem in "${VOID_ELEMENTS[@]}"; do
        if [[ "${tag_name,,}" == "$elem" ]]; then
            return 0  # true
        fi
    done
    return 1  # false
}

# check if a tag is a raw element (content should be preserved)
is_raw_element() {
    local tag_name="$1"
    local elem
    for elem in "${RAW_ELEMENTS[@]}"; do
        if [[ "${tag_name,,}" == "$elem" ]]; then
            return 0  # true
        fi
    done
    return 1  # false
}

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
    local in_raw_element=false
    local raw_tag_name=""

    # read file, normalize whitespace, put each tag on its own line, add empty echo to ensure the last line is processed
    { cat "$file"; } \
        | tr '\n\r' '  ' \
        | sed 's/>[[:space:]]*</>\n</g' \
        | sed 's/\([^>]\)</\1\n</g' \
        | { cat; printf '\n'; } \
        | while IFS= read -r line; do
            # skip empty lines
            [ -z "$line" ] && continue

            # trim whitespace
            line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [ -z "$line" ] && continue

            # if we're inside a raw element, check for closing tag
            if [[ "$in_raw_element" == true ]]; then
                if [[ "$line" =~ ^\</ ]] && [[ "$(get_tag_name "$line")" == "$raw_tag_name" ]]; then
                    # found closing tag
                    ((indent_level--))
                    [ $indent_level -lt 0 ] && indent_level=0
                    print_indent $indent_level
                    echo "$line"
                    in_raw_element=false
                    raw_tag_name=""
                else
                    # raw content - print with current indent
                    print_indent $indent_level
                    echo "$line"
                fi
                continue
            fi

            if [[ "$line" =~ ^\<![Dd][Oo][Cc][Tt][Yy][Pp][Ee] ]]; then
                # DOCTYPE - always print at indent level 0
                echo "$line"
            
            elif [[ "$line" =~ ^\<!\-\- ]]; then
                # HTML comment - print with current indent
                print_indent $indent_level
                echo "$line"
            
            # check if it's a closing tag
            elif [[ "$line" =~ ^\</ ]]; then
                # closing tag - decrease indent first
                ((indent_level--))
                [ $indent_level -lt 0 ] && indent_level=0
                print_indent $indent_level
                echo "$line"
            # check if it's an opening tag
            elif [[ "$line" =~ ^\< ]]; then
                # extract tag and any text after it
                local tag_part="${line%%>*}>"
                local text_part="${line#*>}"
                
                # print the tag
                print_indent $indent_level
                echo "$tag_part"
                
                # extract tag name
                local tag_name=$(get_tag_name "$tag_part")
                
                if [[ "$tag_part" =~ /\>$ ]]; then
                    # self-closing tag, don't increase indent
                    :
                elif is_void_element "$tag_name"; then
                    # void element, don't increase indent
                    :
                elif is_raw_element "$tag_name"; then
                    # raw element - increase indent and track state
                    ((indent_level++))
                    in_raw_element=true
                    raw_tag_name="$tag_name"
                else
                    # regular opening tag, increase indent
                    ((indent_level++))
                fi
                
                # print text content if any
                if [[ -n "$text_part" && ! "$tag_part" =~ /\>$ ]] && ! is_void_element "$tag_name"; then
                    text_part=$(echo "$text_part" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    [[ -n "$text_part" ]] && { print_indent $indent_level; echo "$text_part"; }
                fi
            else
                # text content
                print_indent $indent_level
                echo "$line"
            fi
        done
}

main "$@"