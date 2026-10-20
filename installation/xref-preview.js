(function () {
  "use strict";

  var previews = window.BOOKDOWN_XREF_PREVIEWS || {};
  var popover;
  var showTimer;
  var hideTimer;
  var activeLink;

  function pageName(pathname) {
    var parts = pathname.split("/");
    return decodeURIComponent(parts[parts.length - 1] || "index.html");
  }

  function previewKey(link) {
    var href = link.getAttribute("href");
    var url;
    var key;
    var targetId;

    if (!href || href.indexOf("#") === -1) {
      return null;
    }

    try {
      url = new URL(href, window.location.href);
    } catch (_error) {
      return null;
    }

    if (!url.hash || url.origin !== window.location.origin) {
      return null;
    }

    targetId = decodeURIComponent(url.hash.slice(1));
    key = pageName(url.pathname) + "#" + targetId;
    if (previews[key]) {
      return key;
    }

    if (targetId.indexOf("ref-") === 0) {
      key = "bibliography.html#" + targetId;
      if (previews[key]) {
        return key;
      }
    }

    return null;
  }

  function positionPopover(link) {
    var linkBox = link.getBoundingClientRect();
    var previewBox = popover.getBoundingClientRect();
    var gap = 9;
    var margin = 12;
    var left = Math.max(
      margin,
      Math.min(linkBox.left, window.innerWidth - previewBox.width - margin)
    );
    var top = linkBox.bottom + gap;

    if (top + previewBox.height > window.innerHeight - margin) {
      top = Math.max(margin, linkBox.top - previewBox.height - gap);
    }

    popover.style.left = left + "px";
    popover.style.top = top + "px";
  }

  function typesetPreview() {
    if (window.MathJax && window.MathJax.Hub) {
      window.MathJax.Hub.Queue(["Typeset", window.MathJax.Hub, popover]);
    } else if (window.MathJax && window.MathJax.typesetPromise) {
      window.MathJax.typesetPromise([popover]);
    }
  }

  function showPreview(link, key) {
    window.clearTimeout(hideTimer);
    activeLink = link;
    popover.innerHTML = previews[key];
    Array.prototype.forEach.call(
      popover.querySelectorAll("[id]"),
      function (element) {
        element.removeAttribute("id");
      }
    );
    popover.classList.add("is-visible");
    popover.setAttribute("aria-hidden", "false");
    positionPopover(link);
    typesetPreview();
  }

  function queuePreview(link, key, immediate) {
    window.clearTimeout(showTimer);
    window.clearTimeout(hideTimer);
    showTimer = window.setTimeout(function () {
      showPreview(link, key);
    }, immediate ? 0 : 240);
  }

  function hidePreview() {
    window.clearTimeout(showTimer);
    hideTimer = window.setTimeout(function () {
      popover.classList.remove("is-visible");
      popover.setAttribute("aria-hidden", "true");
      popover.innerHTML = "";
      activeLink = null;
    }, 140);
  }

  function initialise() {
    popover = document.createElement("aside");
    popover.className = "xref-preview-popover";
    popover.setAttribute("role", "tooltip");
    popover.setAttribute("aria-hidden", "true");
    document.body.appendChild(popover);

    popover.addEventListener("mouseenter", function () {
      window.clearTimeout(hideTimer);
    });
    popover.addEventListener("mouseleave", hidePreview);

    Array.prototype.forEach.call(
      document.querySelectorAll('a[href*="#"]'),
      function (link) {
        var key;

        if (
          link.classList.contains("anchor-section") ||
          link.closest(".book-summary") ||
          link.closest(".navigation")
        ) {
          return;
        }

        key = previewKey(link);
        if (!key) {
          return;
        }

        link.classList.add("xref-preview-link");
        link.addEventListener("mouseenter", function () {
          queuePreview(link, key, false);
        });
        link.addEventListener("mouseleave", hidePreview);
        link.addEventListener("focus", function () {
          queuePreview(link, key, true);
        });
        link.addEventListener("blur", hidePreview);
      }
    );

    window.addEventListener("scroll", function () {
      if (activeLink && popover.classList.contains("is-visible")) {
        positionPopover(activeLink);
      }
    }, true);
    window.addEventListener("resize", function () {
      if (activeLink && popover.classList.contains("is-visible")) {
        positionPopover(activeLink);
      }
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initialise);
  } else {
    initialise();
  }
}());
