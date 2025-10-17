// Client-side search for static site
(function() {
  const searchInput = document.getElementById('search-input');
  if (!searchInput) return;

  const articlesContainer = document.getElementById('articles-container');
  const noResults = document.getElementById('no-results');
  let allArticles = [];

  function init() {
    allArticles = Array.from(articlesContainer.querySelectorAll('.article-card'));
  }

  searchInput.addEventListener('input', (e) => {
    const query = e.target.value.toLowerCase().trim();

    // Update article visibility
    allArticles.forEach(card => {
      const title = card.getAttribute('data-title') || '';
      const tags = card.getAttribute('data-tags') || '';

      const matches = title.includes(query) || tags.includes(query);

      if (matches || query === '') {
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

    if (visibleCards.length === 0 && query !== '') {
      noResults.classList.remove('hidden');
    } else {
      noResults.classList.add('hidden');
    }

    // Trigger pagination update
    if (window.pagination && window.pagination.handleSearch) {
      window.pagination.handleSearch();
    }
  });

  // Initialize on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
