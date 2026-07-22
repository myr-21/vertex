#!/usr/bin/env bash

# Print tabular data from standard input or arguments
# Format: column separator is tab or pipe
print_table() {
    local header="$1"
    shift
    local rows=("$@")

    # Header columns
    IFS=$'\t' read -r -a headers <<< "$header"
    
    # Calculate column widths
    local widths=()
    for col in "${headers[@]}"; do
        widths+=(${#col})
    done

    # Parse rows to find max width per column
    local parsed_rows=()
    for row in "${rows[@]}"; do
        IFS=$'\t' read -r -a cells <<< "$row"
        parsed_rows+=("$row")
        for i in "${!cells[@]}"; do
            local cell_len=${#cells[$i]}
            if [[ -z "${widths[$i]}" ]] || (( cell_len > widths[$i] )); then
                widths[$i]=$cell_len
            fi
        done
    done

    # Build format string
    local fmt=""
    for w in "${widths[@]}"; do
        fmt+="\033[1m%-$(($w + 3))s\033[0m"
    done
    fmt+="\n"

    # Print header
    printf "$fmt" "${headers[@]}"
    
    # Print separator line
    local sep=""
    for w in "${widths[@]}"; do
        for ((i=0; i<w+3; i++)); do sep+="-"; done
    done
    echo "$sep"

    # Build row format string (non-bold)
    local row_fmt=""
    for w in "${widths[@]}"; do
        row_fmt+="%-$(($w + 3))s"
    done
    row_fmt+="\n"

    # Print rows
    for row in "${parsed_rows[@]}"; do
        IFS=$'\t' read -r -a cells <<< "$row"
        printf "$row_fmt" "${cells[@]}"
    done
}
