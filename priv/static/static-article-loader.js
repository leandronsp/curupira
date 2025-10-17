// Article loader for static site - loads articles inline in right column
(function() {
  let currentSlug = null;
  let articleCache = {};

  // Load article content inline
  window.loadArticle = async function(slug) {
    if (currentSlug === slug) return;

    const listView = document.getElementById('articles-list-view');
    const viewer = document.getElementById('article-viewer');
    const content = document.getElementById('article-content');

    if (!viewer || !content || !listView) return;

    // Hide list, show viewer
    listView.classList.add('hidden');
    viewer.classList.remove('hidden');

    // Show loading state
    content.innerHTML = `
      <div class="text-center mt-20">
        <div class="loading loading-spinner loading-lg text-primary"></div>
        <p class="text-base-content/60 mt-4">Loading article...</p>
      </div>
    `;

    // Scroll to top of main content column
    const mainColumn = viewer.parentElement;
    if (mainColumn) {
      mainColumn.scrollTop = 0;
      window.scrollTo(0, 0);
    }

    try {
      // Check cache first
      if (articleCache[slug]) {
        displayArticle(articleCache[slug]);
        currentSlug = slug;
        return;
      }

      // Fetch article HTML
      const response = await fetch(`/articles/${slug}.html`);
      if (!response.ok) throw new Error('Article not found');

      const htmlText = await response.text();

      // Parse the HTML to extract article content
      const parser = new DOMParser();
      const doc = parser.parseFromString(htmlText, 'text/html');
      const articleElement = doc.querySelector('article');

      if (!articleElement) throw new Error('Article content not found');

      // Cache it
      articleCache[slug] = articleElement.outerHTML;

      // Display it
      displayArticle(articleCache[slug]);
      currentSlug = slug;

      // Highlight active article in list
      highlightActiveArticle(slug);

    } catch (error) {
      console.error('Error loading article:', error);
      content.innerHTML = `
        <div class="text-center text-error mt-20">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 mx-auto mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
          </svg>
          <p class="text-lg">Failed to load article</p>
          <p class="text-sm text-base-content/60 mt-2">${error.message}</p>
        </div>
      `;
    }
  };

  // Show article list (back button)
  window.showArticleList = function() {
    const listView = document.getElementById('articles-list-view');
    const viewer = document.getElementById('article-viewer');

    if (!listView || !viewer) return;

    // Show list, hide viewer
    viewer.classList.add('hidden');
    listView.classList.remove('hidden');

    // Clear current slug
    currentSlug = null;

    // Remove highlights
    document.querySelectorAll('.article-card').forEach(card => {
      card.classList.remove('ring-2', 'ring-primary', 'border-primary');
    });

    // Scroll to top
    window.scrollTo(0, 0);
  };

  function displayArticle(articleHTML) {
    const content = document.getElementById('article-content');
    content.innerHTML = articleHTML;
  }

  function highlightActiveArticle(slug) {
    // Remove previous highlights
    document.querySelectorAll('.article-card').forEach(card => {
      card.classList.remove('ring-2', 'ring-primary', 'border-primary');
    });

    // Add highlight to current
    const activeCard = document.querySelector(`[data-slug="${slug}"]`);
    if (activeCard) {
      activeCard.classList.add('ring-2', 'ring-primary', 'border-primary');
    }
  }

  // Setup article theme toggle
  document.addEventListener('DOMContentLoaded', () => {
    const articleToggle = document.getElementById('article-theme-toggle');
    const mainToggle = document.getElementById('theme-toggle');

    if (articleToggle && mainToggle) {
      articleToggle.addEventListener('click', () => {
        // Trigger the main theme toggle
        mainToggle.click();
      });
    }
  });
})();
