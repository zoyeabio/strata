/* Lite-YouTube embed Web Component: accessible, privacy-enhanced, and CLS-safe.
   Creates no third-party connection until the reader activates the local link.
   Playback uses YouTube's privacy-enhanced youtube-nocookie.com host. */
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

      var self = this;
      var trigger = this.querySelector(".lite-youtube__btn");
      if (!trigger) return;
      trigger.addEventListener("click", function (event) {
        event.preventDefault();
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
