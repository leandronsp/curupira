# Curupira

Personal blog platform built with Phoenix LiveView. Imports articles from dev.to and displays them in a newspaper-style layout with pagination and search.

## Quick Start

### Native (requires Elixir/PostgreSQL)

```bash
# Setup database and dependencies
mix setup

# Start server
mix phx.server

# Visit http://localhost:4000
```

### Docker (recommended)

```bash
# Start development environment
make dev-up

# View logs
make dev-logs

# Stop environment
make dev-down
```

## Import Articles from dev.to

Set your dev.to username in `.env`:
```
DEVTO_USERNAME=your_username
```

Import all articles:
```bash
# Native
mix devto.import --all

# Docker
docker-compose exec web mix devto.import --all
```

## Development

```bash
# Run tests
mix test

# Run precommit checks (format, compile with warnings, test)
mix precommit

# Access IEx console (native)
iex -S mix phx.server

# Access IEx console (docker)
make dev-shell
```

## Database

```bash
# Reset database (drop, create, migrate, seed)
mix ecto.reset

# Run migrations only
mix ecto.migrate
```

## Production

### Local Testing

```bash
# Build and start production environment (port 4001)
make prod-build
make prod-up

# Create admin user
make prod-create-admin ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD=password
```

### Deploy to Server

Configure deployment in `~/.ssh/config`:
```
Host curupira
  HostName your-server.com
  User your-user
```

Deploy:
```bash
make deploy
```

Or manually:
```bash
make deploy-build  # Build AMD64 image
make deploy-push   # Push to Docker Hub
```

## Environment Variables

Create `.env` file:
```bash
DATABASE_URL=postgresql://postgres:postgres@db:5432/curupira_dev
MIX_ENV=dev
DEVTO_USERNAME=your_username

# Optional: for image uploads
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
```

## Makefile Commands

Run `make help` to see all available commands for development, production testing, and deployment.
