(function () {
  "use strict";

  var TARGET_TEXT = "Workflow Control Plane (SVG Literal Interactive)";
  var HIGHLIGHTED_HTML = "Workflow Control Plane (SVG Literal <span class=\"nav-interactive-red\">Interactive</span>)";

  function patchLink(link) {
    var holder = link.querySelector(".md-ellipsis") || link;
    if (!holder) return;
    if (holder.getAttribute("data-nav-interactive-patched") === "1") return;
    if (holder.textContent.trim() !== TARGET_TEXT) return;
    holder.innerHTML = HIGHLIGHTED_HTML;
    holder.setAttribute("data-nav-interactive-patched", "1");
  }

  function patchAll() {
    var links = document.querySelectorAll("a.md-nav__link, a.md-tabs__link");
    for (var i = 0; i < links.length; i += 1) {
      patchLink(links[i]);
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", patchAll);
  } else {
    patchAll();
  }

  var observer = new MutationObserver(function () {
    patchAll();
  });
  observer.observe(document.documentElement, { childList: true, subtree: true });
})();
