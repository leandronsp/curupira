# Export & Deploy Workflow

This guide explains how to export your blog to a separate repository for deployment to Cloudflare Pages, Netlify, Vercel, or any git-based static hosting.

## Overview

Curupira acts as your backoffice/CMS where you manage articles. The export workflow pushes the static site and markdown files to a separate repository for deployment.

**Workflow:**
```
Curupira (backoffice) → Export → Target Repo → Push → Hosting Platform
```

**Benefits:**
- ✅ Separation of concerns (CMS vs public site)
- ✅ Automatic deployment on git push
- ✅ Version control for your published content
- ✅ Export markdown source files alongside HTML
- ✅ Works with any git-based hosting (Cloudflare Pages, Netlify, Vercel, GitHub Pages)

## Quick Start

### 1. Create target repository

```bash
# Create a separate repository for your static site
cd ..
mkdir mysite.com
cd mysite.com
git init
git remote add origin git@github.com:USERNAME/mysite.com.git
```

### 2. Configure export target

Set the `EXPORT_TARGET` environment variable to point to your target repository:

```bash
# In curupira directory
export EXPORT_TARGET=../mysite.com

# Or add to your shell profile (~/.bashrc, ~/.zshrc)
echo 'export EXPORT_TARGET=../mysite.com' >> ~/.zshrc
```

**Default:** If not set, defaults to `../leandronsp.com`

### 3. Run export workflow

```bash
# Full workflow: build static site, export markdown, sync files
make export-full
```

This will:
1. Build optimized static site with Giscus comments
2. Export all published articles as markdown with YAML frontmatter
3. Sync static files (HTML, CSS, JS, images) to target repo
4. Preserve target repo's git metadata and infrastructure files

### 4. Commit and deploy

```bash
# Navigate to target repo
cd $EXPORT_TARGET  # or cd ../mysite.com

# Review changes
git status
git diff

# Commit changes
git add .
git commit -m "update blog content"

# Push to trigger deployment
git push
```

Your hosting platform (Cloudflare Pages, Netlify, etc.) will automatically detect the push and deploy.

## Export Commands

### Individual commands

```bash
# Export only markdown files
make export-markdown

# Sync only static files (HTML, CSS, JS, images)
make export-static

# Full export (recommended)
make export-full
```

### Manual commands

```bash
# Export markdown with custom output
docker-compose exec -T web mix export.markdown --output /app/markdown_output

# Sync with custom target
EXPORT_TARGET=/path/to/target ./sync_static.sh
```

## What Gets Exported

### Static Files (HTML/CSS/JS)

Exported to target repo root:

```
mysite.com/
├── index.html              # Homepage with article list
├── articles/               # Individual article pages
│   ├── my-post.html
│   └── another-post.html
├── assets/
│   └── css/
│       └── app.css         # Optimized & purged CSS (25KB)
├── uploads/                # Article images
├── static-theme.js         # Dark/light theme toggle (0.6KB)
├── static-search.js        # Client-side search (1.9KB)
├── static-pagination.js    # Pagination logic (2.5KB)
├── static-giscus.js        # Giscus theme sync (0.6KB)
├── search-index.json       # Search data
├── sitemap.xml            # SEO sitemap
├── robots.txt             # SEO robots file
└── .nojekyll              # Disable Jekyll processing
```

### Markdown Files

Exported to `articles/` subdirectory with YAML frontmatter:

```
mysite.com/articles/
├── my-first-post.md
├── another-post.md
└── ...
```

**Frontmatter format:**
```yaml
---
title: "Building a Web Server in Bash"
slug: "building-a-web-server-in-bash"
published_at: "2024-01-15T10:30:00Z"
language: "en"
status: "published"
tags: ["bash", "linux", "web"]
---

Article content here...
```

## Sync Script Behavior

The `sync_static.sh` script uses `rsync` with smart exclusions:

**Preserves in target repo:**
- `.git/` - Git metadata
- `.gitignore` - Git ignore rules
- `docker-compose.yml` - Local dev server config
- `nginx.conf` - Nginx configuration
- `Makefile` - Target repo commands
- `README.md` - Target repo documentation
- `articles/*.md` - Markdown files (managed by export-markdown)

**Syncs from static_output:**
- All HTML files
- All CSS/JS assets
- All images
- Generated JSON/XML files

**Command:**
```bash
rsync -av --delete \
    --exclude '.git/' \
    --exclude '.gitignore' \
    --exclude 'docker-compose.yml' \
    --exclude 'nginx.conf' \
    --exclude 'Makefile' \
    --exclude 'README.md' \
    --exclude 'articles/*.md' \
    static_output/ target_repo/
```

## Deployment Platforms

### Cloudflare Pages

1. **Connect repository:**
   - Go to [Cloudflare Pages](https://pages.cloudflare.com/)
   - Create new project → Connect to Git
   - Select your target repository

2. **Build settings:**
   - Framework preset: None
   - Build command: (leave empty)
   - Build output directory: `/`
   - Root directory: `/`

3. **Deploy:**
   - Every push to main branch triggers deployment
   - Preview deployments for other branches

### Netlify

1. **Connect repository:**
   - Go to [Netlify](https://netlify.com/)
   - Add new site → Import from Git
   - Select your target repository

2. **Build settings:**
   - Build command: (leave empty)
   - Publish directory: `/`

3. **Deploy:**
   - Auto-deploys on every push

### Vercel

1. **Connect repository:**
   - Go to [Vercel](https://vercel.com/)
   - Add New Project → Import Git Repository

2. **Build settings:**
   - Framework Preset: Other
   - Build Command: (leave empty)
   - Output Directory: `/`

3. **Deploy:**
   - Auto-deploys on every push

### GitHub Pages

See `STATIC_DEPLOY.md` for GitHub Pages-specific instructions.

## Local Preview (Target Repo)

If you set up nginx in your target repo:

```bash
# In target repo (e.g., ../mysite.com)
docker-compose up

# Open browser
open http://localhost:8000
```

**docker-compose.yml:**
```yaml
services:
  nginx:
    image: nginx:alpine
    ports:
      - "8000:80"
    volumes:
      - .:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    restart: unless-stopped
```

## Complete Deployment Workflow

Here's the full workflow you just executed:

```bash
# 1. Build optimized static site with all features
make static-build

# 2. Export markdown and sync to target repo
make export-full

# 3. Navigate to target repo
cd $EXPORT_TARGET  # or cd ../leandronsp.com

# 4. Review changes
git status

# 5. Commit changes
git add .
git commit -m "add giscus comments to all article pages"

# 6. Push to trigger deployment
git push

# 7. Hosting platform automatically deploys
# (Cloudflare Pages, Netlify, etc. detect the push)
```

## Environment Variables

### EXPORT_TARGET

Location of your target repository.

**Default:** `../leandronsp.com`

**Usage:**
```bash
# Set for single command
EXPORT_TARGET=/path/to/repo make export-full

# Set persistently
export EXPORT_TARGET=../mysite.com
make export-full

# Add to shell profile
echo 'export EXPORT_TARGET=../mysite.com' >> ~/.zshrc
```

## Makefile Commands

### In Curupira (backoffice)

```makefile
# Build static site (in Docker)
make static-build

# Export markdown files
make export-markdown

# Sync static files to target
make export-static

# Full workflow (build + export markdown + sync)
make export-full
```

**Implementation:**
```makefile
EXPORT_TARGET ?= ../leandronsp.com

export-markdown:
	@docker-compose exec -T web mix export.markdown --output /app/markdown_output
	@mkdir -p $(EXPORT_TARGET)/articles
	@cp -r ./markdown_output/* $(EXPORT_TARGET)/articles/

export-static:
	@EXPORT_TARGET=$(EXPORT_TARGET) ./sync_static.sh

export-full: static-build export-markdown export-static
	@echo "Full export complete!"
```

### In Target Repo

```makefile
# Serve locally on port 8000
serve:
	docker-compose up

# Stop local server
stop:
	docker-compose down
```

## Customization

### Change target repository

```bash
# Use different repo
export EXPORT_TARGET=../blog.example.com
make export-full
```

### Export only drafts (advanced)

```bash
# Export all articles (including drafts)
docker-compose exec -T web mix export.markdown --output /app/markdown_output --all
```

### Add custom files to sync

Edit `sync_static.sh` to remove exclusions or add more:

```bash
rsync -av --delete \
    --exclude '.git/' \
    --exclude 'custom-file.txt' \
    static_output/ $TARGET_DIR/
```

## Features Included

All exported HTML pages include:

- ✅ Giscus comments (GitHub Discussions)
- ✅ Dark/light theme toggle with localStorage persistence
- ✅ Theme synchronization with Giscus iframe
- ✅ Client-side search with instant filtering
- ✅ Pagination (if many articles)
- ✅ Language filtering (PT/EN buttons)
- ✅ SEO metadata (Open Graph, Twitter Cards, JSON-LD)
- ✅ Sitemap.xml for search engines
- ✅ Robots.txt
- ✅ Responsive design
- ✅ Minified JavaScript (~5KB total)
- ✅ Optimized CSS (~25KB purged)

## Troubleshooting

### Export target not found

```
Error: ../mysite.com does not exist
```

**Solution:** Create the target directory and initialize git:
```bash
mkdir -p ../mysite.com
cd ../mysite.com
git init
git remote add origin YOUR_GIT_URL
```

### Git metadata deleted

```
Error: .git folder is missing in target repo
```

**Solution:** The sync script preserves `.git/` by default. If deleted, re-initialize:
```bash
cd $EXPORT_TARGET
git init
git remote add origin YOUR_GIT_URL
```

### Permission denied on sync

```
Error: rsync permission denied
```

**Solution:** Check directory permissions:
```bash
chmod -R u+w $EXPORT_TARGET
```

### Deployment not triggered

**Solution:** Check your hosting platform's git integration:
- Verify repository is connected
- Check branch name matches (usually `main` or `master`)
- Review deployment logs in platform dashboard

## Migration from Old Workflow

If you were using the old `static_output` in the same repo:

1. Create target repo: `mkdir ../mysite.com && cd ../mysite.com && git init`
2. Copy existing files: `cp -r ../curupira/static_output/* .`
3. Add infrastructure: `docker-compose.yml`, `nginx.conf`, `Makefile`, `README.md`
4. Commit initial state: `git add . && git commit -m "initial site"`
5. Set export target: `export EXPORT_TARGET=../mysite.com`
6. Use new workflow: `make export-full`

## See Also

- `STATIC_DEPLOY.md` - GitHub Pages deployment (old workflow)
- `CLAUDE.md` - Development patterns and project context
- `lib/mix/tasks/build_static.ex` - Static site generator implementation
- `lib/mix/tasks/export.markdown.ex` - Markdown export implementation
- `sync_static.sh` - Rsync synchronization script
