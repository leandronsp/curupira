#!/bin/bash
set -e

echo "Building static site..."
cd /Users/leandronsp/Documents/code/curupira

echo "1. Starting docker-compose..."
docker-compose up -d --wait

echo "2. Building assets..."
docker-compose exec -T web mix assets.build

echo "3. Generating static pages..."
docker-compose exec -T web mix build_static

echo "4. Copying static_output..."
rm -rf static_output
CONTAINER_ID=$(docker-compose ps -q web)
docker cp ${CONTAINER_ID}:/app/static_output ./static_output

echo "✓ Done! Static site in ./static_output"
