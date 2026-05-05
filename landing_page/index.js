(function () {
  var STORAGE_KEY = "pasahero-theme";
  var root = document.documentElement;

  function getStoredTheme() {
    try {
      return localStorage.getItem(STORAGE_KEY);
    } catch (e) {
      return null;
    }
  }

  function getPreferredTheme() {
    var stored = getStoredTheme();
    if (stored === "light" || stored === "dark") return stored;
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  }

  function applyTheme(theme) {
    root.setAttribute("data-theme", theme);
    root.style.colorScheme = theme === "dark" ? "dark" : "light";
    var toggle = document.getElementById("theme-toggle");
    if (toggle) toggle.checked = theme === "dark";
  }

  applyTheme(getPreferredTheme());

  var themeToggle = document.getElementById("theme-toggle");
  if (themeToggle) {
    themeToggle.addEventListener("change", function () {
      var next = this.checked ? "dark" : "light";
      try {
        localStorage.setItem(STORAGE_KEY, next);
      } catch (e) {}
      applyTheme(next);
    });
  }

  window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", function () {
    if (getStoredTheme()) return;
    applyTheme(getPreferredTheme());
  });

  document.getElementById("year").textContent = new Date().getFullYear();
})();
