# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Curupira is a personal blog platform built with Phoenix 1.8 and Phoenix LiveView 1.1. It imports articles from dev.to and displays them in a newspaper-style layout with pagination and search functionality. The application supports both development and production deployment via Docker.

## Architecture

### Context Boundaries

- **Curupira.Blog**: Main business context managing articles and blog profile (singleton)
  - `Article` schema: Stores blog posts with dev.to metadata (title, content, slug, tags, published_at, dev_to_id, etc.)
  - `Profile` schema: Singleton blog configuration (name, bio, avatar, social links)
  - `DevToImporter`: Fetches articles from dev.to API, filters boost articles, generates HTML previews

- **Curupira.Markdown**: Markdown parsing using MDEx library
  - `Parser.to_html/1`: Converts markdown to HTML with strikethrough, tables, footnotes, autolinks, and smart punctuation

- **CurupiraWeb.ArticleLive**: LiveView module handling article listing and editing
  - `Index`: Homepage with paginated article list, search, and newspaper-style layout
  - `Form`: Article creation/editing with markdown preview

### Key Dependencies

- `:mdex` - Markdown to HTML conversion (not CommonMark.ex)
- `:req` - HTTP client for dev.to API (preferred over :httpoison, :tesla)
- `:cloudex` - Cloudinary integration for image uploads
- `:html_sanitize_ex` - HTML sanitization
- `:owl` - CLI progress bars and colored output

## Development Commands

### Setup & Running

```bash
# Initial setup (install deps, create db, migrate, seed)
mix setup

# Start development server
mix phx.server

# Start with IEx console
iex -S mix phx.server

# Pre-commit checks (compile with warnings as errors, format, test)
mix precommit
```

### Database

```bash
# Run migrations
mix ecto.migrate

# Reset database (drop, create, migrate, seed)
mix ecto.reset

# Run seeds
mix run priv/repo/seeds.exs
```

### Testing

```bash
# Run all tests
mix test

# Run specific test file
mix test test/path/to/test.exs

# Run previously failed tests
mix test --failed
```

### Assets

```bash
# Install asset tooling (if missing)
mix assets.setup

# Build assets (compile, tailwind, esbuild)
mix assets.build

# Deploy assets (minified with digest)
mix assets.deploy
```

### dev.to Import

```bash
# Import articles using DEVTO_USERNAME env var
mix devto.import

# Import with specific username
mix devto.import --username leandronsp

# Import ALL articles with progress bar
mix devto.import --all

# Import specific page
mix devto.import --page 2 --per-page 100
```

### Static Site Generation & Export

```bash
# Export to separate repo (default: ../leandronsp.com)
make export-markdown  # Export markdown with YAML frontmatter
make export-static    # Sync static files (HTML, CSS, JS, images)
make export-full      # Build + export markdown + sync (recommended)

# Configure custom export target
export EXPORT_TARGET=../mysite.com
make export-full

# Manual build (without Docker, requires running dev environment)
./build_static.sh
# Or: docker-compose exec web mix assets.build && docker-compose exec web mix build_static
```

**Export workflow** (see `EXPORT_DEPLOY.md` for details):
1. `make export-full` - Builds static site and syncs to target repo
2. `cd $EXPORT_TARGET && git add . && git commit -m "update"`
3. `git push` - Triggers deployment on Cloudflare Pages/Netlify/Vercel

## Docker & Deployment

### Development (Docker Compose)

```bash
# Start development environment (port 4000)
make dev-up

# Stop development
make dev-down

# View logs
make dev-logs

# Reset database
make dev-reset

# Run seeds
make dev-seeds

# Access IEx shell
make dev-shell
```

### Production (Local Testing)

```bash
# Build production image
make prod-build

# Start production environment (port 4001)
make prod-up

# Stop production
make prod-down

# Create admin user
make prod-create-admin ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD=password
```

### Deployment to Server

```bash
# Full deployment (build, push, deploy)
make deploy

# Or step by step:
make deploy-build  # Build AMD64 image
make deploy-push   # Push to Docker Hub
```

**Configuration via environment variables:**
- `DOCKER_REGISTRY` - Docker Hub repository (default: leandronsp/curupira)
- `DOCKER_TAG` - Image tag (default: latest)
- `DEPLOY_HOST` - SSH host for deployment (default: reads from ~/.ssh/config)
- `DEPLOY_KEY` - SSH key path (default: ~/.ssh/curupira-user)

### Database Backup & Restore

```bash
# Create local backup (.sql file)
make backup-create

# Upload to S3 (requires AWS CLI + AWS_PROFILE)
make backup-upload

# Download latest from S3
make backup-download

# Restore from downloaded backup (with confirmation)
make backup-restore

# Create + upload in one command
make backup-full

# List all S3 backups
make backup-list
```

**S3 Configuration** (defaults in Makefile):
- `S3_BUCKET` - S3 bucket name (default: curupira-backups)
- `S3_PREFIX` - Path prefix in bucket (default: curupira/)
- `AWS_PROFILE` - AWS CLI profile (default: default)
- `BACKUP_DIR` - Local backup directory (default: ./backups)

## Environment Variables

Required in `.env` for development:

```
DATABASE_URL=postgresql://postgres:postgres@db:5432/curupira_dev
MIX_ENV=dev
DEVTO_USERNAME=your_devto_username
CLOUDINARY_CLOUD_NAME=    # Optional: for image uploads
CLOUDINARY_API_KEY=       # Optional
CLOUDINARY_API_SECRET=    # Optional
```

Production requires:
- `DATABASE_URL`
- `SECRET_KEY_BASE`
- `PHX_SERVER=true`
- `PHX_HOST`
- `PORT`
- `POOL_SIZE`

## Project Structure Patterns

### LiveView Routing
- Routes use the default `:browser` pipeline which aliases `CurupiraWeb`
- No need to duplicate module prefixes: `live "/", ArticleLive.Index, :index`

### Article Schema Notes
- `dev_to_id` uniquely identifies imported articles for updates
- `status` field tracks publication state ("published", "draft")
- `html_preview` generated from markdown during import
- `tags` stored as array of strings
- `language` field stores article language code ("en", "pt", "pt-BR")
- Helper functions: `language_flag/1` returns emoji (🇺🇸, 🇧🇷), `language_code/1` returns display code (EN, PT)

### DevToImporter Behavior
- Fetches individual article content for full `body_markdown`
- Filters boost articles (title "[Boost]" or contains `{% embed`)
- Updates existing articles by `dev_to_id` or creates new
- Progress callback support for CLI progress bars

### Blog Profile (Singleton)
- Only one profile record exists, managed by `Blog.get_or_create_profile/0`
- Used for site-wide settings (name, bio, avatar, social links)

### Static Site Generation & Export System

**Build Process** (`lib/mix/tasks/build_static.ex`):
- Generates static HTML/CSS/JS in `static_output/` directory
- Optimizes CSS using Tailwind with custom config (`tailwind.static.config.js`) - ~25KB
- Minifies JavaScript files (total ~5KB):
  - `static-theme.js` (0.6KB) - Dark/light theme toggle
  - `static-search.js` (1.9KB) - Client-side search
  - `static-pagination.js` (2.5KB) - Pagination logic
  - `static-giscus.js` (0.6KB) - Giscus theme sync
- Giscus comments integration on each article page (GitHub Discussions-based)
- Client-side search using JSON index (`search-index.json`)
- Language filtering (PT/EN) with active state buttons
- SEO: Open Graph, Twitter Cards, JSON-LD schema, sitemap.xml, robots.txt

**Markdown Export** (`lib/mix/tasks/export.markdown.ex`):
- Exports articles as `.md` files with YAML frontmatter
- Frontmatter includes: title, slug, published_at, language, status, tags
- Default: only published articles (use `--all` for drafts)
- Output: `markdown_output/` → copied to target repo's `articles/` subdirectory

**Sync Script** (`sync_static.sh`):
- Uses rsync to sync `static_output/` to target repository
- Preserves git metadata and infrastructure files in target repo
- Controlled via `EXPORT_TARGET` env var (default: `../leandronsp.com`)
- Exclusions: `.git/`, `docker-compose.yml`, `nginx.conf`, `Makefile`, `README.md`, `articles/*.md`

**Deployment** (see `EXPORT_DEPLOY.md`):
- Curupira acts as backoffice/CMS
- Export workflow pushes to separate git repo
- Target repo auto-deploys via Cloudflare Pages, Netlify, Vercel, or GitHub Pages
- Separation of concerns: CMS vs public site

## Important Architecture Patterns

### Dual-Mode Operation
Curupira operates in two distinct modes:
1. **Dynamic Mode**: Full Phoenix LiveView app with admin features (backoffice)
2. **Static Mode**: Zero-server HTML/CSS/JS deployment for public consumption

### Export vs Build Distinction
- **`mix build_static`**: Generates static HTML from database articles (for static hosting)
- **`mix export.markdown`**: Exports raw markdown with frontmatter (for git versioning)
- **`make export-full`**: Combines both + rsync to target repo (complete workflow)

### Database Seeding
- Seeds use `Blog.create_article/1` (not `Repo.insert!`) to ensure slugs are auto-generated via changesets
- Articles without slugs will fail to render in static mode

### JavaScript Minification
- All static JS files are minified using esbuild during `mix build_static`
- Source files in `priv/static/`, minified output in `static_output/`
- Total JS payload optimized to ~5KB for PageSpeed performance

### Giscus Comments Integration
- Comments load on each article page (not homepage)
- Theme sync script uses MutationObserver to watch `data-theme` attribute
- Configuration uses pathname mapping for per-article discussion threads
- Repository: `leandronsp/leandronsp.com` with `Announcements` category

## Testing Patterns

- Test files in `test/curupira/` and `test/curupira_web/`
- LiveView tests use `Phoenix.LiveViewTest` and `LazyHTML` for assertions
- Use `has_element?/2` with DOM IDs rather than raw HTML matching
- Prefer testing element presence over text content

## Related Documentation

- `EXPORT_DEPLOY.md` - Complete export and deployment workflow guide
- `STATIC_DEPLOY.md` - GitHub Pages deployment (legacy, pre-export system)
- `README.md` - User-facing project overview and quick start
- `CONTRIBUTING.md` - Contributor license agreement
