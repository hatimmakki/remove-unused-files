#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Progress bar function
progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((percentage * width / 100))
    local empty=$((width - filled))
    
    printf "\rProgress: ["
    printf "%${filled}s" '' | tr ' ' '='
    printf "%${empty}s" '' | tr ' ' ' '
    printf "] %d%%" "$percentage"
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

print_usage() {
    echo "Usage: $0 [options]"
    echo
    echo "Required:"
    echo "  -s STATIC_DIR                    Static files directory path"
    echo "  -e EXTENSIONS                    File extensions to check (comma-separated)"
    echo
    echo "Optional:"
    echo "  searchExtensions \"EXTS\"          File extensions to search in (comma-separated)"
    echo "                                   Default: html,js,css,vue,jsx,tsx"
    echo "  excludeFolders \"FOLDERS\"         Folders to exclude (comma-separated)"
    echo "                                   Default: venv,node_modules,staticfiles,media"
    echo "  searchPath \"PATH\"                Path to search in"
    echo "                                   Default: current directory (.)"
    echo "  -d                               Dry run - don't actually delete files"
    echo "  -v                               Verbose output"
    echo
    echo "Example:"
    echo "  $0 -s static -e \"png,svg,jpg\" searchExtensions \"html,js,css\" excludeFolders \"venv,dist\" searchPath \".\" -d"
    exit 1
}

# Initialize variables
STATIC_PATH=""
EXTENSIONS=""
SEARCH_EXTENSIONS="html,js,css,vue,jsx,tsx"
EXCLUDE_FOLDERS="venv,node_modules,staticfiles,media"
SEARCH_PATH="."
DRY_RUN=false
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s)
            STATIC_PATH="$2"
            shift 2
            ;;
        -e)
            EXTENSIONS="$2"
            shift 2
            ;;
        searchExtensions)
            SEARCH_EXTENSIONS="${2//\"/}"  # Remove quotes if present
            shift 2
            ;;
        excludeFolders)
            EXCLUDE_FOLDERS="${2//\"/}"  # Remove quotes if present
            shift 2
            ;;
        searchPath)
            SEARCH_PATH="${2//\"/}"  # Remove quotes if present
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

# Convert relative paths to absolute paths
if [[ ! "$STATIC_PATH" = /* ]]; then
    STATIC_PATH="$(pwd)/$STATIC_PATH"
fi
if [[ ! "$SEARCH_PATH" = /* ]]; then
    SEARCH_PATH="$(pwd)/$SEARCH_PATH"
fi

# Validate required arguments
if [ -z "$STATIC_PATH" ] || [ -z "$EXTENSIONS" ]; then
    echo -e "${RED}Error: Missing required arguments${NC}"
    print_usage
fi

# Validate static directory exists
if [ ! -d "$STATIC_PATH" ]; then
    echo -e "${RED}Error: Static directory '$STATIC_PATH' not found${NC}"
    exit 1
fi

# Convert extensions and exclude patterns to array
IFS=',' read -ra EXT_ARRAY <<< "$EXTENSIONS"
IFS=',' read -ra SEARCH_EXT_ARRAY <<< "$SEARCH_EXTENSIONS"
IFS=',' read -ra EXCLUDE_ARRAY <<< "$EXCLUDE_FOLDERS"

# Build find command for source files
FIND_EXTENSIONS=""
for ext in "${SEARCH_EXT_ARRAY[@]}"; do
    if [ -z "$FIND_EXTENSIONS" ]; then
        FIND_EXTENSIONS="-name \"*.${ext}\""
    else
        FIND_EXTENSIONS="${FIND_EXTENSIONS} -o -name \"*.${ext}\""
    fi
done

# Build exclude pattern for find command
EXCLUDE_FIND=""
for pattern in "${EXCLUDE_ARRAY[@]}"; do
    EXCLUDE_FIND="$EXCLUDE_FIND -not -path '*/$pattern/*'"
done

# Initialize counters
TOTAL_FILES=0
UNUSED_FILES=0
TOTAL_SIZE=0

echo -e "${GREEN}=== Django Static Files Cleaner ===${NC}"
echo "Static directory: $STATIC_PATH"
echo "Search path: $SEARCH_PATH"
echo "Static extensions to check: ${EXTENSIONS}"
echo "File types to search in: ${SEARCH_EXTENSIONS}"
echo "Excluding folders: ${EXCLUDE_FOLDERS}"
echo -e "Dry run: $([ "$DRY_RUN" = true ] && echo 'Yes' || echo 'No')\n"

# Create temporary files
USED_FILES=$(mktemp)
trap 'rm -f $USED_FILES' EXIT

echo -e "${YELLOW}Finding files to scan...${NC}"
eval "SOURCE_FILES=\$(find \"$SEARCH_PATH\" \( ${FIND_EXTENSIONS} \) ${EXCLUDE_FIND})"
FILE_COUNT=$(echo "$SOURCE_FILES" | grep -c "^" || true)
echo -e "Found ${GREEN}$FILE_COUNT${NC} files to scan\n"

echo -e "${YELLOW}Scanning files for static references...${NC}"

current_file=0
total_files=$FILE_COUNT

while IFS= read -r file; do
    ((current_file++))
    progress_bar $current_file $total_files
    
    while IFS= read -r line; do
        # Skip lines with data: URIs or base64 content
        if [[ $line =~ "data:" ]] || [[ $line =~ "base64" ]]; then
            continue
        fi

        # Extract URLs from url() patterns in CSS/SCSS, ignoring special cases
        echo "$line" | grep -o "url([^)]*)" | \
        grep -v "data:" | \
        grep -v "base64" | \
        grep -v "#default" | \
        sed -E "s/url\(['\"]?([^'\"^)]+)['\"]?\)/\1/" | while read -r url; do
            if [ ! -z "$url" ]; then
                # Handle relative paths with ../
                clean_url=$(echo "$url" | sed 's#\.\./##g')
                # Only process if it has a file extension that we're looking for
                for ext in "${EXT_ARRAY[@]}"; do
                    if [[ "$clean_url" == *".$ext" ]]; then
                        filename=$(basename "$clean_url")
                        echo "$filename" >> "$USED_FILES"
                        [ "$VERBOSE" = true ] && echo -e "\nFound (url): $filename in $file from: $url"
                    fi
                done
            fi
        done

        # Check for Django static tags
        if [[ $line =~ \{\%[[:space:]]*static[[:space:]]*[\'\"]([^\'\"]+)[\'\"] ]]; then
            filepath="${BASH_REMATCH[1]}"
            # Only process if it has a file extension that we're looking for
            for ext in "${EXT_ARRAY[@]}"; do
                if [[ "$filepath" == *".$ext" ]]; then
                    filename=$(basename "$filepath")
                    echo "$filename" >> "$USED_FILES"
                    [ "$VERBOSE" = true ] && echo -e "\nFound (static): $filename in $file"
                fi
            done
        fi
    done < "$file"
    
done <<< "$SOURCE_FILES"

# Sort and remove duplicates from used files
sort -u "$USED_FILES" -o "$USED_FILES"

echo -e "\n\n${YELLOW}Analyzing static files...${NC}"

# Process each extension
for EXT in "${EXT_ARRAY[@]}"; do
    echo -e "\nChecking ${GREEN}.${EXT}${NC} files:"
    
    # Find all static files with current extension
    while IFS= read -r -d '' file; do
        ((TOTAL_FILES++))
        rel_path=${file#"$STATIC_PATH/"}
        filename=$(basename "$rel_path")
        
        # Check if file is used
        if ! grep -q "^$filename\$" "$USED_FILES"; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                size=$(stat -f %z "$file")
            else
                size=$(stat -c %s "$file")
            fi
            
            ((TOTAL_SIZE+=size))
            ((UNUSED_FILES++))
            
            formatted_size=$(format_size $size)
            
            if [ "$DRY_RUN" = true ]; then
                echo -e "${YELLOW}Would remove:${NC} $rel_path ($formatted_size)"
            else
                echo -e "${RED}Removing:${NC} $rel_path ($formatted_size)"
                rm "$file"
            fi
        elif [ "$VERBOSE" = true ]; then
            echo -e "${GREEN}Found usage for:${NC} $filename"
        fi
    done < <(find "$STATIC_PATH" -type f -name "*.$EXT" -print0)
done

echo -e "\n${GREEN}=== Summary ===${NC}"
echo "Total files checked: $TOTAL_FILES"
echo "Unused files found: $UNUSED_FILES"
echo "Total space $([ "$DRY_RUN" = true ] && echo 'that would be' || echo '') recovered: $(format_size $TOTAL_SIZE)"

if [ "$DRY_RUN" = true ]; then
    echo -e "\n${YELLOW}Note: This was a dry run. No files were actually deleted.${NC}"
    echo "Run without -d flag to perform actual cleanup."
fi