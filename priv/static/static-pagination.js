// Pagination with URL persistence
(function() {
  const ARTICLES_PER_PAGE = 10;
  let currentPage = 1;
  let totalPages = 1;
  let allArticles = [];

  function getUrlParams() {
    const params = new URLSearchParams(window.location.search);
    return {
      page: parseInt(params.get('page')) || 1
    };
  }

  function updateUrlParams(page) {
    const params = new URLSearchParams(window.location.search);

    if (page === 1) {
      params.delete('page');
    } else {
      params.set('page', page);
    }

    const newUrl = params.toString()
      ? `${window.location.pathname}?${params.toString()}`
      : window.location.pathname;

    window.history.pushState({}, '', newUrl);
  }

  function init() {
    allArticles = Array.from(document.querySelectorAll('.article-card'));

    // Don't show page yet - let filters initialize first
    // The filter system will trigger handleSearch() which will restore the page from URL
  }

  function recalculatePagination() {
    // Exclude pinned article from pagination count
    const visibleArticles = allArticles.filter(
      article => article.style.display !== 'none' && !article.classList.contains('pinned-article')
    );
    totalPages = Math.max(1, Math.ceil(visibleArticles.length / ARTICLES_PER_PAGE));

    // If current page is beyond total pages, go to last page
    if (currentPage > totalPages) {
      currentPage = totalPages;
    }
  }

  function handleSearch() {
    recalculatePagination();

    // Restore page from URL if available, otherwise reset to page 1
    const params = getUrlParams();
    const targetPage = params.page <= totalPages ? params.page : 1;

    showPage(targetPage, false);  // Don't scroll when filtering
  }

  function showPage(page, shouldScroll = true) {
    currentPage = page;

    // Separate pinned and regular articles
    const pinnedArticle = allArticles.find(
      article => article.style.display !== 'none' && article.classList.contains('pinned-article')
    );

    const regularArticles = allArticles.filter(
      article => article.style.display !== 'none' && !article.classList.contains('pinned-article')
    );

    const start = (page - 1) * ARTICLES_PER_PAGE;
    const end = start + ARTICLES_PER_PAGE;

    // Hide all first
    allArticles.forEach(article => {
      article.classList.add('hidden');
    });

    // Always show pinned article if it's visible
    if (pinnedArticle) {
      pinnedArticle.classList.remove('hidden');
    }

    // Show only current page items from regular articles
    regularArticles.forEach((article, index) => {
      if (index >= start && index < end) {
        article.classList.remove('hidden');
      }
    });

    renderPagination();
    renderEmptyState(regularArticles.length === 0);
    updateUrlParams(page);
  }

  function renderPagination() {
    const container = document.getElementById('pagination-container');
    if (!container) return;

    // Update top page indicator
    const currentPageEl = document.getElementById('current-page');
    const totalPagesEl = document.getElementById('total-pages');
    if (currentPageEl) currentPageEl.textContent = currentPage;
    if (totalPagesEl) totalPagesEl.textContent = totalPages;

    const visibleArticles = allArticles.filter(
      article => article.style.display !== 'none'
    );

    if (totalPages <= 1) {
      container.innerHTML = '';
      return;
    }

    const start = Math.min((currentPage - 1) * ARTICLES_PER_PAGE + 1, visibleArticles.length);
    const end = Math.min(currentPage * ARTICLES_PER_PAGE, visibleArticles.length);

    container.innerHTML = `
      <div class="flex items-center justify-center gap-6 mt-16">
        <button class="px-4 py-3 rounded-full border-2 border-base-300 bg-base-100 hover:bg-base-200 hover:border-primary/30 text-base-content transition-all disabled:opacity-30 disabled:cursor-not-allowed disabled:hover:bg-base-100 disabled:hover:border-base-300 cursor-pointer shadow-sm" id="prev-page" onclick="window.pagination.prevPage()" aria-label="Previous page">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-5 h-5 pointer-events-none" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5 8.25 12l7.5-7.5"/>
          </svg>
        </button>

        <span class="text-base text-base-content/80 font-medium px-4">
          Page ${currentPage} of ${totalPages}
        </span>

        <button class="px-4 py-3 rounded-full border-2 border-base-300 bg-base-100 hover:bg-base-200 hover:border-primary/30 text-base-content transition-all disabled:opacity-30 disabled:cursor-not-allowed disabled:hover:bg-base-100 disabled:hover:border-base-300 cursor-pointer shadow-sm" id="next-page" onclick="window.pagination.nextPage()" aria-label="Next page">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-5 h-5 pointer-events-none" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" d="m8.25 4.5 7.5 7.5-7.5 7.5"/>
          </svg>
        </button>
      </div>
    `;

    updatePaginationButtons();
  }

  function updatePaginationButtons() {
    const prevBtn = document.getElementById('prev-page');
    const nextBtn = document.getElementById('next-page');

    if (prevBtn) {
      prevBtn.disabled = currentPage === 1;
    }

    if (nextBtn) {
      nextBtn.disabled = currentPage === totalPages;
    }
  }

  function renderEmptyState(isEmpty) {
    let emptyStateEl = document.getElementById('empty-state');

    if (isEmpty) {
      if (!emptyStateEl) {
        // Create empty state element if it doesn't exist
        const container = document.querySelector('main');
        if (container) {
          emptyStateEl = document.createElement('div');
          emptyStateEl.id = 'empty-state';
          emptyStateEl.className = 'text-center py-16';
          container.appendChild(emptyStateEl);
        }
      }

      if (emptyStateEl) {
        emptyStateEl.innerHTML = `
          <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 mx-auto mb-4 text-base-content/20" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
          <p class="text-lg font-semibold text-base-content/60 mb-2">No articles found</p>
          <p class="text-sm text-base-content/40">Try adjusting your filters</p>
        `;
      }
    } else {
      // Remove empty state if it exists
      if (emptyStateEl) {
        emptyStateEl.remove();
      }
    }
  }

  function nextPage() {
    if (currentPage < totalPages) {
      showPage(currentPage + 1);
    }
  }

  function prevPage() {
    if (currentPage > 1) {
      showPage(currentPage - 1);
    }
  }

  // Expose functions globally
  window.pagination = {
    nextPage,
    prevPage,
    handleSearch
  };

  // Initialize on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
