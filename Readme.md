# Remove Unused Files (very fast)

A bash script to find and remove unused static files (images, fonts, etc.) in web projects. It's particularly useful for cleaning up old assets in Django projects, but works with any web project structure.

## Why I Built This

After maintaining several Django projects, I noticed we often had many unused images and other static files sitting around. These files:
- Bloat git repositories
- Make deployments slower
- Add confusion about which assets are actually needed

This tool helps keep projects clean by finding static files that aren't referenced anywhere in your codebase.

## Installation

Clone the repository and make the script executable:
```bash
git clone https://github.com/hatimmakki/remove-unused-files.git
cd remove-unused-files
chmod +x static-cleanup.sh
```

## Usage

Basic usage:
```bash
./static-cleanup.sh -e "png,jpg" -s "html,js,css" -l "static/assets" -d
```

### Options

Required:
- `-e EXTENSIONS`: File types to check (comma-separated)
- `-s SEARCH_IN`: File types to search in (comma-separated)

Optional:
- `-l LOCATION`: Where to look for static files
- `-i IGNORE`: Folders to ignore (comma-separated)
- `-d`: Dry run (don't actually delete)
- `-v`: Verbose output

### Examples

Check for unused PNGs and JPGs:
```bash
./static-cleanup.sh -e "png,jpg" -s "html,js,css" -l "static/assets" -d
```

Include fonts and exclude some directories:
```bash
./static-cleanup.sh -e "png,jpg,ttf,woff" -s "html,js,css,scss" -l "static/assets" -i "venv,node_modules" -d
```

Real-world example - checking static assets in a Django project:
```bash
# First, run in dry-run mode to see what would be removed
./static-cleanup.sh -e "png,jpg,svg" -s "html,js,css,scss" -l "static/assets" -i "venv,node_modules,dist" -d

# If the results look good, run without -d to actually remove files
./static-cleanup.sh -e "png,jpg,svg" -s "html,js,css,scss" -l "static/assets" -i "venv,node_modules,dist"
```

## How It Works

The script:
1. Creates a cache of all searchable file content
2. Looks for files with specified extensions
3. Checks if each file is referenced in the cached content
4. Reports or removes unused files

## Safety Features

- Dry run mode (`-d`) to preview changes
- Verbose mode (`-v`) to see detailed info
- Backups aren't deleted (located outside static dirs)
- Ignores specified directories

## Tips

1. Always run with `-d` first to see what would be removed
2. Use `-v` to understand why files are marked as unused
3. Check the templates/code if a file is marked unused but you think it's used
4. Exclude cache and build directories using `-i`

## Contributing

Feel free to open issues or submit PRs if you have improvements!

## License

MIT License - feel free to use and modify as needed.
