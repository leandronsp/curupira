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

  // Render tag pills in header
  function renderTagsPills() {
    const container = document.getElementById('tags-pills');
    if (!container) return;

    // Add "All" button first
    const allActive = currentFilters.tag === null;
    const allButtonClasses = allActive
      ? 'px-4 py-1.5 text-sm font-medium rounded-full transition-all whitespace-nowrap bg-primary text-white cursor-pointer'
      : 'px-4 py-1.5 text-sm font-medium rounded-full transition-all whitespace-nowrap bg-transparent hover:bg-base-200 text-base-content cursor-pointer';

    const allButton = `<button
      class="${allButtonClasses}"
      onclick="window.blogFilters.clearTag()"
      data-tag="all"
    >
      All
    </button>`;

    // Filter to only show specific main tags
    const mainTags = ['ruby', 'rust', 'haskell', 'assembly', 'bash', 'postgres', 'kubernetes'];

    const filteredTags = tagCategories
      .flatMap(category => category.tags)
      .filter(({ tag }) => mainTags.includes(tag.toLowerCase()));

    const tagButtons = filteredTags.map(({ tag, count }) => {
      const isActive = currentFilters.tag === tag;
      const classes = isActive
        ? 'px-4 py-1.5 text-sm font-medium rounded-full transition-all whitespace-nowrap bg-primary text-white cursor-pointer'
        : 'px-4 py-1.5 text-sm font-medium rounded-full transition-all whitespace-nowrap bg-transparent hover:bg-base-200 text-base-content cursor-pointer';

      return `<button
        class="${classes}"
        onclick="window.blogFilters.setTag('${tag}')"
        data-tag="${tag}"
      >
        ${tag.charAt(0).toUpperCase() + tag.slice(1).toLowerCase()}
      </button>`;
    }).join('');

    container.innerHTML = allButton + tagButtons;
  }

  // Update language filter UI
  function updateLanguageUI() {
    document.querySelectorAll('.lang-filter-btn').forEach(btn => {
      const lang = btn.getAttribute('data-lang');
      if (lang === currentFilters.lang) {
        btn.className = 'lang-filter-btn px-4 py-1.5 text-sm font-medium rounded-full transition-all whitespace-nowrap cursor-pointer bg-primary text-white';
      } else {
        btn.className = 'lang-filter-btn px-4 py-1.5 text-sm font-medium rounded-full transition-all whitespace-nowrap cursor-pointer bg-transparent hover:bg-base-100 text-base-content';
      }
    });
  }

  // Check if we're on an article page (not homepage)
  function isArticlePage() {
    return window.location.pathname.includes('/articles/');
  }

  // Public API
  window.blogFilters = {
    setLanguage(lang) {
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
      renderTagsPills();

      // Trigger search/filter update
      if (window.blogSearch && window.blogSearch.filter) {
        window.blogSearch.filter();
      }
    },

    setTag(tag) {
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
      } else {
        currentFilters.tag = tag;
      }

      updateUrlParams({ tag: currentFilters.tag, page: 1 });
      renderTagsPills();

      // Trigger search/filter update
      if (window.blogSearch && window.blogSearch.filter) {
        window.blogSearch.filter();
      }
    },

    clearTag() {
      // If on article page, navigate to home
      if (isArticlePage()) {
        window.location.href = '/';
        return;
      }

      currentFilters.tag = null;
      updateUrlParams({ tag: null, page: 1 });
      renderTagsPills();

      // Trigger search/filter update
      if (window.blogSearch && window.blogSearch.filter) {
        window.blogSearch.filter();
      }
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

      // Trigger search/filter update
      if (window.blogSearch && window.blogSearch.filter) {
        window.blogSearch.filter();
      }
    },

    getFilters() {
      return { ...currentFilters };
    },

    init() {
      // Restore from URL
      const params = getUrlParams();
      currentFilters.lang = params.lang;
      currentFilters.tag = params.tag;
      currentFilters.search = params.search;

      // Update UI
      updateLanguageUI();

      // Restore search input
      const searchInput = document.getElementById('search-input');
      if (searchInput && params.search) {
        searchInput.value = params.search;
      }

      // Trigger initial filter after state restoration
      // Use a small delay to ensure search.js has initialized
      setTimeout(() => {
        if (window.blogSearch && window.blogSearch.filter) {
          window.blogSearch.filter();
        }
      }, 0);
    }
  };

  // Initialize on DOM ready
  async function init() {
    await loadTags();
    window.blogFilters.init();
    renderTagsPills();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
