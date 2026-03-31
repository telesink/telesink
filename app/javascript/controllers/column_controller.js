import { Controller } from "@hotwired/stimulus";

const MAX_ITEMS = 200;
const MAX_PENDING = 100;

export default class extends Controller {
  static targets = ["list", "jumpBar", "newCount"];
  static values = { cutoff: String };

  connect() {
    this.pendingEvents = [];
    this.newEventCount = 0;
    this.isAtTop = true;
    this.cutoffTime = null;

    this.columnEl = this.element.closest(".column") || this.element;

    this.scrollHandler = this.#onScroll.bind(this);
    this.columnEl.addEventListener("scroll", this.scrollHandler);

    this.visibilityHandler = this.#onVisibilityChange.bind(this);
    document.addEventListener("visibilitychange", this.visibilityHandler);

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

    this.#setupCutoff();
  }

  disconnect() {
    this.columnEl?.removeEventListener("scroll", this.scrollHandler);
    document.removeEventListener("visibilitychange", this.visibilityHandler);
    this.observer?.disconnect();
    this.pendingEvents = [];
  }

  #setupCutoff() {
    if (!this.cutoffValue) return;
    this.cutoffTime = new Date(this.cutoffValue);
    if (isNaN(this.cutoffTime.getTime())) return;

    this.#insertSeenDelimiter();
  }

  #onVisibilityChange() {
    if (document.visibilityState === "visible") {
      this.#insertSeenDelimiter();
    }
  }

  #insertSeenDelimiter() {
    if (!this.cutoffTime) return;

    const list = this.listTarget;
    list.querySelectorAll(".seen-delimiter").forEach((el) => el.remove());

    const events = Array.from(list.querySelectorAll(".event-preview"));
    if (!events.length) return;

    const newestEventTime = new Date(
      events[0].querySelector("time").getAttribute("datetime"),
    );
    if (newestEventTime <= this.cutoffTime) return;

    for (const eventEl of events) {
      const timeEl = eventEl.querySelector("time");
      if (!timeEl) continue;

      const eventTime = new Date(timeEl.getAttribute("datetime"));

      if (eventTime <= this.cutoffTime) {
        eventEl.before(this.#createSeenDelimiter());
        break;
      }
    }
  }

  #createSeenDelimiter() {
    const div = document.createElement("div");
    div.className = "seen-delimiter";
    div.innerHTML = `
      <div class="seen-line"></div>
      <span class="seen-label">↑ new ↑</span>
      <div class="seen-line"></div>
    `;
    return div;
  }

  #handlePrepend(node) {
    if (this.isAtTop) {
      this.#trimBottom();
      this.#insertSeenDelimiter();
      return;
    }

    if (this.pendingEvents.length >= MAX_PENDING) {
      this.pendingEvents.shift();
    }

    this.pendingEvents.push(node);
    this.newEventCount++;

    this.newCountTarget.textContent = `· ${this.newEventCount} new event${this.newEventCount > 1 ? "s" : ""}`;
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

    this.#trimBottom();
    if (this.cutoffTime) this.#insertSeenDelimiter();
  }

  #trimBottom() {
    const list = this.listTarget;

    while (list.children.length > MAX_ITEMS) {
      list.lastElementChild?.remove();
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

    if (removedHeight > 0) {
      column.scrollTop -= removedHeight;
    }
  }

  jumpToTop() {
    this.columnEl?.scrollTo({ top: 0, behavior: "smooth" });
  }
}
