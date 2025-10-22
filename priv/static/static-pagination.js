(function() {
  const ARTICLES_PER_PAGE = 10;
  let currentPage = 1;
  let totalPages = 1;
  let allArticles = [];

  function init() {
    allArticles = Array.from(document.querySelectorAll('.article-card'));
    recalculatePagination();

    // Restore state from sessionStorage if exists
    const savedState = sessionStorage.getItem('homepage-state');
    if (savedState) {
      try {
        const state = JSON.parse(savedState);
        showPage(state.page || 1);
        // Trigger search restoration if needed
        if (state.search) {
          const searchInput = document.getElementById('search-input');
          if (searchInput) {
            searchInput.value = state.search;
            // Dispatch input event to trigger search
            searchInput.dispatchEvent(new Event('input', { bubbles: true }));
          }
        }
      } catch (e) {
        showPage(1);
      }
    } else {
      showPage(1);
    }
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
    currentPage = 1;
    recalculatePagination();
    showPage(1);
  }

  function showPage(page) {
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

    // Save state to sessionStorage
    saveState();

    // Scroll articles container to top
    const container = document.getElementById('articles-container');
    if (container) {
      container.scrollTop = 0;
    }
  }

  function saveState() {
    const searchInput = document.getElementById('search-input');
    const state = {
      page: currentPage,
      search: searchInput ? searchInput.value : ''
    };
    sessionStorage.setItem('homepage-state', JSON.stringify(state));
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
      <div class="flex flex-col items-center gap-4">
        <div class="text-sm text-base-content/70">
          Showing ${start}-${end} of ${visibleArticles.length} articles
        </div>

        <div class="join">
          <button class="join-item btn btn-sm" id="prev-page" onclick="window.pagination.prevPage()" aria-label="Previous page">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
          </button>

          <button class="join-item btn btn-sm no-animation" aria-label="Page ${currentPage} of ${totalPages}">
            Page ${currentPage} of ${totalPages}
          </button>

          <button class="join-item btn btn-sm" id="next-page" onclick="window.pagination.nextPage()" aria-label="Next page">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </button>
        </div>
      </div>
    `;

    updatePaginationButtons();
  }

  function updatePaginationButtons() {
    const prevBtn = document.getElementById('prev-page');
    const nextBtn = document.getElementById('next-page');

    if (prevBtn) {
      prevBtn.disabled = currentPage === 1;
      if (currentPage === 1) {
        prevBtn.classList.add('btn-disabled');
      } else {
        prevBtn.classList.remove('btn-disabled');
      }
    }

    if (nextBtn) {
      nextBtn.disabled = currentPage === totalPages;
      if (currentPage === totalPages) {
        nextBtn.classList.add('btn-disabled');
      } else {
        nextBtn.classList.remove('btn-disabled');
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
