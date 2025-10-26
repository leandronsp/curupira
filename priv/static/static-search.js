// Search with dropdown results
(function() {
  const searchInput = document.getElementById('search-input');
  if (!searchInput) return;

  const searchResults = document.getElementById('search-results');
  const searchClear = document.getElementById('search-clear');
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

  function normalizeText(text) {
    return (text || '').toLowerCase().trim();
  }

  function scoreMatch(item, query) {
    const normalizedQuery = normalizeText(query);
    const title = normalizeText(item.title);
    const tags = normalizeText((item.tags || []).join(' '));
    const snippet = normalizeText(item.snippet || '');

    let score = 0;

    // Title match is worth more
    if (title.includes(normalizedQuery)) score += 10;
    if (title.startsWith(normalizedQuery)) score += 5;

    // Tags match
    if (tags.includes(normalizedQuery)) score += 5;

    // Snippet match
    if (snippet.includes(normalizedQuery)) score += 1;

    return score;
  }

  function formatDate(dateString) {
    const date = new Date(dateString);
    const day = String(date.getDate()).padStart(2, '0');
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const month = months[date.getMonth()];
    const year = date.getFullYear();
    return `${day} ${month} ${year}`;
  }

  function getLanguageFlag(lang) {
    if (lang === 'pt-BR' || lang === 'pt') return '🇧🇷';
    if (lang === 'en') return '🇺🇸';
    return '';
  }

  function renderResults(results) {
    if (results.length === 0) {
      searchResults.innerHTML = `
        <div class="px-8 py-10 text-center text-base-content/60">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 mx-auto mb-4 text-base-content/20" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
          <p class="text-lg font-semibold text-base-content/60 mb-2">No articles found</p>
          <p class="text-sm text-base-content/40">Try different keywords</p>
        </div>
      `;
      return;
    }

    const html = results.map(item => {
      const tags = (item.tags || []).slice(0, 3);
      const snippet = item.snippet || item.description || '';
      const truncatedSnippet = snippet.length > 80 ? snippet.substring(0, 80) + '...' : snippet;

      return `
        <a href="/articles/${item.slug}.html" class="block px-4 py-4 mb-2 last:mb-0 bg-base-200/30 hover:bg-base-200 rounded-xl transition-all duration-200 group">
          <div class="flex flex-col gap-3">
            <h3 class="font-semibold text-base text-base-content group-hover:text-primary transition-colors leading-snug line-clamp-2">${item.title}</h3>
            ${truncatedSnippet ? `<p class="text-sm text-base-content/70 leading-relaxed line-clamp-2">${truncatedSnippet}</p>` : ''}
            <div class="flex flex-wrap items-center gap-3 text-xs text-base-content/60">
              <span class="font-medium">${formatDate(item.published_at)}</span>
              ${item.language ? `<span class="flex items-center gap-1.5"><span class="w-1 h-1 rounded-full bg-base-content/30"></span>${getLanguageFlag(item.language)}</span>` : ''}
              ${tags.length > 0 ? `<span class="flex items-center gap-2">${tags.map(tag => `<span class="px-2.5 py-1 bg-yellow-100 group-hover:bg-yellow-200 rounded-full transition-colors">${tag}</span>`).join('')}</span>` : ''}
            </div>
          </div>
        </a>
      `;
    }).join('');

    searchResults.innerHTML = html;
  }

  function search(query) {
    if (!query || query.length < 2) {
      searchResults.classList.add('hidden');
      return;
    }

    // Apply language filter if active
    const filters = window.blogFilters ? window.blogFilters.getFilters() : { lang: 'all' };

    // Score and filter results
    const scored = searchIndex
      .map(item => ({
        item,
        score: scoreMatch(item, query)
      }))
      .filter(({score, item}) => {
        if (score === 0) return false;

        // Apply language filter
        if (filters.lang !== 'all') {
          const language = item.language || 'en';
          if (filters.lang === 'pt') {
            return language === 'pt-BR' || language === 'pt';
          }
          return language === filters.lang;
        }

        return true;
      })
      .sort((a, b) => b.score - a.score)
      .map(({item}) => item);

    renderResults(scored);
    searchResults.classList.remove('hidden');
  }

  // Toggle clear button visibility
  function toggleClearButton() {
    if (searchClear) {
      if (searchInput.value.length > 0) {
        searchClear.classList.remove('hidden');
      } else {
        searchClear.classList.add('hidden');
      }
    }
  }

  // Clear search
  if (searchClear) {
    searchClear.addEventListener('click', () => {
      searchInput.value = '';
      searchResults.classList.add('hidden');
      toggleClearButton();
      searchInput.focus();
    });
  }

  // Search on input
  searchInput.addEventListener('input', (e) => {
    search(e.target.value);
    toggleClearButton();
  });

  // Close dropdown when clicking outside
  document.addEventListener('click', (e) => {
    if (!searchInput.contains(e.target) && !searchResults.contains(e.target)) {
      searchResults.classList.add('hidden');
    }
  });

  // Close on ESC key
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      searchResults.classList.add('hidden');
      searchInput.blur();
    }
  });

  // Initialize
  async function init() {
    await loadSearchIndex();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
