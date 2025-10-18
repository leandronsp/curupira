defmodule Mix.Tasks.BuildStatic do
  @moduledoc """
  Build static site for GitHub Pages deployment.

  Usage:
      mix build_static

  This will:
  - Read all published articles from the database
  - Generate static HTML pages (homepage, article pages)
  - Copy compiled assets (CSS, JS, images)
  - Output everything to ./static_output ready for deployment
  """

  use Mix.Task
  require Logger

  @output_dir "static_output"
  @articles_per_page 10
  @site_url "https://leandronsp.com"  # TODO: Make this configurable

  @shortdoc "Build static site for deployment"
  def run(_args) do
    Mix.Task.run("app.start")

    Logger.info("🚀 Starting static site generation...")

    # Clean and create output directory
    File.rm_rf!(@output_dir)
    File.mkdir_p!(@output_dir)
    File.mkdir_p!(Path.join(@output_dir, "articles"))
    File.mkdir_p!(Path.join(@output_dir, "assets"))
    File.mkdir_p!(Path.join(@output_dir, "uploads"))
    File.mkdir_p!(Path.join(@output_dir, "images"))

    # Copy favicon
    File.cp!("priv/static/images/favicon.svg", Path.join([@output_dir, "images", "favicon.svg"]))

    # Build optimized CSS for static site
    build_optimized_css()

    # Get all published articles
    articles = Curupira.Blog.list_articles()
    Logger.info("📄 Found #{length(articles)} articles")

    # Get profile
    profile = Curupira.Blog.get_or_create_profile()

    # Generate pages
    generate_homepage(articles, profile)
    generate_article_pages(articles, profile)

    # Copy assets
    copy_assets()
    copy_uploads()

    # Generate SEO files
    generate_search_index(articles)
    generate_sitemap(articles)
    generate_robots_txt()

    # Create .nojekyll for GitHub Pages
    File.write!(Path.join(@output_dir, ".nojekyll"), "")

    Logger.info("✅ Static site generated in ./#{@output_dir}")
    Logger.info("📦 Deploy this directory to GitHub Pages")
    Logger.info("📖 See STATIC_DEPLOY.md for deployment instructions")
  end

  defp build_optimized_css do
    Logger.info("🎨 Building optimized CSS...")

    # Create temporary config for minified build
    css_output = Path.join([@output_dir, "assets", "css", "app.css"])

    # Use shell to run tailwind with static CSS (no DaisyUI components)
    cmd = """
    _build/tailwind-* \
      -c tailwind.static.config.js \
      -i assets/css/app.static.css \
      -o #{css_output} \
      --minify
    """

    {output, status} = System.cmd("sh", ["-c", cmd], stderr_to_stdout: true)

    if status != 0 do
      Logger.error("Failed to build CSS: #{output}")
      raise "CSS build failed"
    end

    # Get file size for logging
    {:ok, stat} = File.stat(css_output)
    size_kb = Float.round(stat.size / 1024, 1)
    Logger.info("  ✓ CSS optimized: #{size_kb}KB")
  end

  defp generate_homepage(articles, profile) do
    Logger.info("🏠 Generating homepage...")

    html = render_homepage(articles, profile)
    File.write!(Path.join(@output_dir, "index.html"), html)
  end

  defp generate_article_pages(articles, profile) do
    Logger.info("📝 Generating article pages...")

    Enum.each(articles, fn article ->
      slug = article.slug
      html = render_article(article, profile)
      File.write!(Path.join([@output_dir, "articles", "#{slug}.html"]), html)
      Logger.info("  ✓ #{slug}")
    end)
  end

  defp copy_assets do
    Logger.info("📦 Copying and minifying JavaScript...")

    priv_static = "priv/static"

    # Minify and copy static JavaScript files
    ["static-theme.js", "static-search.js", "static-pagination.js"]
    |> Enum.each(fn file ->
      src = Path.join(priv_static, file)
      dest = Path.join(@output_dir, file)

      if File.exists?(src) do
        # Minify JS using esbuild binary (use wildcard pattern for cross-platform)
        cmd = "_build/esbuild-* #{src} --minify --outfile=#{dest}"
        {output, status} = System.cmd("sh", ["-c", cmd], stderr_to_stdout: true)

        if status != 0 do
          Logger.warning("Failed to minify #{file}, copying original: #{output}")
          File.cp!(src, dest)
        else
          {:ok, stat} = File.stat(dest)
          size_kb = Float.round(stat.size / 1024, 1)
          Logger.info("  ✓ #{file} minified: #{size_kb}KB")
        end
      end
    end)
  end

  defp copy_uploads do
    Logger.info("🖼️  Copying uploaded images...")

    uploads_dir = "priv/static/uploads"

    if File.exists?(uploads_dir) do
      File.cp_r!(
        uploads_dir,
        Path.join(@output_dir, "uploads")
      )
    end
  end

  defp generate_search_index(articles) do
    Logger.info("🔍 Generating search index...")

    index = Enum.map(articles, fn article ->
      %{
        slug: article.slug,
        title: article.title,
        tags: article.tags || [],
        language: article.language || "en"
      }
    end)

    json = Jason.encode!(index)
    File.write!(Path.join(@output_dir, "search-index.json"), json)
  end

  defp generate_sitemap(articles) do
    Logger.info("🗺️  Generating sitemap.xml...")

    urls = [
      sitemap_url("/", "1.0", "daily"),
      # Add article URLs
      Enum.map(articles, fn article ->
        date = if article.published_at do
          Calendar.strftime(article.published_at, "%Y-%m-%d")
        else
          Calendar.strftime(article.inserted_at, "%Y-%m-%d")
        end
        sitemap_url("/articles/#{article.slug}.html", "0.8", "monthly", date)
      end)
    ]
    |> List.flatten()
    |> Enum.join("\n  ")

    sitemap = """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      #{urls}
    </urlset>
    """

    File.write!(Path.join(@output_dir, "sitemap.xml"), sitemap)
  end

  defp sitemap_url(path, priority, changefreq, lastmod \\ nil) do
    lastmod_tag = if lastmod do
      "<lastmod>#{lastmod}</lastmod>"
    else
      ""
    end

    """
    <url>
      <loc>#{@site_url}#{path}</loc>
      <priority>#{priority}</priority>
      <changefreq>#{changefreq}</changefreq>
      #{lastmod_tag}
    </url>
    """
  end

  defp generate_robots_txt do
    Logger.info("🤖 Generating robots.txt...")

    robots = """
    User-agent: *
    Allow: /

    Sitemap: #{@site_url}/sitemap.xml
    """

    File.write!(Path.join(@output_dir, "robots.txt"), robots)
  end

  defp render_homepage(articles, profile) do
    total_pages = ceil(length(articles) / @articles_per_page)

    # SEO metadata for homepage
    site_description = profile.bio || "Personal blog about software development, programming, and technology"

    """
    <!DOCTYPE html>
    <html lang="pt-BR" data-theme="light">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>#{profile.name || "Blog"}</title>
      <link rel="icon" type="image/svg+xml" href="/images/favicon.svg">

      <!-- SEO Meta Tags -->
      <meta name="description" content="#{site_description}">
      <meta name="author" content="#{profile.name || ""}">
      <link rel="canonical" href="#{@site_url}/">

      <!-- Open Graph / Facebook -->
      <meta property="og:type" content="website">
      <meta property="og:url" content="#{@site_url}/">
      <meta property="og:title" content="#{profile.name || "Blog"}">
      <meta property="og:description" content="#{site_description}">
      <meta property="og:site_name" content="#{profile.name || "Blog"}">

      <!-- JSON-LD Schema -->
      <script type="application/ld+json">
      {
        "@context": "https://schema.org",
        "@type": "Blog",
        "name": "#{profile.name || "Blog"}",
        "description": "#{String.replace(site_description, "\"", "\\\"")}"#{if profile.name do
          ~s(,\n        "author": {\n          "@type": "Person",\n          "name": "#{profile.name}"\n        })
        else
          ""
        end}
      }
      </script>

      <link rel="preload" href="/assets/css/app.css" as="style">
      <script>
        // Prevent FOUC (Flash of Unstyled Content) by setting theme before CSS loads
        (function() {
          const theme = localStorage.getItem('theme') || 'light';
          document.documentElement.setAttribute('data-theme', theme);
        })();
      </script>
      <link rel="stylesheet" href="/assets/css/app.css">
      <style>
        /* Softer dark theme colors */
        [data-theme="dark"] {
          --base-100: #2a2f3a;
          --base-200: #232831;
          --base-300: #1e222a;
          --base-content: #e8eaed;
        }
        [data-theme="dark"] .article-card {
          background-color: #2f3542;
          border-color: #3d4454;
        }
        [data-theme="dark"] .article-card:hover {
          border-color: #4a5568;
        }
        [data-theme="dark"] .prose {
          color: #e8eaed;
        }
        [data-theme="dark"] .prose h1,
        [data-theme="dark"] .prose h2,
        [data-theme="dark"] .prose h3,
        [data-theme="dark"] .prose h4 {
          color: #f0f2f5;
        }
        [data-theme="dark"] .prose a {
          color: #8fb4ff;
        }
        [data-theme="dark"] .prose code {
          background-color: #3d4454;
          color: #f0f2f5;
        }
        [data-theme="dark"] .prose pre {
          background-color: #1e222a;
          border: 1px solid #3d4454;
        }
        [data-theme="dark"] input {
          background-color: #2f3542;
          border-color: #3d4454;
          color: #e8eaed;
        }
        [data-theme="dark"] input::placeholder {
          color: #9ca3af;
        }
      </style>
    </head>
    <body class="min-h-screen bg-base-200">
      <div class="container mx-auto px-6 py-8 max-w-7xl">
        <div class="grid grid-cols-1 lg:grid-cols-12 gap-8">
          <!-- Sidebar - Profile Section -->
          <style>
            @media (min-width: 1024px) {
              .sidebar-column {
                position: sticky;
                top: 2rem;
                align-self: start;
              }
            }
          </style>
          <div class="lg:col-span-4 sidebar-column">
            <div class="space-y-6">
              <h1 class="text-4xl font-bold">#{profile.name || "Blog"}</h1>
              #{if profile.bio do
                ~s(<p class="text-lg text-base-content/85 whitespace-pre-wrap">#{profile.bio}</p>)
              else
                ""
              end}

              <div class="space-y-4 mt-4">
                <div class="flex items-center gap-3">
                  <a href="https://linkedin.com/in/leandronsp" target="_blank" rel="noopener noreferrer" class="inline-flex items-center justify-center w-10 h-10 rounded-lg bg-base-200 hover:bg-primary hover:text-primary-content transition-colors group" title="LinkedIn">
                    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                      <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/>
                    </svg>
                  </a>
                  <a href="https://github.com/leandronsp" target="_blank" rel="noopener noreferrer" class="inline-flex items-center justify-center w-10 h-10 rounded-lg bg-base-200 hover:bg-primary hover:text-primary-content transition-colors group" title="GitHub">
                    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                      <path fill-rule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" clip-rule="evenodd"/>
                    </svg>
                  </a>
                </div>

                <div class="flex flex-col gap-2">
                  <a href="https://web101.leandronsp.com" target="_blank" rel="noopener noreferrer" class="inline-flex items-center gap-2 text-base-content/80 hover:text-primary transition-colors group">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-base-content/40 group-hover:text-primary transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                    </svg>
                    <span class="inline-flex items-center gap-2">
                      <span>Web 101</span>
                      <span>🇧🇷</span>
                    </span>
                  </a>
                  <a href="https://concorrencia101.leandronsp.com" target="_blank" rel="noopener noreferrer" class="inline-flex items-center gap-2 text-base-content/80 hover:text-primary transition-colors group">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-base-content/40 group-hover:text-primary transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                    </svg>
                    <span class="inline-flex items-center gap-2">
                      <span>Concorrência 101</span>
                      <span>🇧🇷</span>
                    </span>
                  </a>
                  <a href="https://aws101.leandronsp.com" target="_blank" rel="noopener noreferrer" class="inline-flex items-center gap-2 text-base-content/80 hover:text-primary transition-colors group">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-base-content/40 group-hover:text-primary transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                    </svg>
                    <span class="inline-flex items-center gap-2">
                      <span>AWS 101</span>
                      <span>🇧🇷</span>
                    </span>
                  </a>
                </div>
              </div>
            </div>
          </div>

          <!-- Main Content - Articles List -->
          <div class="lg:col-span-8">
            <div class="flex items-center gap-2 mb-2">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-base-content/40" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z" />
              </svg>
              <span class="text-sm text-base-content/50 font-mono" id="page-indicator">
                <span id="current-page">1</span> / <span id="total-pages">#{total_pages}</span>
              </span>
            </div>

            <div class="flex flex-wrap items-center gap-3 mb-6">
              <div class="w-full md:flex-1 md:max-w-lg">
                <div class="relative">
                  <input
                    type="text"
                    id="search-input"
                    placeholder="Search articles..."
                    class="w-full h-10 sm:h-12 pr-10 sm:pr-12 text-sm sm:text-base bg-base-100 border-2 border-base-300 rounded-lg px-3 sm:px-4 transition-all duration-200 ease-in-out focus:border-primary focus:outline-none hover:border-base-content/30 hover:shadow-sm"
                    autocomplete="off"
                  />
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 sm:h-6 sm:w-6 absolute right-3 sm:right-4 top-1/2 -translate-y-1/2 text-base-content/40" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                  </svg>
                </div>
              </div>

              <div class="flex items-center gap-2 sm:gap-3">
                <span class="text-xs sm:text-sm text-base-content/80 font-medium whitespace-nowrap">Filter:</span>
                <div class="flex rounded-lg border-2 border-base-300 overflow-hidden">
                  <button class="lang-filter-btn px-2 sm:px-3 py-1 sm:py-1.5 text-xs sm:text-sm font-medium transition-colors bg-blue-600 text-white" data-lang="all" onclick="setLanguageFilter('all')">All</button>
                  <button class="lang-filter-btn px-2 sm:px-3 py-1 sm:py-1.5 text-xs sm:text-sm font-medium transition-colors bg-base-100 hover:bg-base-200 border-l-2 border-base-300" data-lang="pt" onclick="setLanguageFilter('pt')">🇧🇷 PT</button>
                  <button class="lang-filter-btn px-2 sm:px-3 py-1 sm:py-1.5 text-xs sm:text-sm font-medium transition-colors bg-base-100 hover:bg-base-200 border-l-2 border-base-300" data-lang="en" onclick="setLanguageFilter('en')">🇺🇸 EN</button>
                </div>
              </div>

              <button
                type="button"
                id="theme-toggle"
                class="inline-flex items-center justify-center rounded-full h-10 w-10 sm:h-12 sm:w-12 hover:bg-base-content/10 transition-colors flex-shrink-0"
                title="Toggle theme"
              >
                <svg xmlns="http://www.w3.org/2000/svg" class="sun-icon h-5 w-5 sm:h-6 sm:w-6 hidden" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
                </svg>
                <svg xmlns="http://www.w3.org/2000/svg" class="moon-icon h-5 w-5 sm:h-6 sm:w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
                </svg>
              </button>
            </div>

            <div class="space-y-4" id="articles-container">
              #{render_article_list(articles)}
            </div>

            <div id="no-results" class="hidden text-center text-base-content/85 py-16">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 text-base-content/50 mb-4 mx-auto" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <h3 class="text-lg font-semibold text-base-content/85 mb-2">No results found</h3>
              <p class="text-base-content/50">Try a different search</p>
            </div>

            <div id="pagination-container" class="mt-8"></div>
          </div>
        </div>
      </div>

      <script src="/static-theme.js" defer></script>
      <script src="/static-search.js" defer></script>
      <script src="/static-pagination.js" defer></script>

      <!-- Lazy load Google Analytics after page is interactive -->
      <script>
        (function() {
          function loadGTM() {
            window.dataLayer = window.dataLayer || [];
            function gtag(){dataLayer.push(arguments);}
            gtag('js', new Date());
            gtag('config', 'G-0Y5RNLZMKN');

            var script = document.createElement('script');
            script.async = true;
            script.src = 'https://www.googletagmanager.com/gtag/js?id=G-0Y5RNLZMKN';
            document.head.appendChild(script);
          }

          // Load after page is idle, or after 2 seconds as fallback
          if ('requestIdleCallback' in window) {
            requestIdleCallback(loadGTM, { timeout: 2000 });
          } else {
            setTimeout(loadGTM, 2000);
          }
        })();
      </script>
    </body>
    </html>
    """
  end

  defp render_article(article, profile) do
    {:ok, html_content} = Curupira.Markdown.Parser.to_html(article.content || "")

    published_date = if article.published_at do
      Calendar.strftime(article.published_at, "%d %b %Y")
    else
      Calendar.strftime(article.inserted_at, "%d %b %Y")
    end

    # SEO metadata
    description = article.content
      |> String.replace(~r/<[^>]*>/, "")  # Remove HTML tags
      |> String.slice(0..160)
      |> String.trim()

    article_url = "#{@site_url}/articles/#{article.slug}.html"

    iso_date = if article.published_at do
      DateTime.to_iso8601(article.published_at)
    else
      DateTime.to_iso8601(article.inserted_at)
    end

    """
    <!DOCTYPE html>
    <html lang="pt-BR" data-theme="light">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>#{article.title} - #{profile.name || "Blog"}</title>
      <link rel="icon" type="image/svg+xml" href="/images/favicon.svg">

      <!-- SEO Meta Tags -->
      <meta name="description" content="#{description}">
      <meta name="author" content="#{profile.name || ""}">
      <link rel="canonical" href="#{article_url}">

      <!-- Open Graph / Facebook -->
      <meta property="og:type" content="article">
      <meta property="og:url" content="#{article_url}">
      <meta property="og:title" content="#{article.title}">
      <meta property="og:description" content="#{description}">
      <meta property="og:site_name" content="#{profile.name || "Blog"}">
      #{if article.published_at, do: ~s(<meta property="article:published_time" content="#{iso_date}">), else: ""}
      #{if article.tags && length(article.tags) > 0 do
        Enum.map_join(article.tags, "\n      ", fn tag ->
          ~s(<meta property="article:tag" content="#{tag}">)
        end)
      else
        ""
      end}

      <!-- JSON-LD Schema -->
      <script type="application/ld+json">
      {
        "@context": "https://schema.org",
        "@type": "BlogPosting",
        "headline": "#{String.replace(article.title, "\"", "\\\"")}",
        "datePublished": "#{iso_date}",
        "author": {
          "@type": "Person",
          "name": "#{profile.name || ""}"
        },
        "description": "#{String.replace(description, "\"", "\\\"")}"#{if article.tags && length(article.tags) > 0 do
          ~s(,\n        "keywords": "#{Enum.join(article.tags, ", ")}")
        else
          ""
        end}
      }
      </script>

      <link rel="preload" href="/assets/css/app.css" as="style">
      <script>
        // Prevent FOUC (Flash of Unstyled Content) by setting theme before CSS loads
        (function() {
          const theme = localStorage.getItem('theme') || 'light';
          document.documentElement.setAttribute('data-theme', theme);
        })();
      </script>
      <link rel="stylesheet" href="/assets/css/app.css">
      <style>
        /* Softer dark theme colors */
        [data-theme="dark"] {
          --base-100: #2a2f3a;
          --base-200: #232831;
          --base-300: #1e222a;
          --base-content: #e8eaed;
        }
        [data-theme="dark"] .article-card {
          background-color: #2f3542;
          border-color: #3d4454;
        }
        [data-theme="dark"] .article-card:hover {
          border-color: #4a5568;
        }
        [data-theme="dark"] .prose {
          color: #e8eaed;
        }
        [data-theme="dark"] .prose h1,
        [data-theme="dark"] .prose h2,
        [data-theme="dark"] .prose h3,
        [data-theme="dark"] .prose h4 {
          color: #f0f2f5;
        }
        [data-theme="dark"] .prose a {
          color: #8fb4ff;
        }
        [data-theme="dark"] .prose code {
          background-color: #3d4454;
          color: #f0f2f5;
        }
        [data-theme="dark"] .prose pre {
          background-color: #1e222a;
          border: 1px solid #3d4454;
        }
        [data-theme="dark"] input {
          background-color: #2f3542;
          border-color: #3d4454;
          color: #e8eaed;
        }
        [data-theme="dark"] input::placeholder {
          color: #9ca3af;
        }
        /* Article card styling */
        article {
          background-color: transparent;
          border: none;
          border-radius: 0.5rem;
          padding: 2rem;
        }
        [data-theme="dark"] article {
          background-color: transparent;
        }
        /* Article container has its own background */
        .article-container {
          background-color: oklch(98% 0.005 80); /* base-100 light */
          border-radius: 0.5rem;
        }
        [data-theme="dark"] .article-container {
          background-color: oklch(30% 0.015 252); /* base-100 dark */
        }
      </style>
    </head>
    <body class="min-h-screen bg-base-200">
      <div class="border-b border-base-300 bg-base-200 sticky top-0 z-10">
        <div class="container mx-auto px-4 py-4 flex items-center justify-between max-w-8xl">
          <a href="/" class="inline-flex items-center gap-2 px-4 py-2 rounded-lg hover:bg-base-content/10 transition-colors">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            Back to articles
          </a>

          <button
            type="button"
            id="theme-toggle"
            class="inline-flex items-center justify-center px-4 py-2 rounded-lg hover:bg-base-content/10 transition-colors"
            title="Toggle theme"
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="sun-icon h-5 w-5 hidden" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
            </svg>
            <svg xmlns="http://www.w3.org/2000/svg" class="moon-icon h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
            </svg>
          </button>
        </div>
      </div>

      <div class="article-container py-8">
        <article class="container mx-auto px-4 max-w-8xl">
          <h1 class="text-5xl font-bold mb-6">#{article.title}</h1>

          <div class="flex flex-wrap items-center gap-3 mb-8 text-base text-base-content/85">
            <div class="flex items-center gap-1.5">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
              </svg>
              <span>Published #{published_date}</span>
            </div>

            #{if article.tags && length(article.tags) > 0 do
              """
              <div class="flex items-center gap-1.5">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
                </svg>
                <div class="flex gap-2 flex-wrap">
                  #{Enum.map_join(article.tags, "", fn tag ->
                    ~s(<span class="inline-flex items-center px-3 py-1 text-sm border border-base-content/25 rounded-full">#{tag}</span>)
                  end)}
                </div>
              </div>
              """
            else
              ""
            end}
          </div>

          <div class="prose prose-lg max-w-none">
            #{html_content}
          </div>
        </article>
      </div>

      <script src="/static-theme.js" defer></script>

      <!-- Lazy load Google Analytics after page is interactive -->
      <script>
        (function() {
          function loadGTM() {
            window.dataLayer = window.dataLayer || [];
            function gtag(){dataLayer.push(arguments);}
            gtag('js', new Date());
            gtag('config', 'G-0Y5RNLZMKN');

            var script = document.createElement('script');
            script.async = true;
            script.src = 'https://www.googletagmanager.com/gtag/js?id=G-0Y5RNLZMKN';
            document.head.appendChild(script);
          }

          // Load after page is idle, or after 2 seconds as fallback
          if ('requestIdleCallback' in window) {
            requestIdleCallback(loadGTM, { timeout: 2000 });
          } else {
            setTimeout(loadGTM, 2000);
          }
        })();
      </script>
    </body>
    </html>
    """
  end

  defp render_article_list(articles) do
    articles
    |> Enum.sort_by(& &1.published_at || &1.inserted_at, {:desc, DateTime})
    |> Enum.map(fn article ->
      published_date = if article.published_at do
        Calendar.strftime(article.published_at, "%d %b %Y")
      else
        Calendar.strftime(article.inserted_at, "%d %b %Y")
      end

      """
      <div class="article-card rounded-lg border border-base-300 hover:border-base-content/20 transition-colors cursor-pointer min-h-[140px] sm:h-[160px] bg-base-100"
           data-slug="#{article.slug}"
           data-title="#{String.downcase(article.title)}"
           data-tags="#{String.downcase(Enum.join(article.tags || [], " "))}"
           onclick="window.location.href='/articles/#{article.slug}.html'">
        <div class="p-4 sm:p-6 h-full">
          <div class="flex items-start gap-3 sm:gap-4 h-full">
            <div class="flex-1 min-w-0 flex flex-col h-full">
              <h2 class="text-base sm:text-xl font-bold text-base-content mb-2 sm:mb-3 line-clamp-2">
                #{article.title}
              </h2>

              <div class="mt-auto space-y-1.5 sm:space-y-2">
                <div class="flex flex-wrap items-center gap-2 sm:gap-3 text-xs sm:text-sm text-base-content/85">
                  <div class="flex items-center gap-1 sm:gap-1.5">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3 sm:h-4 sm:w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                    <span class="truncate">#{published_date}</span>
                  </div>
                  <div class="flex items-center gap-1">
                    <span>•</span>
                    <span class="text-base sm:text-lg">#{Curupira.Blog.Article.language_flag(article)}</span>
                  </div>
                </div>

                #{if article.tags && length(article.tags) > 0 do
                  max_tags = 2
                  """
                  <div class="flex items-center gap-1 sm:gap-1.5 text-xs sm:text-sm text-base-content/85">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3 sm:h-4 sm:w-4 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
                    </svg>
                    <div class="flex gap-1 flex-wrap">
                      #{Enum.take(article.tags, max_tags) |> Enum.map_join("", fn tag ->
                        ~s(<span class="inline-flex items-center px-1.5 sm:px-2 py-0.5 text-xs border border-base-content/25 rounded-full whitespace-nowrap truncate max-w-[80px] sm:max-w-none">#{tag}</span>)
                      end)}
                      #{if length(article.tags) > max_tags do
                        ~s(<span class="inline-flex items-center px-1.5 sm:px-2 py-0.5 text-xs border border-base-content/25 rounded-full">+#{length(article.tags) - max_tags}</span>)
                      else
                        ""
                      end}
                    </div>
                  </div>
                  """
                else
                  ""
                end}
              </div>
            </div>
          </div>
        </div>
      </div>
      """
    end)
    |> Enum.join("\n")
  end
end
