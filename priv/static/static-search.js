// Enhanced client-side search with filters integration
(function() {
  const searchInput = document.getElementById('search-input');
  if (!searchInput) return;

  const articlesContainer = document.getElementById('articles-container');
  const noResults = document.getElementById('no-results');
  let allArticles = [];
  let searchIndex = [];

  // Load search index
  async function loadSearchIndex() {
    try {
      const response = await fetch('/search-index.json');
      searchIndex = await response.json();
    } catch (error) {
      console.error('Failed to load search index:', error);
      searchIndex = [];
    }
  }

  async function init() {
    allArticles = Array.from(articlesContainer.querySelectorAll('.article-card'));
    await loadSearchIndex();

    // Check if we need to apply initial filters from URL
    // This ensures filters are applied even if blogFilters hasn't called us yet
    const params = new URLSearchParams(window.location.search);
    if (params.has('lang') || params.has('tag') || params.has('q')) {
      // Delay slightly to ensure blogFilters has restored state
      setTimeout(() => filter(), 50);
    }
  }

  function normalizeText(text) {
    return (text || '').toLowerCase().trim();
  }

  function matchesSearch(article, query) {
    if (!query) return true;

    const slug = article.getAttribute('data-slug') || '';
    const indexData = searchIndex.find(item => item.slug === slug);

    if (!indexData) {
      // Fallback to data attributes
      const title = normalizeText(article.getAttribute('data-title'));
      const tags = normalizeText(article.getAttribute('data-tags'));
      return title.includes(query) || tags.includes(query);
    }

    // Search in title, tags, and snippet
    const title = normalizeText(indexData.title);
    const tags = normalizeText((indexData.tags || []).join(' '));
    const snippet = normalizeText(indexData.snippet || '');

    return title.includes(query) || tags.includes(query) || snippet.includes(query);
  }

  function matchesLanguage(article, lang) {
    if (lang === 'all') return true;

    const slug = article.getAttribute('data-slug') || '';
    const indexData = searchIndex.find(item => item.slug === slug);

    if (!indexData) return true;

    const language = indexData.language || 'en';

    if (lang === 'pt') {
      return language === 'pt-BR' || language === 'pt';
    }

    return language === lang;
  }

  function matchesTag(article, tag) {
    if (!tag) return true;

    const slug = article.getAttribute('data-slug') || '';
    const indexData = searchIndex.find(item => item.slug === slug);

    if (!indexData) return false; // Don't show if not in index

    return (indexData.tags || []).includes(tag);
  }

  function filter(resetPage = false) {
    const query = normalizeText(searchInput.value);
    const filters = window.blogFilters ? window.blogFilters.getFilters() : { lang: 'all', tag: null };

    // Hide pinned only when TAG is active (not when language or search is active)
    const hasTagFilter = filters.tag !== null;

    // Update URL with search query
    if (window.blogFilters) {
      const params = new URLSearchParams(window.location.search);
      if (query) {
        params.set('q', query);
      } else {
        params.delete('q');
      }

      // Reset page when search query changes (user typing)
      if (resetPage) {
        params.delete('page');
      }

      const newUrl = params.toString()
        ? `${window.location.pathname}?${params.toString()}`
        : window.location.pathname;
      window.history.replaceState({}, '', newUrl);
    }

    allArticles.forEach(card => {
      const isPinnedHighlight = card.classList.contains('pinned-article');
      const isPinned = card.getAttribute('data-pinned') === 'true';

      // Hide ALL pinned cards (both highlight and regular) when TAG filter is active
      if (isPinned && hasTagFilter) {
        card.style.display = 'none';
        card.classList.add('hidden');
        return;
      }

      // Show pinned highlight when no TAG filter
      if (isPinnedHighlight && !hasTagFilter) {
        card.style.display = '';
        card.classList.remove('hidden');
        return;
      }

      // Hide regular pinned card when no TAG filter (show highlight instead)
      if (isPinned && !isPinnedHighlight && !hasTagFilter) {
        card.style.display = 'none';
        card.classList.add('hidden');
        return;
      }

      // For non-pinned cards, apply normal filtering
      const matchesQ = matchesSearch(card, query);
      const matchesLang = matchesLanguage(card, filters.lang);
      const matchesT = matchesTag(card, filters.tag);
      const matches = matchesQ && matchesLang && matchesT;

      if (matches) {
        card.style.display = '';
        card.classList.remove('hidden');
      } else {
        card.style.display = 'none';
        card.classList.add('hidden');
      }
    });

    // Show/hide no results message
    const visibleCards = allArticles.filter(
      card => card.style.display !== 'none'
    );

    if (visibleCards.length === 0) {
      noResults.classList.remove('hidden');
    } else {
      noResults.classList.add('hidden');
    }

    // Trigger pagination update
    if (window.pagination && window.pagination.handleSearch) {
      window.pagination.handleSearch();
    }
  }

  // Search input handler - reset page when user types
  searchInput.addEventListener('input', () => filter(true));

  // Expose public API
  window.blogSearch = {
    filter
  };

  // Initialize on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
