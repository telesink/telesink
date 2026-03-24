import { Controller } from "@hotwired/stimulus";

const MAX_ITEMS = 200;
const MAX_PENDING = 100;

export default class extends Controller {
  static targets = ["list", "jumpBar", "newCount"];

  connect() {
    this.pendingEvents = [];
    this.newEventCount = 0;
    this.isAtTop = true;

    this.columnEl = this.element.closest(".column");

    this.scrollHandler = this.#onScroll.bind(this);
    this.columnEl?.addEventListener("scroll", this.scrollHandler);

    this.observer = new MutationObserver((mutations) => {
      for (const m of mutations) {
        for (const node of m.addedNodes) {
          if (node.nodeType !== Node.ELEMENT_NODE) continue;

          const isPrepend = m.target.firstElementChild === node;

          if (isPrepend) {
            this.#handlePrepend(node);
          } else {
            this.#handleAppend(node);
          }
        }
      }
    });

    this.observer.observe(this.listTarget, { childList: true });
  }

  disconnect() {
    this.columnEl?.removeEventListener("scroll", this.scrollHandler);
    this.observer?.disconnect();
    this.pendingEvents = [];
  }

  #handlePrepend(node) {
    if (this.isAtTop) {
      this.#trimBottom();
      return;
    }

    // buffer new events
    if (this.pendingEvents.length >= MAX_PENDING) {
      this.pendingEvents.shift();
    }

    this.pendingEvents.push(node);
    this.newEventCount++;

    this.newCountTarget.textContent = `· ${this.newEventCount} new event${
      this.newEventCount > 1 ? "s" : ""
    }`;
    this.newCountTarget.classList.remove("hidden");

    node.remove();
  }

  #handleAppend(_node) {
    if (!this.isAtTop) {
      this.#trimTop();
    }
  }

  #onScroll(e) {
    const el = e.target;
    const atTop = el.scrollTop < 80;

    if (atTop !== this.isAtTop) {
      this.isAtTop = atTop;

      if (atTop) {
        this.#flushPending();
      }
    }

    this.jumpBarTarget.classList.toggle("hidden", atTop);
  }

  #flushPending() {
    const list = this.listTarget;

    [...this.pendingEvents].reverse().forEach((el) => {
      list.prepend(el);
    });

    this.pendingEvents = [];
    this.newEventCount = 0;
    this.newCountTarget.classList.add("hidden");

    this.#trimBottom(); // safe here
  }

  #trimBottom() {
    const list = this.listTarget;

    while (list.children.length > MAX_ITEMS) {
      list.lastElementChild?.remove(); // remove oldest
    }
  }

  #trimTop() {
    const list = this.listTarget;
    const column = this.columnEl;

    let removedHeight = 0;

    while (list.children.length > MAX_ITEMS) {
      const el = list.firstElementChild;
      if (!el) break;

      removedHeight += el.offsetHeight;
      el.remove();
    }

    // preserve scroll position
    if (removedHeight > 0) {
      column.scrollTop -= removedHeight;
    }
  }

  jumpToTop() {
    this.columnEl?.scrollTo({ top: 0, behavior: "smooth" });
  }
}
