#!/bin/bash

# Author: Hatim Makki Hoho
# Date: 2024-1-11, first release at 2024-1-11 11:11:11 AM
# Description: This script is used to find and delete unused static files in a project.
# Usage: ./cleanup.sh -e "png,jpg" -s "html,js,css" -l "static/assets" -i "venv,node_modules" -d


# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_usage() {
    echo "Usage: $0 [options]"
    echo
    echo "Required:"
    echo "  -e EXTENSIONS        File extensions to check (comma-separated)"
    echo "  -s SEARCH_IN        File extensions to search in (comma-separated)"
    echo
    echo "Optional:"
    echo "  -l LOCATION         Location to search in (default: current directory)"
    echo "  -i IGNORE           Folders to ignore (comma-separated)"

    echo "  -if IGNORE_FILES    Files to never mark as unused (comma-separated)"

    echo "  -d                  Dry run - don't actually delete files"
    echo "  -v                  Verbose output"
    echo
    echo "Example:"
    echo "  $0 -e \"png,jpg\" -s \"html,js,css\" -l \"static/assets\" -i \"venv,node_modules\" -if \"package.json\" -d"
    exit 1
}

format_size() {
    local size=$1
    if [ $size -gt 1073741824 ]; then
        echo "$(bc <<< "scale=2; $size/1073741824")GB"
    elif [ $size -gt 1048576 ]; then
        echo "$(bc <<< "scale=2; $size/1048576")MB"
    elif [ $size -gt 1024 ]; then
        echo "$(bc <<< "scale=2; $size/1024")KB"
    else
        echo "${size}B"
    fi
}

# Initialize variables
CHECK_EXTENSIONS=""
SEARCH_EXTENSIONS=""
SEARCH_LOCATION="."
IGNORE_FOLDERS=""
IGNORE_FILES=""
DRY_RUN=false
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e)
            CHECK_EXTENSIONS="${2//\"/}"
            shift 2
            ;;
        -s)
            SEARCH_EXTENSIONS="${2//\"/}"
            shift 2
            ;;
        -l)
            SEARCH_LOCATION="${2//\"/}"
            shift 2
            ;;
        -i)
            IGNORE_FOLDERS="${2//\"/}"
            shift 2
            ;;

        -if)
            IGNORE_FILES="${2//\"/}"
            shift 2
            ;;
        -d)
            DRY_RUN=true
            shift
            ;;
        -v)
            VERBOSE=true
            shift
            ;;
        *)
            echo -e "${RED}Error: Unknown parameter: $1${NC}"
            print_usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$CHECK_EXTENSIONS" ] || [ -z "$SEARCH_EXTENSIONS" ]; then
    echo -e "${RED}Error: Missing required arguments${NC}"
    print_usage
fi

# Convert extensions to arrays
IFS=',' read -ra CHECK_EXT_ARRAY <<< "$CHECK_EXTENSIONS"
IFS=',' read -ra SEARCH_EXT_ARRAY <<< "$SEARCH_EXTENSIONS"
if [ ! -z "$IGNORE_FILES" ]; then
    IFS=',' read -ra IGNORE_FILES_ARRAY <<< "$IGNORE_FILES"
fi

# Convert relative paths to absolute paths
if [[ ! "$SEARCH_LOCATION" = /* ]]; then
    SEARCH_LOCATION="$(pwd)/$SEARCH_LOCATION"
fi

# Validate search location exists
if [ ! -d "$SEARCH_LOCATION" ]; then
    echo -e "${RED}Error: Search location '$SEARCH_LOCATION' not found${NC}"
    exit 1
fi

# Build exclude pattern for find command
EXCLUDE_PATTERN=""
if [ ! -z "$IGNORE_FOLDERS" ]; then
    IFS=',' read -ra IGNORE_ARRAY <<< "$IGNORE_FOLDERS"
    for folder in "${IGNORE_ARRAY[@]}"; do
        folder=$(echo "$folder" | sed 's/^ *//;s/ *$//')  # Trim whitespace
        if [ -z "$EXCLUDE_PATTERN" ]; then
            EXCLUDE_PATTERN="-not -path '*/$folder/*'"
        else
            EXCLUDE_PATTERN="$EXCLUDE_PATTERN -not -path '*/$folder/*'"
        fi
    done
fi

# Initialize counters
TOTAL_FILES=0
UNUSED_FILES=0
TOTAL_SIZE=0

echo -e "${GREEN}=== Static Files Cleaner ===${NC}"
echo "Checking files in: ${SEARCH_LOCATION}"
echo "Searching for references in: $(dirname "$SEARCH_LOCATION")"
echo "File types to check: ${CHECK_EXTENSIONS}"
echo "File types to search in: ${SEARCH_EXTENSIONS}"
if [ ! -z "$IGNORE_FOLDERS" ]; then
    echo "Ignoring folders: ${IGNORE_FOLDERS}"
fi
if [ ! -z "$IGNORE_FILES" ]; then
    echo "Ignoring files: ${IGNORE_FILES}"
fi

echo -e "Dry run: $([ "$DRY_RUN" = true ] && echo 'Yes' || echo 'No')\n"

# Create temporary file for content cache
TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

# Cache all searchable file content from entire project
echo -e "${YELLOW}Creating search cache...${NC}"
PROJECT_ROOT=$(dirname "$SEARCH_LOCATION")  # Get parent directory of static/assets
for ext in "${SEARCH_EXT_ARRAY[@]}"; do
    if [ "$VERBOSE" = true ]; then
        echo "Caching .$ext files..."
    fi
    eval "find \"$PROJECT_ROOT\" -type f -name \"*.$ext\" $EXCLUDE_PATTERN -exec cat {} \;" >> "$TEMP_FILE"
done

echo -e "\n${YELLOW}Finding and checking files...${NC}"
for ext in "${CHECK_EXT_ARRAY[@]}"; do
    while IFS= read -r file; do
        if [ ! -z "$file" ] && [ -f "$file" ]; then
            ((TOTAL_FILES++))
            filename=$(basename "$file")
            [ "$VERBOSE" = true ] && echo "Checking: $filename"
            
            SKIP=false
            if [ ! -z "$IGNORE_FILES" ]; then
                for ignore_file in "${IGNORE_FILES_ARRAY[@]}"; do
                    if [ "$filename" = "$ignore_file" ]; then
                        SKIP=true
                        [ "$VERBOSE" = true ] && echo -e "${GREEN}Skipping ignored file: $filename${NC}"
                        break
                    fi
                done
            fi

            if [ "$SKIP" = false ]; then

                # Check if the file is referenced anywhere
                if ! grep -q "$filename" "$TEMP_FILE"; then
                    if [[ "$OSTYPE" == "darwin"* ]]; then
                        size=$(stat -f %z "$file")
                    else
                        size=$(stat -c %s "$file")
                    fi
                    
                    ((UNUSED_FILES++))
                    ((TOTAL_SIZE+=size))
                    formatted_size=$(format_size $size)
                    
                    if [ "$DRY_RUN" = true ]; then
                        echo -e "${YELLOW}Would remove:${NC} $file ($formatted_size)"
                    else
                        echo -e "${RED}Removing:${NC} $file ($formatted_size)"
                        rm "$file"
                    fi
                elif [ "$VERBOSE" = true ]; then
                    echo -e "${GREEN}File is used${NC}"
                fi
            fi

        fi
    done < <(eval "find \"$SEARCH_LOCATION\" -type f -name \"*.$ext\" $EXCLUDE_PATTERN")
done

echo -e "\n${GREEN}=== Summary ===${NC}"
echo "Total files checked: $TOTAL_FILES"
echo "Unused files found: $UNUSED_FILES"
echo "Total space $([ "$DRY_RUN" = true ] && echo 'that would be' || echo '') recovered: $(format_size $TOTAL_SIZE)"

if [ "$DRY_RUN" = true ]; then
    echo -e "\n${YELLOW}Note: This was a dry run. No files were actually deleted.${NC}"
    echo "Run without -d flag to perform actual cleanup."
fi