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
    const visibleArticles = allArticles.filter(
      article => article.style.display !== 'none'
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

    const visibleArticles = allArticles.filter(
      article => article.style.display !== 'none'
    );

    const start = (page - 1) * ARTICLES_PER_PAGE;
    const end = start + ARTICLES_PER_PAGE;

    // Hide all first
    allArticles.forEach(article => {
      article.classList.add('hidden');
    });

    // Show only current page items
    visibleArticles.forEach((article, index) => {
      if (index >= start && index < end) {
        article.classList.remove('hidden');
      }
    });

    renderPagination();
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
      <div class="flex items-center justify-center gap-4">
        <button class="px-3 py-2 rounded-lg border border-base-300 bg-transparent hover:bg-base-200 text-base-content transition-colors disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-transparent cursor-pointer" id="prev-page" onclick="window.pagination.prevPage()" aria-label="Previous page">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5 pointer-events-none" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5 8.25 12l7.5-7.5"/>
          </svg>
        </button>

        <span class="text-sm text-base-content/70">
          Page ${currentPage} of ${totalPages}
        </span>

        <button class="px-3 py-2 rounded-lg border border-base-300 bg-transparent hover:bg-base-200 text-base-content transition-colors disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-transparent cursor-pointer" id="next-page" onclick="window.pagination.nextPage()" aria-label="Next page">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5 pointer-events-none" aria-hidden="true">
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
