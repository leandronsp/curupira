// Enhanced client-side search for static site
(function() {
  const searchInput = document.getElementById('search-input');
  if (!searchInput) return;

  const articlesContainer = document.getElementById('articles-container');
  const noResults = document.getElementById('no-results');
  let allArticles = [];
  let searchIndex = [];
  let currentLanguageFilter = 'all';

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

    // Search in title and tags
    const title = normalizeText(indexData.title);
    const tags = normalizeText((indexData.tags || []).join(' '));

    return title.includes(query) || tags.includes(query);
  }

  function matchesLanguage(article) {
    if (currentLanguageFilter === 'all') return true;

    const slug = article.getAttribute('data-slug') || '';
    const indexData = searchIndex.find(item => item.slug === slug);

    if (!indexData) return true;

    const language = indexData.language || 'en';

    if (currentLanguageFilter === 'pt') {
      return language === 'pt-BR' || language === 'pt';
    }

    return language === currentLanguageFilter;
  }

  function filterArticles() {
    const query = normalizeText(searchInput.value);

    allArticles.forEach(card => {
      const matchesQ = matchesSearch(card, query);
      const matchesLang = matchesLanguage(card);
      const matches = matchesQ && matchesLang;

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

  // Search input handler
  searchInput.addEventListener('input', filterArticles);

  // Language filter buttons
  window.setLanguageFilter = function(lang) {
    currentLanguageFilter = lang;

    // Update button states
    document.querySelectorAll('.lang-filter-btn').forEach(btn => {
      if (btn.getAttribute('data-lang') === lang) {
        btn.className = 'lang-filter-btn px-2 sm:px-3 py-1 sm:py-1.5 text-xs sm:text-sm font-medium transition-colors bg-primary text-white';
        if (btn.getAttribute('data-lang') !== 'all') {
          btn.classList.add('border-l-2', 'border-base-300');
        }
      } else {
        btn.className = 'lang-filter-btn px-2 sm:px-3 py-1 sm:py-1.5 text-xs sm:text-sm font-medium transition-colors bg-base-100 hover:bg-base-200';
        if (btn.getAttribute('data-lang') !== 'all') {
          btn.classList.add('border-l-2', 'border-base-300');
        }
      }
    });

    filterArticles();
  };

  // Initialize on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
