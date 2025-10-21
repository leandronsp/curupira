# Export to leandronsp.com

This document explains how to export the Curupira blog to the `leandronsp.com` repository for deployment on Cloudflare Pages.

## Overview

The export process generates:
- **Static HTML files** - Homepage, article pages, CSS, JS, images
- **Markdown files** - Raw markdown versions of all published articles

All files are exported to `../leandronsp.com` by default (configurable via `EXPORT_TARGET` env var).

## Quick Start

```bash
# Build static site + export everything
make export-full

# Or export individually:
make static-build      # Build static HTML/CSS/JS
make export-markdown   # Export articles as markdown
make export-static     # Sync static files
```

## Configuration

Set the target directory via environment variable:

```bash
export EXPORT_TARGET=/path/to/your/site
make export-full
```

Or inline:

```bash
EXPORT_TARGET=/custom/path make export-full
```

Default: `../leandronsp.com`

## Output Structure

```
leandronsp.com/
├── index.html              # Homepage
├── robots.txt              # SEO
├── sitemap.xml             # SEO
├── search-index.json       # Client-side search
├── static-*.js             # JavaScript
├── assets/
│   └── css/
│       └── app.css         # Optimized/minified CSS
├── images/
│   └── favicon.svg
├── uploads/                # User-uploaded images
└── articles/
    ├── *.html              # 70 HTML article pages
    └── *.md                # 70 Markdown source files
```

## Commands Reference

### `make export-markdown`
Exports all published articles as markdown files with YAML frontmatter.

**Output**: `$EXPORT_TARGET/articles/*.md`

**Frontmatter includes**:
- title
- slug
- published_at
- language
- status
- tags

### `make export-static`
Syncs static HTML/CSS/JS files to target directory.

**Preserves**: Markdown files in `articles/` directory

### `make export-full`
Complete export workflow:
1. Builds static site (`make static-build`)
2. Exports markdown files
3. Syncs static files

## Local Preview

After exporting, preview the site locally:

```bash
cd ../leandronsp.com
make up
```

Visit: http://localhost:8000

Stop the server:

```bash
make down
```

## Deployment to Cloudflare Pages

After running `make export-full`:

```bash
cd ../leandronsp.com
git add .
git commit -m "Update site content"
git push
```

Cloudflare Pages will automatically deploy the changes.

## Article Filtering

By default, only **published** articles are exported.

To export ALL articles (including drafts):

```bash
docker-compose exec web mix export.markdown --all
```

## Troubleshooting

### Markdown files get deleted
Run exports in the correct order:
```bash
make export-markdown  # First
make export-static    # Second (preserves .md files)
```

Or use `make export-full` which runs them in the correct order.

### Target directory doesn't exist
The export process automatically creates the target directory if it doesn't exist.

### Permission errors
Ensure you have write permissions to the target directory.

## Development

**Mix Task**: `lib/mix/tasks/export.markdown.ex`
**Sync Script**: `sync_static.sh`
**Makefile**: See "Export Commands" section

## See Also

- `STATIC_DEPLOY.md` - Static site generation details
- `Makefile` - All available commands
