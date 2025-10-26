// Blog filters management with URL persistence
(function() {
  let tagCategories = [];
  let currentFilters = {
    lang: 'all',
    tag: null,
    search: ''
  };

  // URL params management
  function getUrlParams() {
    const params = new URLSearchParams(window.location.search);
    return {
      lang: params.get('lang') || 'all',
      tag: params.get('tag') || null,
      search: params.get('q') || '',
      page: parseInt(params.get('page')) || 1
    };
  }

  function updateUrlParams(updates) {
    const params = new URLSearchParams(window.location.search);

    Object.entries(updates).forEach(([key, value]) => {
      if (value === null || value === '' || value === 'all' || value === 1) {
        params.delete(key);
      } else {
        params.set(key, value);
      }
    });

    const newUrl = params.toString()
      ? `${window.location.pathname}?${params.toString()}`
      : window.location.pathname;

    window.history.pushState({}, '', newUrl);
  }

  // Load tags from tags.json (curated with categories)
  async function loadTags() {
    try {
      const response = await fetch('/tags.json');
      tagCategories = await response.json();
    } catch (error) {
      console.error('Failed to load tags:', error);
      tagCategories = [];
    }
  }

  // Filter articles based on current filters (optimized to avoid reflows)
  function filterArticles() {
    // Use requestAnimationFrame to batch DOM updates
    requestAnimationFrame(() => {
      const articles = document.querySelectorAll('.article-card');

      // Batch class changes to minimize reflows
      const toShow = [];
      const toHide = [];

      articles.forEach(article => {
        let visible = true;

        // Language filter
        if (currentFilters.lang !== 'all') {
          const articleLang = article.getAttribute('data-language') || 'en';
          if (currentFilters.lang === 'pt') {
            visible = visible && (articleLang === 'pt-BR' || articleLang === 'pt');
          } else {
            visible = visible && (articleLang === currentFilters.lang);
          }
        }

        // Tag filter
        if (currentFilters.tag) {
          const articleTags = article.getAttribute('data-tags') || '';
          visible = visible && articleTags.includes(currentFilters.tag.toLowerCase());
        }

        // Collect elements to show/hide
        if (visible) {
          toShow.push(article);
        } else {
          toHide.push(article);
        }
      });

      // Apply visibility changes in batches
      toShow.forEach(article => article.classList.remove('js-hidden'));
      toHide.forEach(article => article.classList.add('js-hidden'));

      // Trigger pagination recalculation
      if (window.pagination && window.pagination.handleSearch) {
        window.pagination.handleSearch();
      }
    });
  }

  // Update tag pills UI (tags are already rendered in HTML by server)
  function updateTagsUI() {
    const buttons = document.querySelectorAll('.tag-pill');
    buttons.forEach(btn => {
      const tag = btn.getAttribute('data-tag');
      const isActive = (tag === 'all' && !currentFilters.tag) || (tag === currentFilters.tag);
      if (isActive) {
        btn.className = 'tag-pill px-4 py-1.5 text-sm font-medium rounded-full whitespace-nowrap cursor-pointer bg-primary text-white';
      } else {
        btn.className = 'tag-pill px-4 py-1.5 text-sm font-medium rounded-full whitespace-nowrap cursor-pointer bg-transparent hover:bg-base-200 text-base-content';
      }
    });
  }

  // Render tag pills (stub function for compatibility)
  function renderTagsPills() {
    updateTagsUI();
  }

  // Update language filter UI
  function updateLanguageUI() {
    document.querySelectorAll('.lang-filter-btn').forEach(btn => {
      const lang = btn.getAttribute('data-lang');
      if (lang === currentFilters.lang) {
        btn.className = 'lang-filter-btn px-4 py-1.5 text-sm font-medium rounded-full whitespace-nowrap cursor-pointer bg-primary text-white';
      } else {
        btn.className = 'lang-filter-btn px-4 py-1.5 text-sm font-medium rounded-full whitespace-nowrap cursor-pointer bg-transparent hover:bg-base-100 text-base-content';
      }
    });
  }

  // Update mobile active filters UI
  function updateMobileFilters() {
    const container = document.getElementById('active-filters-mobile');
    const chipsContainer = document.getElementById('filter-chips');
    const resultsCount = document.getElementById('results-count');

    if (!container || !chipsContainer) return;

    const hasActiveFilters = currentFilters.lang !== 'all' || currentFilters.tag;

    if (!hasActiveFilters) {
      container.classList.add('hidden');
      return;
    }

    container.classList.remove('hidden');

    // Build filter chips
    let chips = [];

    // Language chip
    if (currentFilters.lang !== 'all') {
      const langLabel = currentFilters.lang === 'pt' ? '🇧🇷 PT' : '🇺🇸 EN';
      chips.push(`
        <button onclick="window.blogFilters.setLanguage('all')" class="inline-flex items-center gap-2 px-3 py-1.5 bg-primary/10 text-primary rounded-full text-sm font-medium hover:bg-primary/20 transition-colors">
          <span>${langLabel}</span>
          <svg class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>
        </button>
      `);
    }

    // Tag chip
    if (currentFilters.tag) {
      const tagLabel = currentFilters.tag.charAt(0).toUpperCase() + currentFilters.tag.slice(1);
      chips.push(`
        <button onclick="window.blogFilters.clearTag()" class="inline-flex items-center gap-2 px-3 py-1.5 bg-primary/10 text-primary rounded-full text-sm font-medium hover:bg-primary/20 transition-colors">
          <span>${tagLabel}</span>
          <svg class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>
        </button>
      `);
    }

    chipsContainer.innerHTML = chips.join('');

    // Update results count
    const visibleArticles = document.querySelectorAll('.article-card:not(.js-hidden)');
    const count = visibleArticles.length;
    resultsCount.innerHTML = `Showing ${count} article${count !== 1 ? 's' : ''}`;
  }

  // Check if we're on an article page (not homepage)
  function isArticlePage() {
    return window.location.pathname.includes('/articles/');
  }

  // Public API
  window.blogFilters = {
    setLanguage(lang) {
      // Save to localStorage for article pages
      localStorage.setItem('blog-filter-lang', lang);

      // If on article page, navigate to home with filter
      if (isArticlePage()) {
        const params = new URLSearchParams();
        if (lang !== 'all') params.set('lang', lang);
        window.location.href = '/' + (params.toString() ? '?' + params.toString() : '');
        return;
      }

      currentFilters.lang = lang;
      updateUrlParams({ lang, page: 1 });
      updateLanguageUI();
      updateTagsUI();
      filterArticles();
      updateMobileFilters();
    },

    setTag(tag) {
      // Save to localStorage for article pages
      if (tag) {
        localStorage.setItem('blog-filter-tag', tag);
      } else {
        localStorage.removeItem('blog-filter-tag');
      }

      // If on article page, navigate to home with filter
      if (isArticlePage()) {
        const params = new URLSearchParams();
        params.set('tag', tag);
        window.location.href = '/' + '?' + params.toString();
        return;
      }

      // Toggle tag if clicking same one
      if (currentFilters.tag === tag) {
        currentFilters.tag = null;
        localStorage.removeItem('blog-filter-tag');
      } else {
        currentFilters.tag = tag;
      }

      updateUrlParams({ tag: currentFilters.tag, page: 1 });
      updateTagsUI();
      filterArticles();
      updateMobileFilters();
    },

    clearTag() {
      // Remove from localStorage
      localStorage.removeItem('blog-filter-tag');

      // If on article page, navigate to home
      if (isArticlePage()) {
        window.location.href = '/';
        return;
      }

      currentFilters.tag = null;
      updateUrlParams({ tag: null, page: 1 });
      updateTagsUI();
      filterArticles();
      updateMobileFilters();
    },

    remove(type) {
      if (type === 'lang') {
        this.setLanguage('all');
      } else if (type === 'tag') {
        this.setTag(currentFilters.tag); // Toggle off
      }
    },

    clearAll() {
      currentFilters.lang = 'all';
      currentFilters.tag = null;
      updateUrlParams({ lang: null, tag: null, page: 1 });
      updateLanguageUI();
      renderTagsPills();
      filterArticles();
      updateMobileFilters();
    },

    getFilters() {
      return { ...currentFilters };
    },

    init() {
      // If on article page, try to restore filters from referrer or localStorage
      if (isArticlePage()) {
        let langRestored = false;
        let tagRestored = false;

        // Try to restore from referrer first
        if (document.referrer) {
          try {
            const referrerUrl = new URL(document.referrer);
            // Only read from referrer if it's from the same site
            if (referrerUrl.origin === window.location.origin) {
              const referrerParams = new URLSearchParams(referrerUrl.search);
              const langParam = referrerParams.get('lang');
              const tagParam = referrerParams.get('tag');

              if (langParam) {
                currentFilters.lang = langParam;
                langRestored = true;
              }
              if (tagParam) {
                currentFilters.tag = tagParam;
                tagRestored = true;
              }
            }
          } catch (e) {
            // Ignore invalid referrer URLs
          }
        }

        // Fallback to localStorage
        if (!langRestored) {
          currentFilters.lang = localStorage.getItem('blog-filter-lang') || 'all';
        }
        if (!tagRestored) {
          const savedTag = localStorage.getItem('blog-filter-tag');
          currentFilters.tag = savedTag || null;
        }
      } else {
        // Restore from current URL (homepage)
        const params = getUrlParams();
        currentFilters.lang = params.lang;
        currentFilters.tag = params.tag;
        currentFilters.search = params.search;

        // Save to localStorage for article pages to use
        localStorage.setItem('blog-filter-lang', currentFilters.lang);
        if (currentFilters.tag) {
          localStorage.setItem('blog-filter-tag', currentFilters.tag);
        } else {
          localStorage.removeItem('blog-filter-tag');
        }
      }

      // Restore search input (homepage only)
      const searchInput = document.getElementById('search-input');
      if (searchInput && currentFilters.search && !isArticlePage()) {
        searchInput.value = currentFilters.search;
      }

    }
  };

  // Initialize on DOM ready
  async function init() {
    await loadTags();
    window.blogFilters.init();
    renderTagsPills();
    filterArticles();  // Apply filters on page load
    updateMobileFilters();  // Update mobile filter chips on page load
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
