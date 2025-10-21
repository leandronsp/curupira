.PHONY: help dev-up dev-down dev-logs dev-reset dev-seeds prod-build prod-up prod-down prod-logs prod-reset prod-seeds prod-create-admin test-all clean static-build deploy-build deploy-push deploy backup-create backup-upload backup-download backup-restore backup-full backup-list export-markdown export-static export-full

# Default target
help:
	@echo "Curupira - Makefile Commands"
	@echo "=========================="
	@echo ""
	@echo "Development:"
	@echo "  make dev-up          - Start development environment (compose)"
	@echo "  make dev-down        - Stop development environment"
	@echo "  make dev-logs        - Follow development logs"
	@echo "  make dev-reset       - Reset development database"
	@echo "  make dev-seeds       - Run development seeds"
	@echo "  make dev-shell       - Access development shell (iex)"
	@echo ""
	@echo "Production (Local Testing):"
	@echo "  make prod-build      - Build production image"
	@echo "  make prod-up         - Start production environment (port 4001)"
	@echo "  make prod-down       - Stop production environment"
	@echo "  make prod-logs       - Follow production logs"
	@echo "  make prod-reset      - Reset production database"
	@echo "  make prod-seeds      - Run production seeds"
	@echo "  make prod-create-admin - Create admin user (requires ADMIN_EMAIL and ADMIN_PASSWORD)"
	@echo ""
	@echo "Testing:"
	@echo "  make test-all        - Start both dev and prod for testing"
	@echo "  make test-dev        - Test dev endpoint (localhost:4000)"
	@echo "  make test-prod       - Test prod endpoint (localhost:4001)"
	@echo ""
	@echo "Static Site:"
	@echo "  make static-build    - Build static site (output: ./static_output)"
	@echo ""
	@echo "Deployment:"
	@echo "  make deploy-build    - Build AMD64 image for production servers"
	@echo "  make deploy-push     - Push image to Docker Hub registry"
	@echo "  make deploy          - Build, push, and deploy to server (all-in-one)"
	@echo ""
	@echo "Backup & Restore:"
	@echo "  make backup-create   - Create database backup (.sql file)"
	@echo "  make backup-upload   - Upload backup to S3"
	@echo "  make backup-download - Download latest backup from S3"
	@echo "  make backup-restore  - Restore database from downloaded backup"
	@echo "  make backup-full     - Create and upload backup (all-in-one)"
	@echo "  make backup-list     - List all backups in S3"
	@echo ""
	@echo "Export to leandronsp.com:"
	@echo "  make export-markdown - Export articles as markdown files"
	@echo "  make export-static   - Sync static HTML/CSS/JS files"
	@echo "  make export-full     - Build static site + export markdown (all-in-one)"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean           - Stop everything and remove containers/volumes"
	@echo ""

# ======================
# Development Commands
# ======================

dev-up:
	@echo "Starting development environment..."
	docker-compose up -d --wait
	@echo "✓ Development running at http://localhost:4000"

dev-down:
	@echo "Stopping development environment..."
	docker-compose down

dev-logs:
	docker-compose logs -f web

dev-reset:
	@echo "Resetting development database..."
	docker-compose down -v
	docker-compose up -d --wait
	docker-compose exec web mix deps.get
	docker-compose exec web mix ecto.create
	docker-compose exec web mix ecto.migrate
	@echo "✓ Database reset complete"

dev-seeds:
	@echo "Running development seeds..."
	docker-compose exec web mix run priv/repo/seeds.exs
	@echo "✓ Seeds complete"

dev-shell:
	docker-compose exec web iex -S mix

# ======================
# Production Commands
# ======================

prod-build:
	@echo "Building production image..."
	docker build --target runner -t curupira:prod .
	@echo "✓ Production image built (check size below)"
	@docker images curupira:prod

prod-up:
	@echo "Starting production environment..."
	@echo "1. Creating production network..."
	-docker network create curupira-prod-local 2>/dev/null || true
	@echo "2. Starting PostgreSQL for production..."
	-docker run -d \
		--name curupira-postgres-prod \
		--network curupira-prod-local \
		--health-cmd="pg_isready -U postgres" \
		--health-interval=5s \
		--health-timeout=3s \
		--health-retries=5 \
		-e POSTGRES_USER=postgres \
		-e POSTGRES_PASSWORD=postgres \
		-e POSTGRES_DB=curupira_prod \
		-v curupira-pgdata-prod:/var/lib/postgresql/data \
		postgres:15-alpine 2>/dev/null || echo "PostgreSQL already running"
	@echo "3. Waiting for PostgreSQL to be healthy..."
	@docker exec curupira-postgres-prod pg_isready -U postgres > /dev/null 2>&1 || (echo "Waiting..." && sleep 5 && docker exec curupira-postgres-prod pg_isready -U postgres)
	@echo "4. Starting Curupira production app..."
	-docker run -d \
		--name curupira-app-prod \
		--network curupira-prod-local \
		-p 4001:4000 \
		-e DATABASE_URL=postgresql://postgres:postgres@curupira-postgres-prod:5432/curupira_prod \
		-e SECRET_KEY_BASE=uUuwfsmH5uHUclBJAsLcd61Y/xyGIaeT0gA48RCOyQhRkMDiD6mSEy2jubMCqdw4 \
		-e PHX_SERVER=true \
		-e PHX_HOST=localhost \
		-e PORT=4000 \
		-e POOL_SIZE=10 \
		-e MIX_ENV=prod \
		curupira:prod 2>/dev/null || echo "App already running"
	@echo "5. Waiting for app to start..."
	@sh -c 'for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do curl -sf http://localhost:4001/ >/dev/null 2>&1 && break || sleep 2; done'
	@echo "✓ Production running at http://localhost:4001"

prod-down:
	@echo "Stopping production environment..."
	-docker stop curupira-app-prod 2>/dev/null || true
	-docker rm curupira-app-prod 2>/dev/null || true
	-docker stop curupira-postgres-prod 2>/dev/null || true
	-docker rm curupira-postgres-prod 2>/dev/null || true
	@echo "✓ Production stopped"

prod-logs:
	docker logs -f curupira-app-prod

prod-reset:
	@echo "Resetting production database..."
	docker exec curupira-app-prod /app/bin/curupira eval "Curupira.Repo.delete_all(Curupira.Appointments.Appointment)"
	docker exec curupira-app-prod /app/bin/curupira eval "Curupira.Repo.delete_all(Curupira.Appointments.AvailabilitySlot)"
	docker exec curupira-app-prod /app/bin/curupira eval "Curupira.Repo.delete_all(Curupira.Accounts.Patient)"
	docker exec curupira-app-prod /app/bin/curupira eval "Curupira.Repo.delete_all(Curupira.Accounts.Professional)"
	docker exec curupira-app-prod /app/bin/curupira eval "Curupira.Repo.delete_all(Curupira.Accounts.User)"
	@echo "✓ Production database cleared"

prod-seeds:
	@echo "Running production seeds..."
	docker exec curupira-app-prod /app/bin/curupira eval "Curupira.Release.seed()"
	@echo "✓ Production seeds complete"

prod-create-admin:
	@if [ -z "$(ADMIN_EMAIL)" ] || [ -z "$(ADMIN_PASSWORD)" ]; then \
		echo "Error: ADMIN_EMAIL and ADMIN_PASSWORD required"; \
		echo "Usage: make prod-create-admin ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD=password"; \
		exit 1; \
	fi
	@echo "Creating admin user: $(ADMIN_EMAIL)"
	docker exec \
		-e ADMIN_EMAIL="$(ADMIN_EMAIL)" \
		-e ADMIN_PASSWORD="$(ADMIN_PASSWORD)" \
		curupira-app-prod /app/bin/curupira eval "Curupira.Release.create_admin()"

# ======================
# Testing Commands
# ======================

test-all: dev-down prod-down
	@echo "=========================================="
	@echo "Starting BOTH environments for testing"
	@echo "=========================================="
	@echo ""
	@make dev-up
	@make dev-reset
	@make dev-seeds
	@echo ""
	@make prod-build
	@make prod-up
	@make prod-seeds
	@echo ""
	@echo "=========================================="
	@echo "✓ Both environments ready!"
	@echo "=========================================="
	@echo ""
	@echo "Development: http://localhost:4000"
	@echo "Production:  http://localhost:4001"
	@echo ""
	@echo "Credentials (both):"
	@echo "  Admin:        admin@example.com / senha123"
	@echo "  Patient:      paciente1@example.com / senha123"
	@echo "  Psychologist: psicologo1@example.com / senha123"
	@echo ""
	@echo "Test endpoints:"
	@make test-dev
	@make test-prod

test-dev:
	@echo "Testing development..."
	@curl -s -o /dev/null -w "Dev (4000): HTTP %{http_code}\n" http://localhost:4000/

test-prod:
	@echo "Testing production..."
	@curl -s -o /dev/null -w "Prod (4001): HTTP %{http_code}\n" http://localhost:4001/

# ======================
# Static Site Commands
# ======================

static-build:
	@echo "=========================================="
	@echo "  Building Optimized Static Site"
	@echo "=========================================="
	@echo ""
	@echo "1. Ensuring development environment is running..."
	@docker-compose up -d --wait
	@echo ""
	@echo "2. Generating static site (CSS purge + SEO + pages)..."
	@docker-compose exec -T web mix build_static
	@echo ""
	@echo "=========================================="
	@echo "  ✓ Static Site Built!"
	@echo "=========================================="
	@echo ""
	@echo "Output:   ./static_output/"
	@echo ""
	@echo "Files generated:"
	@echo "  • Optimized CSS (purged + minified)"
	@echo "  • SEO meta tags (OG, Twitter, Schema)"
	@echo "  • sitemap.xml"
	@echo "  • robots.txt"
	@echo "  • search-index.json"
	@echo ""
	@echo "Next steps:"
	@echo "  make export-full    - Export to leandronsp.com"
	@echo ""

# ======================
# Cleanup Commands
# ======================

clean: dev-down prod-down
	@echo "Cleaning up everything..."
	@echo "Removing development volumes..."
	-docker volume rm curupira_postgres_data 2>/dev/null || true
	-docker volume rm curupira_mix_deps 2>/dev/null || true
	@echo "Removing production volumes..."
	-docker volume rm curupira-pgdata-prod 2>/dev/null || true
	@echo "Removing networks..."
	-docker network rm curupira-prod-local 2>/dev/null || true
	@echo "Removing images..."
	-docker rmi curupira:prod 2>/dev/null || true
	@echo "✓ Cleanup complete"

# ======================
# Backup & Restore
# ======================

AWS_PROFILE ?= personal
S3_BUCKET ?= curupira-backups
S3_PREFIX ?= database/
BACKUP_DIR ?= ./backups
TIMESTAMP := $(shell date +%Y%m%d_%H%M%S)
BACKUP_FILE := curupira_backup_$(TIMESTAMP).sql

backup-create:
	@mkdir -p $(BACKUP_DIR)
	@echo "Creating backup: $(BACKUP_FILE)"
	@docker-compose exec -T db pg_dump -U postgres -d curupira_dev --clean --if-exists > $(BACKUP_DIR)/$(BACKUP_FILE)
	@echo "✓ Backup created: $(BACKUP_DIR)/$(BACKUP_FILE) ($$(du -h $(BACKUP_DIR)/$(BACKUP_FILE) | cut -f1))"

backup-upload:
	@LATEST=$$(ls -t $(BACKUP_DIR)/*.sql 2>/dev/null | head -1); \
	if [ -z "$$LATEST" ]; then echo "Error: no backup found. Run 'make backup-create' first"; exit 1; fi; \
	NAME=$$(basename $$LATEST); \
	echo "Uploading $$NAME to s3://$(S3_BUCKET)/$(S3_PREFIX) (profile: $(AWS_PROFILE))"; \
	AWS_PROFILE=$(AWS_PROFILE) aws s3 cp "$$LATEST" "s3://$(S3_BUCKET)/$(S3_PREFIX)$$NAME" && \
	echo "✓ Uploaded successfully"

backup-download:
	@mkdir -p $(BACKUP_DIR)
	@LATEST=$$(AWS_PROFILE=$(AWS_PROFILE) aws s3 ls s3://$(S3_BUCKET)/$(S3_PREFIX) | grep '.sql$$' | sort | tail -1 | awk '{print $$4}'); \
	if [ -z "$$LATEST" ]; then echo "Error: no backups in s3://$(S3_BUCKET)/$(S3_PREFIX)"; exit 1; fi; \
	echo "Downloading $$LATEST from S3 (profile: $(AWS_PROFILE))"; \
	AWS_PROFILE=$(AWS_PROFILE) aws s3 cp "s3://$(S3_BUCKET)/$(S3_PREFIX)$$LATEST" "$(BACKUP_DIR)/$$LATEST" && \
	echo "✓ Downloaded to $(BACKUP_DIR)/$$LATEST"

backup-restore:
	@LATEST=$$(ls -t $(BACKUP_DIR)/*.sql 2>/dev/null | head -1); \
	if [ -z "$$LATEST" ]; then echo "Error: no backup found. Run 'make backup-download' first"; exit 1; fi; \
	NAME=$$(basename $$LATEST); \
	echo "⚠️  WARNING: This will replace ALL data in curupira_dev"; \
	echo "Backup: $$NAME"; \
	read -p "Continue? [y/N] " -n 1 -r; echo ""; \
	if [[ ! $$REPLY =~ ^[Yy]$$ ]]; then echo "Cancelled"; exit 1; fi; \
	docker-compose exec -T db psql -U postgres -d curupira_dev < "$$LATEST" && \
	echo "✓ Database restored from $$NAME"

backup-full: backup-create backup-upload
	@echo "✓ Full backup complete"

backup-list:
	@echo "S3 backups: s3://$(S3_BUCKET)/$(S3_PREFIX) (profile: $(AWS_PROFILE))"
	@AWS_PROFILE=$(AWS_PROFILE) aws s3 ls s3://$(S3_BUCKET)/$(S3_PREFIX) --human-readable | grep '.sql$$' || echo "No backups found"

# ======================
# Deployment Commands
# ======================

# Configuration (can be overridden via environment variables)
DOCKER_REGISTRY ?= leandronsp/curupira
DOCKER_TAG ?= latest
DEPLOY_HOST ?= $(shell grep "Host curupira" ~/.ssh/config 2>/dev/null && echo "curupira" || echo "")
DEPLOY_KEY ?= ~/.ssh/curupira-user
SECRET_KEY_BASE ?= uUuwfsmH5uHUclBJAsLcd61Y/xyGIaeT0gA48RCOyQhRkMDiD6mSEy2jubMCqdw4

deploy-build:
	@echo "Building production image for AMD64 (linux/amd64)..."
	docker buildx build --platform linux/amd64 --target runner -t $(DOCKER_REGISTRY):$(DOCKER_TAG) --load .
	@echo "✓ Image built: $(DOCKER_REGISTRY):$(DOCKER_TAG)"
	@docker images $(DOCKER_REGISTRY):$(DOCKER_TAG)

deploy-push:
	@echo "Pushing image to Docker Hub..."
	docker push $(DOCKER_REGISTRY):$(DOCKER_TAG)
	@echo "✓ Image pushed: $(DOCKER_REGISTRY):$(DOCKER_TAG)"

deploy: deploy-build deploy-push
	@if [ -z "$(DEPLOY_HOST)" ]; then \
		echo "Error: DEPLOY_HOST not configured"; \
		echo "Set via: export DEPLOY_HOST=user@your-server.com"; \
		echo "Or configure SSH config with 'Host curupira'"; \
		exit 1; \
	fi
	@echo ""
	@echo "=========================================="
	@echo "  Deploying to $(DEPLOY_HOST)"
	@echo "=========================================="
	@echo ""
	@echo "1. Pulling new image..."
	@ssh -i $(DEPLOY_KEY) $(DEPLOY_HOST) "docker pull $(DOCKER_REGISTRY):$(DOCKER_TAG)"
	@echo ""
	@echo "2. Stopping old container..."
	@ssh -i $(DEPLOY_KEY) $(DEPLOY_HOST) "docker stop curupira-app 2>/dev/null || true && docker rm curupira-app 2>/dev/null || true"
	@echo ""
	@echo "3. Starting new container..."
	@ssh -i $(DEPLOY_KEY) $(DEPLOY_HOST) '\
		DB_PASSWORD=$$(cat ~/.curupira_db_password 2>/dev/null || echo "postgres"); \
		docker run -d \
			--name curupira-app \
			--network curupira-prod \
			--restart unless-stopped \
			-p 4000:4000 \
			-e DATABASE_URL="postgresql://postgres:$${DB_PASSWORD}@curupira-postgres:5432/curupira_prod" \
			-e SECRET_KEY_BASE="$(SECRET_KEY_BASE)" \
			-e PHX_SERVER=true \
			-e PHX_HOST="$$(hostname -I | awk \"{print \$$1}\")" \
			-e PORT=4000 \
			-e POOL_SIZE=20 \
			-e MIX_ENV=prod \
			$(DOCKER_REGISTRY):$(DOCKER_TAG)'
	@echo ""
	@echo "4. Waiting for application to start..."
	@sleep 10
	@echo ""
	@echo "5. Checking application health..."
	@ssh -i $(DEPLOY_KEY) $(DEPLOY_HOST) "docker logs curupira-app --tail 20"
	@echo ""
	@echo "=========================================="
	@echo "  ✓ Deployment Complete!"
	@echo "=========================================="
	@echo ""
	@echo "Application should be running at:"
	@ssh -i $(DEPLOY_KEY) $(DEPLOY_HOST) "echo 'http://'$$(hostname -I | awk '{print \$$1}')"
	@echo ""
	@echo "To configure Nginx reverse proxy:"
	@echo "  scp -i $(DEPLOY_KEY) deploy/nginx-site.conf $(DEPLOY_HOST):/tmp/curupira-nginx.conf"
	@echo "  ssh -i $(DEPLOY_KEY) $(DEPLOY_HOST)"
	@echo "  sudo cp /tmp/curupira-nginx.conf /etc/nginx/sites-available/curupira"
	@echo "  sudo ln -sf /etc/nginx/sites-available/curupira /etc/nginx/sites-enabled/"
	@echo "  sudo rm -f /etc/nginx/sites-enabled/default"
	@echo "  sudo nginx -t && sudo systemctl restart nginx"
	@echo ""

# ======================
# Export Commands
# ======================

EXPORT_TARGET ?= ../leandronsp.com

export-markdown:
	@echo "=========================================="
	@echo "  Exporting Articles as Markdown"
	@echo "=========================================="
	@echo ""
	@mkdir -p ./markdown_output
	@docker-compose exec -T web mix export.markdown --output /app/markdown_output
	@echo ""
	@echo "Copying to $(EXPORT_TARGET)/articles..."
	@mkdir -p $(EXPORT_TARGET)/articles
	@cp -r ./markdown_output/* $(EXPORT_TARGET)/articles/
	@ARTICLE_COUNT=$$(ls -1 markdown_output 2>/dev/null | wc -l | tr -d ' '); \
	echo "✓ Exported $$ARTICLE_COUNT markdown files to $(EXPORT_TARGET)/articles"

export-static:
	@echo "=========================================="
	@echo "  Syncing Static Files"
	@echo "=========================================="
	@echo ""
	@EXPORT_TARGET=$(EXPORT_TARGET) ./sync_static.sh

export-full: static-build export-markdown export-static
	@echo ""
	@echo "=========================================="
	@echo "  ✓ Full Export Complete"
	@echo "=========================================="
	@echo ""
	@echo "Target directory: $(EXPORT_TARGET)"
	@echo ""
	@echo "Contents:"
	@echo "  • Static HTML/CSS/JS files (root)"
	@echo "  • Markdown articles (articles/)"
	@echo ""
	@echo "Ready for Cloudflare Pages deployment!"
	@echo ""
