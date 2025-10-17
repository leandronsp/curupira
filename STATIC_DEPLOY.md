# Static Site Deployment

This guide explains how to generate and deploy a static version of your blog to GitHub Pages (or any static hosting).

## What gets generated

The static build creates HTML/CSS/JS files with:
- ✅ Homepage with article list and bio
- ✅ Individual article pages (read-only, no editor)
- ✅ Client-side search (instant, no server needed)
- ✅ Dark/light theme toggle (saved in localStorage)
- ✅ Responsive design (same look & feel)
- ✅ All uploaded images
- ❌ Admin features (no delete buttons, no editor)

## Quick Start

### 1. Build static site locally

```bash
# Option 1: Using the script
chmod +x build_static.sh
./build_static.sh

# Option 2: Manual steps
mix assets.build
mix build_static
```

This generates `./static_output/` directory with all files.

### 2. Test locally

```bash
cd static_output
python3 -m http.server 8000
```

Open http://localhost:8000 to preview.

### 3. Deploy to GitHub Pages

#### Option A: Manual deployment

1. Create a new GitHub repo (or use existing)
2. Copy contents of `static_output/` to the repo
3. Push to GitHub
4. Enable GitHub Pages in repo settings:
   - Go to Settings → Pages
   - Source: Deploy from branch
   - Branch: `main` (or `master`)
   - Folder: `/` (root)
5. Visit `https://USERNAME.github.io/REPO`

#### Option B: Automatic deployment (GitHub Actions)

1. Push this project to GitHub
2. Add secret `DATABASE_URL` in repo settings (Settings → Secrets)
3. Enable GitHub Pages:
   - Go to Settings → Pages
   - Source: GitHub Actions
4. Trigger deployment:
   - Push changes to main/master branch, OR
   - Go to Actions → Deploy Static Site → Run workflow

Your site will auto-deploy on every push!

## How it works

### Build process

1. **Mix task** (`lib/mix/tasks/build_static.ex`):
   - Reads articles from database
   - Generates HTML for each page
   - Copies compiled assets (CSS, JS)
   - Copies uploaded images

2. **Client-side JS**:
   - `static-theme.js`: Theme toggle (localStorage)
   - `static-search.js`: Live search filtering

3. **Output structure**:
   ```
   static_output/
   ├── index.html              # Homepage
   ├── articles/
   │   ├── my-first-post.html
   │   └── another-post.html
   ├── assets/
   │   ├── app.css
   │   └── app.js
   ├── uploads/                # Your images
   ├── static-theme.js
   └── static-search.js
   ```

### URL structure

- Homepage: `/` or `/index.html`
- Article: `/articles/SLUG.html`
- Images: `/uploads/filename.png`

## Updating the site

After adding/editing articles in the admin:

```bash
# Rebuild static files
./build_static.sh

# Deploy updated files
cd static_output
git add .
git commit -m "update articles"
git push
```

Or just push to trigger GitHub Actions auto-deployment.

## Customization

Edit `lib/mix/tasks/build_static.ex` to customize:
- HTML structure
- CSS classes
- Metadata (SEO tags)
- Analytics scripts

## Free hosting options

- **GitHub Pages**: Free, unlimited bandwidth
- **Netlify**: Free tier, auto-deploy from git
- **Vercel**: Free tier, edge CDN
- **Cloudflare Pages**: Free, unlimited bandwidth

All work with the generated `static_output/` directory.

## Troubleshooting

**Assets not loading?**
- Run `mix assets.build` before `mix build_static`
- Check that `priv/static/assets/` exists

**Images not showing?**
- Check that `priv/static/uploads/` has your images
- Images are copied to `static_output/uploads/`

**Search not working?**
- Clear browser cache
- Check browser console for errors

**GitHub Actions failing?**
- Add `DATABASE_URL` secret in repo settings
- Check Actions logs for errors
