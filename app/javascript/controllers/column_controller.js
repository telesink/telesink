import { Controller } from "@hotwired/stimulus";

const MAX_ITEMS = 200;
const MAX_PENDING = 100;

export default class extends Controller {
  static targets = ["list", "jumpBar", "newCount"];

  static values = {
    cutoff: String,
    columnId: String,
    sinkId: String,
  };

  connect() {
    this.pendingEvents = [];
    this.newEventCount = 0;
    this.isAtTop = true;
    this.cutoffTime = null;
    this.hiddenSince = null;
    this.storageKey = `column-cutoff-${this.sinkIdValue}-${this.columnIdValue}`;
    this._syncTimer = null;

    this.scrollHandler = this.#onScroll.bind(this);
    this.element.addEventListener("scroll", this.scrollHandler, {
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

    this.isAtTop = this.element.scrollTop < 80;

    this.#insertSeenDelimiter();
  }

  disconnect() {
    this.element?.removeEventListener("scroll", this.scrollHandler);
    document.removeEventListener("visibilitychange", this.visibilityHandler);
    this.observer?.disconnect();
    clearTimeout(this._syncTimer);

    if (this.isAtTop) {
      this.#syncCutoffToServer();
    }

    this.pendingEvents = [];
  }

  #setupCutoff() {
    let serverCutoff = null;
    if (this.cutoffValue) {
      const parsed = new Date(this.cutoffValue);
      if (!isNaN(parsed.getTime())) serverCutoff = parsed;
    }

    let clientCutoff = null;
    const stored = localStorage.getItem(this.storageKey);
    if (stored) {
      const parsed = new Date(stored);
      if (!isNaN(parsed.getTime())) clientCutoff = parsed;
    }

    if (clientCutoff && serverCutoff) {
      this.cutoffTime =
        clientCutoff > serverCutoff ? clientCutoff : serverCutoff;
    } else {
      this.cutoffTime = clientCutoff || serverCutoff;
    }
  }

  #markAsViewedLocally() {
    this.cutoffTime = new Date();
    localStorage.setItem(this.storageKey, this.cutoffTime.toISOString());
    this.#removeSeenDelimiter();
  }

  #scheduleSyncToServer() {
    clearTimeout(this._syncTimer);
    this._syncTimer = setTimeout(() => this.#syncCutoffToServer(), 1000);
  }

  #syncCutoffToServer() {
    if (!this.columnIdValue || !this.sinkIdValue) return;

    const csrf =
      document.querySelector('meta[name="csrf-token"]')?.content || "";
    const formData = new FormData();
    formData.append("authenticity_token", csrf);

    fetch(`/sinks/${this.sinkIdValue}/columns/${this.columnIdValue}/views`, {
      method: "POST",
      headers: { "X-CSRF-Token": csrf },
      credentials: "same-origin",
      keepalive: true,
      body: formData,
    }).catch((e) => {
      console.error("Failed to mark column as viewed", e);
    });
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
    if (newestTime.getTime() <= this.cutoffTime.getTime()) return;

    for (const eventEl of events) {
      const timeEl = eventEl.querySelector("time");
      if (!timeEl) continue;

      if (
        new Date(timeEl.getAttribute("datetime")).getTime() <=
        this.cutoffTime.getTime()
      ) {
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

    return div;
  }

  #handlePrepend(node) {
    if (this.isAtTop) {
      this.#trimBottom();

      if (document.visibilityState === "visible") {
        const timeEl = node.querySelector("time");
        if (timeEl) {
          const eventTime = new Date(timeEl.getAttribute("datetime"));
          if (
            !this.cutoffTime ||
            eventTime.getTime() > this.cutoffTime.getTime()
          ) {
            this.cutoffTime = eventTime;
          }
        }
        this.#markAsViewedLocally();
        this.#scheduleSyncToServer();
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
    const scrollTop = e.target.scrollTop;
    const atTop = scrollTop < 80;

    if (atTop !== this.isAtTop) {
      this.isAtTop = atTop;

      if (atTop) {
        this.#flushPending();
      }
    }

    this.jumpBarTarget.classList.toggle("hidden", atTop);

    const delimiter = this.listTarget.querySelector(".seen-delimiter");
    if (delimiter) {
      const delimiterTop = delimiter.getBoundingClientRect().top + scrollTop;
      if (scrollTop > delimiterTop + 50) {
        this.#markAsViewedLocally();
        this.#scheduleSyncToServer();
      }
    }
  }

  #flushPending() {
    [...this.pendingEvents]
      .reverse()
      .forEach((el) => this.listTarget.prepend(el));
    this.pendingEvents = [];
    this.newEventCount = 0;
    this.newCountTarget.classList.add("hidden");
    this.#trimBottom();
  }

  #trimBottom() {
    while (this.listTarget.children.length > MAX_ITEMS) {
      this.listTarget.lastElementChild?.remove();
    }
  }

  #trimTop() {
    let removedHeight = 0;

    while (this.listTarget.children.length > MAX_ITEMS) {
      const el = this.listTarget.firstElementChild;
      if (!el) break;

      removedHeight += el.offsetHeight;
      el.remove();
    }

    if (removedHeight > 0) {
      this.element.scrollTop -= removedHeight;
    }
  }

  jumpToTop() {
    this.element?.scrollTo({
      top: 0,
      behavior: "smooth",
    });
  }
}
