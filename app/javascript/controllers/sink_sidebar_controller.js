import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.pendingRefresh = false;
    this.clickHandler = this.#onClick.bind(this);
    this.frameLoadHandler = this.#onFrameLoad.bind(this);

    this.element.addEventListener("click", this.clickHandler);
    document.addEventListener("turbo:frame-load", this.frameLoadHandler);
  }

  disconnect() {
    this.element.removeEventListener("click", this.clickHandler);
    document.removeEventListener("turbo:frame-load", this.frameLoadHandler);
  }

  #onClick(event) {
    const link = event.target.closest("[data-sink-sidebar-link]");

    if (!link || !this.element.contains(link)) return;
    if (event.defaultPrevented) return;
    if (event.button !== 0) return;
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;

    this.pendingRefresh = true;
  }

  #onFrameLoad(event) {
    if (!this.pendingRefresh) return;
    if (event.target.id !== "main_content") return;

    this.pendingRefresh = false;
    this.#collapseMobileDrawer();
    this.#refresh();
  }

  #collapseMobileDrawer() {
    const drawer = this.element.closest(".sidebar__drawer");
    if (!drawer) return;
    if (!window.matchMedia("(max-width: 760px)").matches) return;

    drawer.open = false;
  }

  #refresh() {
    fetch(window.location.href, {
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "Turbo-Frame": "sinks",
      },
      credentials: "same-origin",
    })
      .then((response) => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`);

        return response.text();
      })
      .then((html) => window.Turbo.renderStreamMessage(html))
      .catch((error) => {
        console.error("Failed to refresh sink sidebar", error);
      });
  }
}
