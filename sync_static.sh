#!/usr/bin/env bash
# Sync static_output to leandronsp.com repository

set -e

TARGET_DIR="${EXPORT_TARGET:-../leandronsp.com}"
SOURCE_DIR="./static_output"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Syncing static files to ${TARGET_DIR}${NC}"

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: ${SOURCE_DIR} does not exist. Run 'make static-build' first."
    exit 1
fi

# Create target directory if it doesn't exist
mkdir -p "${TARGET_DIR}"

# Sync static files (preserve markdown files in articles/)
echo "  → Syncing HTML, CSS, JS files..."
rsync -av --delete \
    --exclude 'articles/*.md' \
    "${SOURCE_DIR}/" \
    "${TARGET_DIR}/"

echo -e "${GREEN}✓ Static files synced to ${TARGET_DIR}${NC}"
