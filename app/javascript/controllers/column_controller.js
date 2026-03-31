import { Controller } from "@hotwired/stimulus";

const MAX_ITEMS = 200;
const MAX_PENDING = 100;

export default class extends Controller {
  static targets = ["list", "jumpBar", "newCount"];
  static values = { cutoff: String, columnId: String, sinkId: String };

  connect() {
    this.pendingEvents = [];
    this.newEventCount = 0;
    this.isAtTop = true;
    this.cutoffTime = null;
    this.hiddenSince = null;

    this.columnEl = this.element;

    this.scrollHandler = this.#onScroll.bind(this);
    this.columnEl.addEventListener("scroll", this.scrollHandler, {
      passive: true,
    });

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

    this.isAtTop = this.columnEl.scrollTop < 80;

    this.#insertSeenDelimiter();

    this._markAsViewedDebounced = this.#debounce(
      this.#markAsViewed.bind(this),
      1000,
    );
  }

  disconnect() {
    this.columnEl?.removeEventListener("scroll", this.scrollHandler);
    document.removeEventListener("visibilitychange", this.visibilityHandler);
    this.observer?.disconnect();
    this.pendingEvents = [];
    this._markAsViewedDebounced = null;
  }

  #debounce(fn, ms) {
    let timer;
    return (...args) => {
      clearTimeout(timer);
      timer = setTimeout(() => fn.apply(this, args), ms);
    };
  }

  #setupCutoff() {
    if (!this.cutoffValue) return;
    this.cutoffTime = new Date(this.cutoffValue);
    if (isNaN(this.cutoffTime.getTime())) this.cutoffTime = null;
  }

  async #markAsViewed() {
    if (!this.columnIdValue || !this.sinkIdValue) return;

    this.cutoffTime = new Date();
    this.#removeSeenDelimiter();

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content;

    try {
      await fetch(
        `/sinks/${this.sinkIdValue}/columns/${this.columnIdValue}/viewed`,
        {
          method: "POST",
          headers: { "X-CSRF-Token": csrf || "" },
          credentials: "same-origin",
        },
      );
    } catch (e) {
      console.error("Failed to mark column as viewed", e);
    }
  }

  #onVisibilityChange() {
    if (document.visibilityState === "visible") {
      if (this.hiddenSince) {
        const hasNewEvents = Array.from(
          this.listTarget.querySelectorAll(".event-preview"),
        ).some((el) => {
          const t = el.querySelector("time");
          return (
            t &&
            new Date(t.getAttribute("datetime")).getTime() > this.hiddenSince
          );
        });

        if (hasNewEvents) {
          this.#insertSeenDelimiter();
        } else {
          this.#removeSeenDelimiter();
        }

        this.hiddenSince = null;
      }
    } else {
      this.hiddenSince = Date.now();
    }
  }

  #insertSeenDelimiter() {
    if (!this.cutoffTime) return;

    this.#removeSeenDelimiter();

    const events = Array.from(
      this.listTarget.querySelectorAll(".event-preview"),
    );
    if (!events.length) return;

    const firstTime = events[0].querySelector("time");
    if (!firstTime) return;

    const newestTime = new Date(firstTime.getAttribute("datetime"));
    if (newestTime <= this.cutoffTime) return;

    for (const eventEl of events) {
      const timeEl = eventEl.querySelector("time");
      if (!timeEl) continue;
      if (new Date(timeEl.getAttribute("datetime")) <= this.cutoffTime) {
        eventEl.before(this.#createSeenDelimiter());
        break;
      }
    }
  }

  #removeSeenDelimiter() {
    this.listTarget
      .querySelectorAll(".seen-delimiter")
      .forEach((el) => el.remove());
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

      if (document.visibilityState === "visible") {
        const timeEl = node.querySelector("time");
        if (timeEl) {
          const eventTime = new Date(timeEl.getAttribute("datetime"));
          if (!this.cutoffTime || eventTime > this.cutoffTime) {
            this.cutoffTime = eventTime;
          }
        }
        this._markAsViewedDebounced();
      }

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
    const atTop = e.target.scrollTop < 80;

    if (atTop !== this.isAtTop) {
      this.isAtTop = atTop;

      if (atTop) {
        this.#flushPending();
        this._markAsViewedDebounced();
      }
    }

    this.jumpBarTarget.classList.toggle("hidden", atTop);
  }

  #flushPending() {
    const list = this.listTarget;
    [...this.pendingEvents].reverse().forEach((el) => list.prepend(el));
    this.pendingEvents = [];
    this.newEventCount = 0;
    this.newCountTarget.classList.add("hidden");
    this.#trimBottom();
  }

  #trimBottom() {
    const list = this.listTarget;

    while (list.children.length > MAX_ITEMS) {
      list.lastElementChild?.remove();
    }
  }

  #trimTop() {
    const list = this.listTarget;
    let removedHeight = 0;

    while (list.children.length > MAX_ITEMS) {
      const el = list.firstElementChild;
      if (!el) break;

      removedHeight += el.offsetHeight;
      el.remove();
    }

    if (removedHeight > 0) {
      this.columnEl.scrollTop -= removedHeight;
    }
  }

  jumpToTop() {
    this.columnEl?.scrollTo({ top: 0, behavior: "smooth" });
  }
}
