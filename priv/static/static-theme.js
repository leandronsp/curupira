// Client-side theme toggle for static site
(function() {
  const themeToggle = document.getElementById('theme-toggle');
  const themeToggleMobile = document.getElementById('theme-toggle-mobile');

  if (!themeToggle && !themeToggleMobile) return;

  // Load theme from localStorage or default to 'light'
  const savedTheme = localStorage.getItem('theme') || 'light';
  setTheme(savedTheme);

  // Add event listener to desktop toggle
  if (themeToggle) {
    themeToggle.addEventListener('click', toggleTheme);
  }

  // Add event listener to mobile toggle
  if (themeToggleMobile) {
    themeToggleMobile.addEventListener('click', toggleTheme);
  }

  function toggleTheme() {
    const currentTheme = document.documentElement.getAttribute('data-theme');
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
    setTheme(newTheme);
    localStorage.setItem('theme', newTheme);
  }

  function setTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);

    // Update all sun/moon icons (both mobile and desktop)
    const sunIcons = document.querySelectorAll('.sun-icon');
    const moonIcons = document.querySelectorAll('.moon-icon');

    if (theme === 'dark') {
      sunIcons.forEach(icon => icon.classList.remove('hidden'));
      moonIcons.forEach(icon => icon.classList.add('hidden'));
    } else {
      sunIcons.forEach(icon => icon.classList.add('hidden'));
      moonIcons.forEach(icon => icon.classList.remove('hidden'));
    }
  }
})();
