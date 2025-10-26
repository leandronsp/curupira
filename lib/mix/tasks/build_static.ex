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
    articles = Curupira.Blog.list_published_articles()
    Logger.info("📄 Found #{length(articles)} published articles")

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
    ["static-theme.js", "static-filters.js", "static-search.js", "static-pagination.js", "static-giscus.js"]
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

    # Generate article index with snippets
    index = Enum.map(articles, fn article ->
      # Generate plain text snippet for search (no HTML formatting)
      {:ok, html} = Curupira.Markdown.Parser.to_html(article.content || "")

      snippet = html
        |> String.replace(~r/<[^>]*>/, "")   # Remove all HTML tags
        |> String.replace(~r/\s+/, " ")      # Normalize whitespace
        |> String.trim()
        |> String.slice(0..200)
        |> then(fn s ->
          content_length = String.length(article.content || "")
          if content_length > 200, do: s <> "...", else: s
        end)

      # Normalize tags for consistent filtering
      normalized_tags = (article.tags || [])
        |> Enum.map(&normalize_tag/1)
        |> Enum.uniq()

      %{
        slug: article.slug,
        title: article.title,
        tags: normalized_tags,
        language: article.language || "en",
        snippet: snippet,
        published_at: article.published_at
      }
    end)

    json = Jason.encode!(index)
    File.write!(Path.join(@output_dir, "search-index.json"), json)

    # Generate curated tags with semantic grouping
    curated_tags = generate_curated_tags(articles)
    tags_json = Jason.encode!(curated_tags)
    File.write!(Path.join(@output_dir, "tags.json"), tags_json)

    total_tags = curated_tags
      |> Enum.flat_map(fn category -> category.tags end)
      |> length()
    Logger.info("  ✓ Generated #{total_tags} curated tags in #{length(curated_tags)} categories")
  end

  # Curated tags with semantic grouping
  defp generate_curated_tags(articles) do
    # Normalize tags: k8s -> kubernetes, shellscript/bash merge, etc.
    normalized_articles = Enum.map(articles, fn article ->
      normalized_tags = (article.tags || [])
        |> Enum.map(&normalize_tag/1)
        |> Enum.uniq()

      %{article | tags: normalized_tags}
    end)

    # Count normalized tags
    tag_counts = normalized_articles
      |> Enum.flat_map(fn article -> article.tags end)
      |> Enum.frequencies()

    # Define curated categories with semantic grouping
    [
      %{
        category: "Languages",
        icon: "💻",
        tags: build_tag_list(["ruby", "javascript", "rust", "go", "haskell", "bash", "assembly"], tag_counts)
      },
      %{
        category: "Infrastructure",
        icon: "🚀",
        tags: build_tag_list(["kubernetes", "docker", "linux", "aws"], tag_counts)
      },
      %{
        category: "Data",
        icon: "🗄️",
        tags: build_tag_list(["postgres", "sql"], tag_counts)
      },
      %{
        category: "Tools",
        icon: "🔧",
        tags: build_tag_list(["git"], tag_counts)
      }
    ]
    |> Enum.filter(fn category -> length(category.tags) > 0 end)
  end

  defp normalize_tag(tag) do
    tag_lower = String.downcase(tag)

    cond do
      tag_lower == "k8s" -> "kubernetes"
      tag_lower == "shellscript" -> "bash"
      tag_lower == "postgresql" -> "postgres"
      tag_lower == "js" -> "javascript"
      tag_lower == "rubyonrails" -> "rails"
      true -> tag_lower
    end
  end

  defp build_tag_list(tag_names, tag_counts) do
    tag_names
      |> Enum.map(fn tag ->
        count = Map.get(tag_counts, tag, 0)
        if count > 0 do
          %{tag: tag, count: count}
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(fn %{count: count} -> -count end)
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

      <!-- Google Fonts - Nunito for name, Caveat for bio -->
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
      <link href="https://fonts.googleapis.com/css2?family=Nunito:wght@700;800&family=Caveat:wght@500;700&display=swap" rel="stylesheet">

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
        /* Force scrollbar to always be visible to prevent layout shift */
        html {
          overflow-y: scroll;
        }

        /* Softer dark theme colors */
        [data-theme="dark"] {
          --base-100: #2a2f3a;
          --base-200: #232831;
          --base-300: #1e222a;
          --base-content: #e8eaed;
        }
        [data-theme="dark"] .article-card {
          background-color: transparent;
          border-color: #3d4454;
        }
        [data-theme="dark"] .article-card:hover {
          border-color: #4a5568;
        }
        /* Keep pinned article with background for prominence in dark theme - lighter pastel */
        [data-theme="dark"] .pinned-article {
          background-color: #3a4050 !important;
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
        /* Language switcher dark theme styling */
        [data-theme="dark"] .lang-switcher-bg {
          background-color: rgba(59, 130, 246, 0.15) !important;
          border-color: rgba(59, 130, 246, 0.3) !important;
        }
        /* Blog name styling */
        .blog-name {
          font-family: 'Nunito', sans-serif;
          font-weight: 800;
          letter-spacing: -0.02em;
        }
        /* Intro text styling */
        .intro-text {
          font-family: 'Caveat', cursive;
          font-weight: 600;
          color: #6b7280; /* Darker pastel gray for light theme */
        }
        [data-theme="dark"] .intro-text {
          color: #d4d4d8; /* Lighter pastel gray for dark theme */
        }
      </style>
    </head>
    <body class="min-h-screen bg-base-100">
      <!-- Fixed Header -->
      <header class="sticky top-0 z-50 bg-base-100 border-b border-base-300 shadow-sm">
        <div class="container mx-auto px-4 sm:px-6 py-4 max-w-6xl">
          <!-- All screens: Name + Social Icons on top | Bio below -->

          <div class="flex flex-col gap-2 mb-4">
            <!-- Name + Social Icons (all screens) -->
            <div class="flex items-center gap-3">
              <h1 class="blog-name text-2xl sm:text-3xl font-bold text-base-content flex-shrink-0">#{profile.name || "Blog"}</h1>
              <div class="flex items-center gap-2">
                <a href="https://linkedin.com/in/leandronsp" target="_blank" rel="noopener noreferrer" class="text-base-content/60 hover:text-primary transition-colors" title="LinkedIn">
                  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/></svg>
                </a>
                <a href="https://github.com/leandronsp" target="_blank" rel="noopener noreferrer" class="text-base-content/60 hover:text-primary transition-colors" title="GitHub">
                  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path fill-rule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" clip-rule="evenodd"/></svg>
                </a>
                <button id="theme-toggle" class="text-base-content/60 hover:text-primary transition-colors" title="Toggle theme">
                  <svg xmlns="http://www.w3.org/2000/svg" class="sun-icon h-5 w-5 hidden" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" /></svg>
                  <svg xmlns="http://www.w3.org/2000/svg" class="moon-icon h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" /></svg>
                </button>
              </div>
            </div>

            <!-- Bio: plain on small, with guide links inline on medium/large -->
            <p class="intro-text text-xl lg:text-2xl leading-tight">
              <span class="md:hidden">Software Developer 15+ years programming and counting.</span>
              <span class="hidden md:inline">Software Developer 15+ years programming and counting. See my guides at
                <a href="https://web101.leandronsp.com" target="_blank" rel="noopener noreferrer" class="underline decoration-2 hover:opacity-80 transition-opacity cursor-pointer">web101</a>,
                <a href="https://concorrencia101.leandronsp.com" target="_blank" rel="noopener noreferrer" class="underline decoration-2 hover:opacity-80 transition-opacity cursor-pointer">concorrencia101</a>,
                <a href="https://aws101.leandronsp.com" target="_blank" rel="noopener noreferrer" class="underline decoration-2 hover:opacity-80 transition-opacity cursor-pointer">aws101</a>
              </span>
            </p>
          </div>

          <!-- Small: Language only | Medium: Search + Language | Large: Search + Language -->
          <div class="flex gap-4 items-center">
            <!-- Search (medium and up) -->
            <div class="hidden md:block relative flex-1 max-w-2xl">
              <input
                type="text"
                id="search-input"
                placeholder="Search articles..."
                class="w-full h-12 pl-12 pr-12 text-base bg-base-200 border-2 border-base-300 rounded-full transition-all focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                autocomplete="off"
              />
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 absolute left-4 top-1/2 -translate-y-1/2 text-base-content/40" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
              <button
                id="search-clear"
                class="hidden absolute right-4 top-1/2 -translate-y-1/2 text-base-content/40 hover:text-base-content transition-colors"
                title="Clear search"
              >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>

              <!-- Search Results Dropdown -->
              <div id="search-results" class="hidden absolute top-full mt-2 w-full bg-base-100 border-2 border-base-300 rounded-2xl shadow-2xl max-h-[500px] overflow-y-auto z-50 p-3">
                <!-- Results will be inserted here by JavaScript -->
              </div>
            </div>

            <!-- Language Switcher -->
            <div class="lang-switcher-bg flex gap-0 bg-blue-50/80 border border-blue-100 rounded-full p-1 md:ml-auto shadow-sm">
              <button class="lang-filter-btn px-4 py-1.5 text-sm font-medium rounded-full transition-all whitespace-nowrap cursor-pointer bg-primary text-white" data-lang="all" onclick="window.blogFilters.setLanguage('all')">All</button>
              <button class="lang-filter-btn px-4 py-1.5 text-sm font-medium rounded-full transition-all whitespace-nowrap cursor-pointer bg-transparent hover:bg-white/60 text-base-content" data-lang="pt" onclick="window.blogFilters.setLanguage('pt')">🇧🇷 PT</button>
              <button class="lang-filter-btn px-4 py-1.5 text-sm font-medium rounded-full transition-all whitespace-nowrap cursor-pointer bg-transparent hover:bg-white/60 text-base-content" data-lang="en" onclick="window.blogFilters.setLanguage('en')">🇺🇸 EN</button>
            </div>
            <script>
              // Apply language state immediately (sync, no event listener)
              (function() {
                const urlParams = new URLSearchParams(window.location.search);
                const urlLang = urlParams.get('lang');
                const savedLang = localStorage.getItem('blog-filter-lang') || 'all';
                const currentLang = urlLang || savedLang;

                const buttons = document.querySelectorAll('.lang-filter-btn');
                buttons.forEach(function(btn) {
                  const lang = btn.getAttribute('data-lang');
                  if (lang === currentLang) {
                    btn.className = 'lang-filter-btn px-4 py-1.5 text-sm font-medium rounded-full transition-all whitespace-nowrap cursor-pointer bg-primary text-white';
                  } else {
                    btn.className = 'lang-filter-btn px-4 py-1.5 text-sm font-medium rounded-full transition-all whitespace-nowrap cursor-pointer bg-transparent hover:bg-white/60 text-base-content';
                  }
                });
              })();
            </script>
          </div>
        </div>

        <!-- Tags Navigation -->
        <div class="border-t border-base-300 bg-base-200/50">
          <div class="container mx-auto px-4 sm:px-6 max-w-6xl">
            <div class="py-3">
              <div class="flex flex-wrap gap-2 items-center">
                <div id="tags-pills" class="flex flex-wrap gap-2 items-center">
                  <button class="tag-pill px-4 py-1.5 text-sm font-medium rounded-full transition-all whitespace-nowrap cursor-pointer bg-primary text-white" data-tag="all" onclick="window.blogFilters.clearTag()">All</button>
                  <button class="tag-pill px-4 py-1.5 text-sm font-medium rounded-full transition-all whitespace-nowrap cursor-pointer bg-transparent hover:bg-base-200 text-base-content" data-tag="ruby" onclick="window.blogFilters.setTag('ruby')">Ruby</button>
                  <button class="tag-pill px-4 py-1.5 text-sm font-medium rounded-full transition-all whitespace-nowrap cursor-pointer bg-transparent hover:bg-base-200 text-base-content" data-tag="rust" onclick="window.blogFilters.setTag('rust')">Rust</button>
                  <button class="tag-pill px-4 py-1.5 text-sm font-medium rounded-full transition-all whitespace-nowrap cursor-pointer bg-transparent hover:bg-base-200 text-base-content" data-tag="haskell" onclick="window.blogFilters.setTag('haskell')">Haskell</button>
                  <button class="tag-pill px-4 py-1.5 text-sm font-medium rounded-full transition-all whitespace-nowrap cursor-pointer bg-transparent hover:bg-base-200 text-base-content" data-tag="assembly" onclick="window.blogFilters.setTag('assembly')">Assembly</button>
                  <button class="tag-pill px-4 py-1.5 text-sm font-medium rounded-full transition-all whitespace-nowrap cursor-pointer bg-transparent hover:bg-base-200 text-base-content" data-tag="bash" onclick="window.blogFilters.setTag('bash')">Bash</button>
                  <button class="tag-pill px-4 py-1.5 text-sm font-medium rounded-full transition-all whitespace-nowrap cursor-pointer bg-transparent hover:bg-base-200 text-base-content" data-tag="postgres" onclick="window.blogFilters.setTag('postgres')">Postgres</button>
                  <button class="tag-pill px-4 py-1.5 text-sm font-medium rounded-full transition-all whitespace-nowrap cursor-pointer bg-transparent hover:bg-base-200 text-base-content" data-tag="kubernetes" onclick="window.blogFilters.setTag('kubernetes')">Kubernetes</button>
                </div>
              </div>
            </div>
          </div>
          <script>
            // Apply tag state and pinned visibility immediately (sync, no event listener)
            (function() {
              const urlParams = new URLSearchParams(window.location.search);
              const urlTag = urlParams.get('tag');
              const savedTag = localStorage.getItem('blog-filter-tag');
              const currentTag = urlTag || savedTag || null;

              // Update tag buttons
              const buttons = document.querySelectorAll('.tag-pill');
              buttons.forEach(function(btn) {
                const tag = btn.getAttribute('data-tag');
                const isActive = (tag === 'all' && !currentTag) || (tag === currentTag);
                if (isActive) {
                  btn.className = 'tag-pill px-4 py-1.5 text-sm font-medium rounded-full transition-all whitespace-nowrap cursor-pointer bg-primary text-white';
                } else {
                  btn.className = 'tag-pill px-4 py-1.5 text-sm font-medium rounded-full transition-all whitespace-nowrap cursor-pointer bg-transparent hover:bg-base-200 text-base-content';
                }
              });
            })();
          </script>
        </div>
      </header>

      <!-- Main Content -->
      <main class="container mx-auto px-4 sm:px-6 py-8 max-w-6xl">
        <!-- Active Filters (Mobile Only) -->
        <div id="active-filters-mobile" class="hidden mb-6 p-4 bg-base-200/50 rounded-xl border border-base-300">
          <div class="space-y-3">
            <!-- Top row: Title + Filter chips on left, Clear All on right -->
            <div class="flex items-center justify-between gap-3">
              <div class="flex items-center gap-3 flex-wrap flex-1">
                <h3 class="text-sm font-semibold text-base-content/70">Active Filters</h3>
                <div id="filter-chips" class="flex flex-wrap gap-2">
                  <!-- Filter chips will be inserted here by JavaScript -->
                </div>
              </div>
              <button onclick="window.blogFilters.clearAll()" class="inline-flex items-center gap-1.5 text-xs font-medium text-primary hover:text-primary/80 transition-colors whitespace-nowrap">
                <span>Clear All</span>
                <svg class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
              </button>
            </div>

            <!-- Results count row -->
            <div id="results-count" class="text-xs text-base-content/60">
              <!-- Results count will be inserted here by JavaScript -->
            </div>
          </div>
        </div>

        <!-- Pinned Article (Full Width) -->
        #{render_pinned_article_section(articles)}

        <!-- Articles Grid -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6" id="articles-container">
          #{render_regular_articles_only(articles)}
        </div>

        <!-- Pagination -->
        <div id="pagination-container" class="flex justify-center">
          <div class="text-sm text-base-content/60">
            <span id="page-indicator">Page <span id="current-page">1</span> of <span id="total-pages">#{total_pages}</span></span>
          </div>
        </div>
      </main>

      <!-- Apply pinned visibility after DOM is ready -->
      <script>
        (function() {
          const urlParams = new URLSearchParams(window.location.search);
          const urlTag = urlParams.get('tag');
          const savedTag = localStorage.getItem('blog-filter-tag');
          const currentTag = urlTag || savedTag || null;

          // Hide pinned HIGHLIGHT only when tag filter is active (regular pinned card will be filtered by search.js)
          const hasTagFilter = currentTag !== null;
          if (hasTagFilter) {
            const pinnedHighlight = document.querySelector('.pinned-article');
            if (pinnedHighlight) {
              pinnedHighlight.style.display = 'none';
              pinnedHighlight.classList.add('hidden');
            }
          }
        })();
      </script>

        <!-- Footer -->
        <footer class="mt-16 pt-8 pb-6 border-t border-base-300">
          <div class="text-center text-sm text-base-content/80">
            <p>
              Powered by
              <a
                href="https://github.com/leandronsp/curupira"
                target="_blank"
                rel="noopener noreferrer"
                class="font-semibold text-blue-600 hover:underline"
              >
                Curupira
              </a>
              | Open source blog platform built with Phoenix LiveView
            </p>
            <p class="mt-2 text-xs text-base-content/70">
              Licensed under
              <a
                href="https://github.com/leandronsp/curupira/blob/master/LICENSE"
                target="_blank"
                rel="noopener noreferrer"
                class="text-blue-600 hover:underline"
              >
                AGPL-3.0
              </a>
            </p>
          </div>
        </footer>
      </div>

      <script src="/static-theme.js" defer></script>
      <script src="/static-filters.js" defer></script>
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

      <!-- Google Fonts - Nunito for name, Caveat for bio -->
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
      <link href="https://fonts.googleapis.com/css2?family=Nunito:wght@700;800&family=Caveat:wght@500;700&display=swap" rel="stylesheet">

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
        /* Force scrollbar to always be visible to prevent layout shift */
        html {
          overflow-y: scroll;
        }

        /* Softer dark theme colors */
        [data-theme="dark"] {
          --base-100: #2a2f3a;
          --base-200: #232831;
          --base-300: #1e222a;
          --base-content: #e8eaed;
        }
        [data-theme="dark"] .article-card {
          background-color: transparent;
          border-color: #3d4454;
        }
        [data-theme="dark"] .article-card:hover {
          border-color: #4a5568;
        }
        /* Keep pinned article with background for prominence in dark theme - lighter pastel */
        [data-theme="dark"] .pinned-article {
          background-color: #3a4050 !important;
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
        /* Language switcher dark theme styling */
        [data-theme="dark"] .lang-switcher-bg {
          background-color: rgba(59, 130, 246, 0.15) !important;
          border-color: rgba(59, 130, 246, 0.3) !important;
        }
        /* Blog name styling */
        .blog-name {
          font-family: 'Nunito', sans-serif;
          font-weight: 800;
          letter-spacing: -0.02em;
        }
        /* Intro text styling */
        .intro-text {
          font-family: 'Caveat', cursive;
          font-weight: 600;
          color: #6b7280; /* Darker pastel gray for light theme */
        }
        [data-theme="dark"] .intro-text {
          color: #d4d4d8; /* Lighter pastel gray for dark theme */
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
        /* Article images styling - consistent sizing */
        .prose img {
          max-width: 800px;
          width: 100%;
          height: auto;
          display: block;
          margin-left: auto;
          margin-right: auto;
          border-radius: 0.5rem;
        }
      </style>
    </head>
    <body class="min-h-screen bg-base-100">
      <!-- Fixed Header - Article page: focus on reading -->
      <header class="sticky top-0 z-50 bg-base-100 border-b border-base-300 shadow-sm">
        <div class="container mx-auto px-4 sm:px-6 py-4 max-w-6xl">
          <!-- Same structure as homepage, no search/language/tags -->
          <div class="flex flex-col gap-2">
            <!-- Name + Social Icons (icons hidden on small) -->
            <div class="flex items-center gap-3">
              <h1 class="blog-name text-2xl sm:text-3xl font-bold text-base-content flex-shrink-0">#{profile.name || "Blog"}</h1>
              <div class="hidden md:flex items-center gap-2">
                <a href="https://linkedin.com/in/leandronsp" target="_blank" rel="noopener noreferrer" class="text-base-content/60 hover:text-primary transition-colors" title="LinkedIn">
                  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/></svg>
                </a>
                <a href="https://github.com/leandronsp" target="_blank" rel="noopener noreferrer" class="text-base-content/60 hover:text-primary transition-colors" title="GitHub">
                  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path fill-rule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" clip-rule="evenodd"/></svg>
                </a>
                <button id="theme-toggle" class="text-base-content/60 hover:text-primary transition-colors" title="Toggle theme">
                  <svg xmlns="http://www.w3.org/2000/svg" class="sun-icon h-5 w-5 hidden" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" /></svg>
                  <svg xmlns="http://www.w3.org/2000/svg" class="moon-icon h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" /></svg>
                </button>
              </div>
            </div>

            <!-- Bio: plain on small/medium, with guide links on large -->
            <p class="intro-text text-xl lg:text-2xl leading-tight">
              <span class="lg:hidden">Software Developer 15+ years programming and counting.</span>
              <span class="hidden lg:inline">Software Developer 15+ years programming and counting. See my guides at
                <a href="https://web101.leandronsp.com" target="_blank" rel="noopener noreferrer" class="underline decoration-2 hover:opacity-80 transition-opacity cursor-pointer">web101</a>,
                <a href="https://concorrencia101.leandronsp.com" target="_blank" rel="noopener noreferrer" class="underline decoration-2 hover:opacity-80 transition-opacity cursor-pointer">concorrencia101</a>,
                <a href="https://aws101.leandronsp.com" target="_blank" rel="noopener noreferrer" class="underline decoration-2 hover:opacity-80 transition-opacity cursor-pointer">aws101</a>
              </span>
            </p>
          </div>

        </div>
      </header>

      <!-- Main Content -->
      <main class="container mx-auto px-4 sm:px-6 py-8 max-w-6xl">
        <article class="bg-base-100">
          <!-- Back link -->
          <a href="/" onclick="event.preventDefault(); history.back();" class="inline-flex items-center gap-2 text-lg font-medium transition-colors text-base-content/70 hover:text-primary cursor-pointer mb-6">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            Back
          </a>

          <h1 class="text-5xl font-bold leading-tight mb-6">#{article.title}</h1>

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

          <!-- Back to top -->
          <div class="mt-12 mb-8 text-center">
            <a href="#" onclick="event.preventDefault(); window.scrollTo({ top: 0, behavior: 'smooth' });" class="inline-flex items-center gap-2 text-xl font-medium transition-colors text-base-content/70 hover:text-primary cursor-pointer">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M5 10l7-7m0 0l7 7m-7-7v18" />
              </svg>
              Back to top
            </a>
          </div>
        </article>

        <!-- Giscus Comments -->
        <div class="mt-16">
          <div class="border-t border-base-300 pt-8">
            <h2 class="text-2xl font-bold mb-6">Comments</h2>
            <script src="https://giscus.app/client.js"
                    data-repo="leandronsp/leandronsp.com"
                    data-repo-id="R_kgDOQGG-eQ"
                    data-category="Announcements"
                    data-category-id="DIC_kwDOQGG-ec4Cw4TN"
                    data-mapping="pathname"
                    data-strict="0"
                    data-reactions-enabled="1"
                    data-emit-metadata="0"
                    data-input-position="bottom"
                    data-theme="preferred_color_scheme"
                    data-lang="en"
                    crossorigin="anonymous"
                    async>
            </script>
          </div>
        </div>

        <!-- Footer -->
        <footer class="mt-16 pt-8 pb-6 border-t border-base-300">
          <div class="text-center text-sm text-base-content/80">
            <p>
              Powered by
              <a
                href="https://github.com/leandronsp/curupira"
                target="_blank"
                rel="noopener noreferrer"
                class="font-semibold text-blue-600 hover:underline"
              >
                Curupira
              </a>
              | Open source blog platform built with Phoenix LiveView
            </p>
            <p class="mt-2 text-xs text-base-content/70">
              Licensed under
              <a
                href="https://github.com/leandronsp/curupira/blob/master/LICENSE"
                target="_blank"
                rel="noopener noreferrer"
                class="text-blue-600 hover:underline"
              >
                AGPL-3.0
              </a>
            </p>
          </div>
        </footer>
      </main>

      <script src="/static-theme.js" defer></script>
      <script src="/static-filters.js" defer></script>
      <script src="/static-search.js" defer></script>
      <script src="/static-giscus.js" defer></script>

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

  # Generate HTML snippet with formatting but no clickable links
  defp generate_snippet_html(content) do
    # Convert markdown to HTML
    {:ok, html} = Curupira.Markdown.Parser.to_html(content)

    # Remove all HTML tags to get plain text only
    # Remove links but keep link text: <a href="...">text</a> -> text
    html = Regex.replace(~r/<a[^>]*>(.*?)<\/a>/i, html, "\\1")

    # Remove all other HTML tags (block-level and inline formatting)
    html = html
      |> String.replace(~r/<[^>]*>/, " ")
      |> String.replace("---", "")  # Remove horizontal rules
      |> String.replace(~r/\s+/, " ")
      |> String.trim()

    # Truncate to ~150 chars
    max_length = 150
    if String.length(html) > max_length do
      String.slice(html, 0, max_length) <> "..."
    else
      html
    end
  end

  defp generate_pinned_snippet_html(content) do
    # Convert markdown to HTML
    {:ok, html} = Curupira.Markdown.Parser.to_html(content)

    # Remove all HTML tags to get plain text only
    # Remove links but keep link text: <a href="...">text</a> -> text
    html = Regex.replace(~r/<a[^>]*>(.*?)<\/a>/i, html, "\\1")

    # Remove all other HTML tags (block-level and inline formatting)
    html = html
      |> String.replace(~r/<[^>]*>/, " ")
      |> String.replace("---", "")  # Remove horizontal rules
      |> String.replace(~r/\s+/, " ")
      |> String.trim()

    # Truncate to ~320 chars (larger for pinned articles)
    max_length = 320
    if String.length(html) > max_length do
      String.slice(html, 0, max_length) <> "..."
    else
      html
    end
  end

  # Truncate HTML while preserving tags
  defp truncate_html(html, max_chars) do
    # Simple approach: extract text, truncate, then extract HTML up to that point
    plain_text = String.replace(html, ~r/<[^>]*>/, "")
    truncated_text = String.slice(plain_text, 0, max_chars)

    # Find position in original HTML
    # This is approximate - better would be proper HTML parsing
    # For now, just slice the HTML at roughly the same position
    String.slice(html, 0, max_chars + 50)
      |> close_unclosed_tags()
  end

  # Close any unclosed tags in truncated HTML
  defp close_unclosed_tags(html) do
    # Find all opening tags
    opening_tags = Regex.scan(~r/<(strong|em|b|i|code|span)(?:\s[^>]*)?>/, html)
      |> Enum.map(fn [_, tag] -> tag end)

    # Find all closing tags
    closing_tags = Regex.scan(~r/<\/(strong|em|b|i|code|span)>/, html)
      |> Enum.map(fn [_, tag] -> tag end)

    # Calculate which tags need to be closed
    unclosed = opening_tags
      |> Enum.frequencies()
      |> Enum.map(fn {tag, open_count} ->
        close_count = Enum.count(closing_tags, &(&1 == tag))
        {tag, max(0, open_count - close_count)}
      end)
      |> Enum.filter(fn {_, count} -> count > 0 end)

    # Add closing tags
    closing_html = unclosed
      |> Enum.flat_map(fn {tag, count} ->
        List.duplicate("</#{tag}>", count)
      end)
      |> Enum.reverse()  # Close in reverse order
      |> Enum.join()

    html <> closing_html
  end

  defp render_article_list(articles) do
    sorted_articles = articles
    |> Enum.sort_by(fn a -> {!a.pinned, a.published_at || a.inserted_at} end, fn {p1, d1}, {p2, d2} ->
      if p1 == p2, do: DateTime.compare(d1, d2) == :gt, else: p1 < p2
    end)

    {pinned, regular} = Enum.split_with(sorted_articles, & &1.pinned)

    pinned_html = case pinned do
      [article | _] -> render_pinned_article(article)
      [] -> ""
    end

    regular_html = Enum.map(regular, &render_regular_article/1)
    |> Enum.join("\n")

    pinned_html <> regular_html
  end

  defp render_pinned_article_section(articles) do
    pinned = Enum.find(articles, & &1.pinned)

    case pinned do
      nil -> ""
      article -> render_pinned_article(article)
    end
  end

  defp render_regular_articles_only(articles) do
    articles
    |> Enum.sort_by(fn a -> a.published_at || a.inserted_at end, {:desc, DateTime})
    |> Enum.map(&render_regular_article/1)
    |> Enum.join("\n")
  end

  defp render_pinned_article(article) do
    published_date = if article.published_at do
      Calendar.strftime(article.published_at, "%d %b %Y")
    else
      Calendar.strftime(article.inserted_at, "%d %b %Y")
    end

    snippet_html = generate_pinned_snippet_html(article.content || "")

    tag_pills = if article.tags && length(article.tags) > 0 do
      Enum.take(article.tags, 4)
      |> Enum.map_join("", fn tag ->
        ~s(<span class="px-2.5 py-1 text-xs font-medium bg-base-200 text-base-content/80 rounded-md hover:bg-primary/10 transition-colors">#{tag}</span>)
      end)
    else
      ""
    end

    """
    <article
      class="article-card pinned-article group block p-8 bg-amber-50/50 dark:bg-slate-800 border-4 border-orange-500 dark:border-blue-400 shadow-md shadow-orange-200/50 dark:shadow-blue-900/30 rounded-xl hover:border-orange-600 dark:hover:border-blue-300 transition-all cursor-pointer mb-8 relative"
      data-slug="#{article.slug}"
      data-title="#{String.downcase(article.title)}"
      data-tags="#{String.downcase(Enum.join(article.tags || [], " "))}"
      data-language="#{article.language || "en"}"
      data-pinned="true"
      onclick="window.location.href='/articles/#{article.slug}.html'"
    >
      <!-- Pinned Badge -->
      <div class="absolute top-4 right-4 flex items-center gap-2 px-3 py-1.5 bg-primary text-white rounded-full text-xs font-semibold">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z" />
        </svg>
        Pinned
      </div>

      <!-- Tags First -->
      <div class="flex gap-2 flex-wrap mb-4">
        #{tag_pills}
      </div>

      <!-- Title -->
      <h2 class="text-2xl sm:text-3xl font-bold text-base-content leading-tight mb-4 group-hover:text-primary transition-colors">
        #{article.title}
      </h2>

      <!-- Snippet -->
      <p class="text-lg text-base-content/75 leading-relaxed line-clamp-5 mb-4">
        #{snippet_html}
      </p>

      <!-- Meta Footer -->
      <div class="flex items-center gap-3 text-sm text-base-content/60">
        <time datetime="#{if article.published_at, do: DateTime.to_iso8601(article.published_at), else: DateTime.to_iso8601(article.inserted_at)}">
          #{published_date}
        </time>
        <span>•</span>
        <span class="text-xl">#{Curupira.Blog.Article.language_flag(article)}</span>
      </div>
    </article>
    """
  end

  defp render_regular_article(article) do
    published_date = if article.published_at do
      Calendar.strftime(article.published_at, "%d %b %Y")
    else
      Calendar.strftime(article.inserted_at, "%d %b %Y")
    end

    snippet_html = generate_snippet_html(article.content || "")

    tag_pills = if article.tags && length(article.tags) > 0 do
      Enum.take(article.tags, 4)
      |> Enum.map_join("", fn tag ->
        ~s(<span class="px-2.5 py-1 text-xs font-medium bg-base-200 text-base-content/80 rounded-md hover:bg-primary/10 transition-colors">#{tag}</span>)
      end)
    else
      ""
    end

    """
    <article
      class="article-card group block p-6 bg-base-100 border border-base-300 rounded-xl hover:shadow-lg hover:border-primary/30 transition-all cursor-pointer"
      data-slug="#{article.slug}"
      data-title="#{String.downcase(article.title)}"
      data-tags="#{String.downcase(Enum.join(article.tags || [], " "))}"
      data-language="#{article.language || "en"}"
      #{if article.pinned, do: ~s(data-pinned="true"), else: ""}
      onclick="window.location.href='/articles/#{article.slug}.html'"
    >
      <!-- Tags First -->
      <div class="flex gap-2 flex-wrap mb-3">
        #{tag_pills}
      </div>

      <!-- Title -->
      <h2 class="text-xl sm:text-2xl font-bold text-base-content leading-snug mb-3 group-hover:text-primary transition-colors line-clamp-2 min-h-[3.5rem]">
        #{article.title}
      </h2>

      <!-- Snippet -->
      <p class="text-base text-base-content/70 leading-relaxed line-clamp-2 mb-4">
        #{snippet_html}
      </p>

      <!-- Meta Footer -->
      <div class="flex items-center gap-3 text-sm text-base-content/60">
        <time datetime="#{if article.published_at, do: DateTime.to_iso8601(article.published_at), else: DateTime.to_iso8601(article.inserted_at)}">
          #{published_date}
        </time>
        <span>•</span>
        <span class="text-lg">#{Curupira.Blog.Article.language_flag(article)}</span>
      </div>
    </article>
    """
  end
end
