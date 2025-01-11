# Fast Files Cleanup Tool for Mac

A bash script I created to help find and remove unused static files (images, fonts, etc.) in web projects. It's particularly useful for cleaning up old assets in Django projects, but works with any web project structure.

## Why I Built This

After maintaining several Django projects, I noticed we often had many unused images and other static files sitting around. These files:
- Bloat git repositories
- Make deployments slower
- Add confusion about which assets are actually needed

This tool helps keep projects clean by finding static files that aren't referenced anywhere in your codebase.

## Features

- Find unused static files (images, fonts, etc.)
- Search through multiple file types (HTML, JS, CSS, etc.)
- Specify search locations and ignore paths
- Dry run mode to preview changes
- Fast operation with caching
- Handles Django static template tags

## Installation

Just download and make executable:
```bash
curl -O https://raw.githubusercontent.com/yourusername/cleanup/main/cleanup.sh
chmod +x cleanup.sh
```

## Usage

Basic usage:
```bash
./cleanup.sh -e "png,jpg" -s "html,js,css" -l "static/assets" -d
```

### Options

Required:
- `-e EXTENSIONS`: File types to check (comma-separated)
- `-s SEARCH_IN`: File types to search in (comma-separated)

Optional:
- `-l LOCATION`: Where to look for static files. default is current location, or "."
- `-i IGNORE`: Folders to ignore (comma-separated). for faster result specify folders like node_modules, or venv for python projects because it doesn't make sence to search in these folders.
- `-d`: Dry run (don't actually delete), just show me what is going on.
- `-v`: Verbose output. Show more details.

### Examples

Check for unused PNGs and JPGs:
```bash
./cleanup.sh -e "png,jpg" -s "html,js,css" -l "." -d
```

Include fonts and exclude some directories:
```bash
./cleanup.sh -e "png,jpg,ttf,woff" -s "html,js,css,scss" -l "static/assets" -i "venv,node_modules" -d
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
