#!/bin/bash
set -e

echo "🔨 Building static site..."

# Compile assets first
echo "📦 Compiling assets..."
mix assets.build

# Run static build task
echo "🚀 Generating static pages..."
mix build_static

echo ""
echo "✅ Done! Static site generated in ./static_output"
echo ""
echo "To test locally:"
echo "  cd static_output && python3 -m http.server 8000"
echo "  Then open http://localhost:8000"
echo ""
echo "To deploy to GitHub Pages:"
echo "  1. Create a new repo or use existing one"
echo "  2. Copy contents of static_output/ to repo"
echo "  3. Enable GitHub Pages in repo settings (source: main branch)"
echo "  4. Push and visit https://USERNAME.github.io/REPO"
