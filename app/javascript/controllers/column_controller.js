import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["list", "jumpBar", "newCount"];
  static values = { id: Number };

  connect() {
    this.pendingEvents = [];
    this.isAtTop = true;
    this.newEventCount = 0;

    this.scrollHandler = this.#onScroll.bind(this);
    const column = this.listTarget.closest(".column");
    column?.addEventListener("scroll", this.scrollHandler);

    this.observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        for (const node of mutation.addedNodes) {
          if (node.nodeType === Node.ELEMENT_NODE && !this.isAtTop) {
            const isPrepend = mutation.target.firstElementChild === node;
            if (isPrepend) this.#onNewEvent(node);
          }
        }
      }
    });

    this.observer.observe(this.listTarget, { childList: true });
  }

  disconnect() {
    const column = this.listTarget.closest(".column");
    column?.removeEventListener("scroll", this.scrollHandler);
    this.observer?.disconnect();
  }

  #onScroll(event) {
    if (!this.hasListTarget || !this.hasJumpBarTarget) return;

    const el = event.target;
    const atTop = el.scrollTop < 80;

    if (atTop !== this.isAtTop) {
      this.isAtTop = atTop;
      if (atTop) this.#flushPending();
    }

    this.jumpBarTarget.classList.toggle("hidden", atTop);
  }

  #onNewEvent(element) {
    if (this.isAtTop) return;

    this.pendingEvents.push(element);
    this.newEventCount++;
    this.newCountTarget.textContent = `· ${this.newEventCount} new event${this.newEventCount > 1 ? "s" : ""}`;
    this.newCountTarget.classList.remove("hidden");

    element.remove();
  }

  #flushPending() {
    if (!this.hasListTarget) return;

    const list = this.listTarget;
    [...this.pendingEvents].reverse().forEach((el) => list.prepend(el));
    this.pendingEvents = [];
    this.newEventCount = 0;
    this.newCountTarget.classList.add("hidden");
  }

  jumpToTop() {
    const column = this.listTarget.closest(".column");
    column?.scrollTo({ top: 0, behavior: "smooth" });
  }
}
