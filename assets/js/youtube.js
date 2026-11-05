/* Lite-YouTube embed Web Component: accessible, privacy-enhanced, and CLS-safe.
   Delays iframe creation and third-party Google requests until the reader clicks play.
   Uses https://www.youtube-nocookie.com to avoid tracking cookies. */
(function () {
  if (typeof customElements === "undefined") return;
  if (customElements.get("lite-youtube")) return;

  var ID_PATTERN = /^[A-Za-z0-9_-]{11}$/;

  class LiteYTEmbed extends HTMLElement {
    connectedCallback() {
      var id = this.getAttribute("videoid");
      if (!id || !ID_PATTERN.test(id)) return;
      this.videoId = id;

      var title = this.getAttribute("data-title") || this.getAttribute("title") || "Play video";
      this.playLabel = title;

      // Poster thumbnail: use official YouTube thumbnail CDN
      if (!this.style.backgroundImage) {
        this.style.backgroundImage = 'url("https://i.ytimg.com/vi/' + encodeURIComponent(id) + '/hqdefault.jpg")';
      }

      // Preconnect on pointerover or focus for faster subsequent playback
      var preconnected = false;
      var preconnect = function () {
        if (preconnected) return;
        preconnected = true;
        ["https://www.youtube-nocookie.com", "https://i.ytimg.com"].forEach(function (url) {
          var link = document.createElement("link");
          link.rel = "preconnect";
          link.href = url;
          document.head.appendChild(link);
        });
      };
      this.addEventListener("pointerover", preconnect, { once: true });
      this.addEventListener("focusin", preconnect, { once: true });

      // Click to activate
      var self = this;
      this.addEventListener("click", function () {
        self.activate();
      });
    }

    activate() {
      if (this.classList.contains("lyt-activated")) return;
      this.classList.add("lyt-activated");

      var start = this.getAttribute("data-start");
      var startParam = (start && /^\d+$/.test(start)) ? "&start=" + start : "";

      var iframe = document.createElement("iframe");
      iframe.width = "100%";
      iframe.height = "100%";
      iframe.title = this.playLabel;
      iframe.allow = "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture";
      iframe.allowFullscreen = true;
      iframe.referrerPolicy = "strict-origin-when-cross-origin";
      iframe.src = "https://www.youtube-nocookie.com/embed/" + encodeURIComponent(this.videoId) + "?autoplay=1&rel=0" + startParam;

      this.appendChild(iframe);
      iframe.focus();
    }
  }

  customElements.define("lite-youtube", LiteYTEmbed);
})();
