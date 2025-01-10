# Static Files Cleaner

A bash script to identify and clean unused static files in your project. The script is particularly useful for Django projects but can be used with any project structure.

## Features

- Detects unused static files by scanning source files for references
- Supports multiple file extensions
- Handles various reference patterns:
  - Django static template tags (`{% static 'path/to/file' %}`)
  - CSS/SCSS URL patterns (`url(path/to/file)`)
  - Relative paths (`../../path/to/file`)
- Excludes specified directories from search
- Dry run mode for safe testing
- Progress bar and detailed logging
- Handles both absolute and relative paths

## Prerequisites

- Bash shell
- Unix-like environment (Linux, macOS)
- Common Unix utilities (`find`, `grep`, `sed`)

## Installation

1. Download the script:
```bash
curl -O https://raw.githubusercontent.com/your-repo/cleanup.sh
```

2. Make it executable:
```bash
chmod +x cleanup.sh
```

## Usage

### Basic Command Structure

```bash
./cleanup.sh -s STATIC_DIR -e EXTENSIONS [options]
```

### Required Parameters

- `-s STATIC_DIR`: Directory containing static files to check
  ```bash
  -s static/assets/fonts
  ```

- `-e EXTENSIONS`: Comma-separated list of file extensions to check
  ```bash
  -e "ttf,woff,woff2"
  ```

### Optional Parameters

- `searchExtensions "EXTS"`: File extensions to search in (default: html,js,css)
  ```bash
  searchExtensions "html,scss,css"
  ```

- `excludeFolders "FOLDERS"`: Directories to exclude from search
  ```bash
  excludeFolders "venv,node_modules,dist"
  ```

- `searchPath "PATH"`: Where to search for references (default: current directory)
  ```bash
  searchPath "static/assets/scss"
  ```

- `-d`: Dry run mode (shows what would be deleted without actually deleting)
- `-v`: Verbose output (shows detailed information about found references)

### Examples

1. Find unused font files:
```bash
./cleanup.sh -s static/assets/fonts -e "ttf" \
    searchExtensions "scss" \
    excludeFolders "venv,dist,build" \
    searchPath "static/assets/scss" -d -v
```

2. Find unused images:
```bash
./cleanup.sh -s static/assets/img -e "png,jpg,svg" \
    searchExtensions "html,js,css" \
    excludeFolders "venv,node_modules" \
    searchPath "templates" -d
```

3. Check specific files in a directory:
```bash
./cleanup.sh -s static/assets/icons -e "svg" \
    searchExtensions "html,scss" \
    searchPath "." -d
```

## How It Works

The script works in three main phases:

1. **Scanning Phase**
   - Searches through files specified by `searchExtensions`
   - Looks for three types of references:
     - Django static tags (`{% static '...' %}`)
     - URL patterns in CSS/SCSS (`url(...)`)
     - Direct file references

2. **Analysis Phase**
   - Builds list of all static files in specified directory
   - Compares against found references
   - Handles relative paths and various formats

3. **Report/Action Phase**
   - Shows what files would be removed
   - Calculates potential space savings
   - Actually removes files if not in dry run mode

## Real-World Example

Consider a Django project with SCSS files:

```scss
// In static/assets/scss/styles.scss
@font-face {
  font-family: 'Montserrat';
  src: url('../../fonts/Montserrat-Regular.ttf');
}
```

To find unused font files:
```bash
./cleanup.sh -s static/assets/fonts -e "ttf" \
    searchExtensions "scss" \
    searchPath "static/assets/scss" -d
```

This will:
1. Look for .ttf files in static/assets/fonts
2. Search all .scss files in static/assets/scss
3. Show which font files aren't referenced

## Tips

1. **Start Specific**: Begin with specific directories and file types
   ```bash
   ./cleanup.sh -s static/assets/fonts -e "ttf" searchPath "static/assets/scss"
   ```

2. **Use Dry Run**: Always use `-d` first to preview changes
   ```bash
   ./cleanup.sh -s static/assets/img -e "png" -d
   ```

3. **Check References**: Use `-v` to see where files are referenced
   ```bash
   ./cleanup.sh -s static/icons -e "svg" -v
   ```

## Best Practices

1. Always run with `-d` first
2. Back up important files before running without `-d`
3. Use specific paths rather than searching entire project
4. Start with smaller directories to test
5. Use version control for safety

## Troubleshooting

Common issues and solutions:

1. **Files marked as unused but actually used**
   - Check file extensions in `searchExtensions`
   - Use `-v` to see what's being found
   - Check path structure in references

2. **Script runs slowly**
   - Use more specific `searchPath`
   - Add irrelevant directories to `excludeFolders`
   - Limit scope of search

3. **No files found**
   - Check paths are correct
   - Verify file extensions
   - Use `-v` for detailed output

## Contributing

Feel free to submit issues and enhancement requests!