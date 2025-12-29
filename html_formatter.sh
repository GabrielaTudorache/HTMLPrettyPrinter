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
        echo "Usage: $0 <input_file> [stdout|inplace|newfile] [output_path]" >&2
        exit 1
    fi

    local file="$1"
    local output_mode="${2:-stdout}"  # default to stdout
    local output_file="${3:-}"

    if [ ! -f "$file" ]; then
        echo "Error: File '$file' not found" >&2
        exit 1
    fi

    if [[ "$output_mode" == "newfile" && -z "$output_file" ]]; then
        echo "Error: newfile mode requires an output path" >&2
        exit 1
    fi

    local indent_level=0
    local in_raw_element=false
    local raw_tag_name=""
    local output=""
    # tag stack for tracking open tags (stored as colon-separated string for subshell compatibility)
    local tag_stack=""

    # helper to push to stack
    stack_push() {
        if [[ -z "$tag_stack" ]]; then
            tag_stack="$1"
        else
            tag_stack="$tag_stack:$1"
        fi
    }

    # helper to pop from stack
    stack_pop() {
        local top="${tag_stack##*:}"
        if [[ "$tag_stack" == *:* ]]; then
            tag_stack="${tag_stack%:*}"
        else
            tag_stack=""
        fi
    }

    # helper to get top of stack
    stack_top() {
        echo "${tag_stack##*:}"
    }

    # helper to check if tag exists in stack
    stack_contains() {
        local needle="$1"
        [[ ":$tag_stack:" == *":$needle:"* ]]
    }

    # helper to check if stack is empty
    stack_empty() {
        [[ -z "$tag_stack" ]]
    }

    # read file, normalize whitespace, put each tag on its own line, add empty echo to ensure the last line is processed
    output=$({ cat "$file"; } \
        | tr '\n\r' '  ' \
        | sed 's/>[[:space:]]*</>\n</g' \
        | sed 's/\([^>]\)<\([a-zA-Z/!]\)/\1\n<\2/g' \
        | { cat; printf '\n'; printf 'EOF_MARKER\n'; } \
        | while IFS= read -r line; do
            # check for end marker to close remaining tags
            if [[ "$line" == "EOF_MARKER" ]]; then
                # close any remaining unclosed tags
                while ! stack_empty; do
                    local unclosed_tag=$(stack_top)
                    ((indent_level--))
                    [ $indent_level -lt 0 ] && indent_level=0
                    print_indent $indent_level
                    echo "</$unclosed_tag>"
                    echo "Warning: Auto-closing unclosed <$unclosed_tag> tag" >&2
                    stack_pop
                done
                continue
            fi

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
                    stack_pop
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
                local tag_name=$(get_tag_name "$line")
                
                # check if this closing tag has a matching opening tag
                if stack_contains "$tag_name"; then
                    # close any mismatched tags first
                    while ! stack_empty && [[ "$(stack_top)" != "$tag_name" ]]; do
                        local mismatched_tag=$(stack_top)
                        ((indent_level--))
                        [ $indent_level -lt 0 ] && indent_level=0
                        print_indent $indent_level
                        echo "</$mismatched_tag>"
                        echo "Warning: Auto-closing mismatched <$mismatched_tag> tag" >&2
                        stack_pop
                    done
                    
                    # now close the matching tag
                    ((indent_level--))
                    [ $indent_level -lt 0 ] && indent_level=0
                    print_indent $indent_level
                    echo "$line"
                    stack_pop
                else
                    # orphan closing tag - skip it and warn
                    echo "Warning: Removing orphan closing tag </$tag_name>" >&2
                fi
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
                
                if [[ "$tag_part" =~ /\>$ ]] || is_void_element "$tag_name"; then
                    # self-closing or void element - don't increase indent
                    :
                elif is_raw_element "$tag_name"; then
                    # raw element - increase indent and track state
                    ((indent_level++))
                    in_raw_element=true
                    raw_tag_name="$tag_name"
                    stack_push "$tag_name"
                else
                    # regular opening tag, increase indent and push to stack
                    ((indent_level++))
                    stack_push "$tag_name"
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
        done)

    # output the result based on mode
    case "$output_mode" in
        stdout)
            echo "$output"
            ;;
        inplace)
            echo "$output" > "$file"
            echo "Formatted output written to '$file'" >&2
            ;;
        newfile)
            echo "$output" > "$output_file"
            echo "Formatted output written to '$output_file'" >&2
            ;;
    esac
}

main "$@"