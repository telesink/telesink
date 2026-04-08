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
          if (node.classList.contains("day-delimiter")) continue;

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

    this.#revealSeenDelimiter();
    this.#rebuildDayDelimiters();
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
    this.#scheduleSyncToServer();
  }

  #updateCutoffToNow() {
    this.cutoffTime = new Date();
    localStorage.setItem(this.storageKey, this.cutoffTime.toISOString());
    this.#scheduleSyncToServer();
  }

  #scheduleSyncToServer() {
    clearTimeout(this._syncTimer);
    this._syncTimer = setTimeout(() => this.#syncCutoffToServer(), 500);
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
    }).catch((e) => console.error("Failed to mark column as viewed", e));
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
          this.#insertDelimiterForTabReturn();
        } else {
          this.#removeSeenDelimiter();
        }

        this.hiddenSince = null;
      }
    } else {
      this.hiddenSince = Date.now();
    }
  }

  #insertDelimiterForTabReturn() {
    if (!this.hiddenSince) return;

    this.#removeSeenDelimiter();

    const events = Array.from(
      this.listTarget.querySelectorAll(".event-preview"),
    );
    if (!events.length) return;

    for (const eventEl of events) {
      const timeEl = eventEl.querySelector("time");
      if (!timeEl) continue;

      if (
        new Date(timeEl.getAttribute("datetime")).getTime() <= this.hiddenSince
      ) {
        eventEl.before(this.#createSeenDelimiter());
        this.#updateCutoffToNow();
        return;
      }
    }

    const firstChild = this.listTarget.firstElementChild;
    if (firstChild) firstChild.before(this.#createSeenDelimiter());
    else this.listTarget.prepend(this.#createSeenDelimiter());

    this.#updateCutoffToNow();
  }

  #revealSeenDelimiter() {
    const delimiter = this.listTarget.querySelector(".seen-delimiter");
    if (!delimiter) return;

    if (this.listTarget.firstElementChild === delimiter) {
      delimiter.remove();
      return;
    }

    delimiter.classList.remove("hidden");
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
      }

      this.#rebuildDayDelimiters();

      return;
    }

    if (this.pendingEvents.length >= MAX_PENDING) this.pendingEvents.shift();

    this.pendingEvents.push(node);
    this.newEventCount++;

    this.newCountTarget.textContent = `· ${this.newEventCount} new event${this.newEventCount > 1 ? "s" : ""}`;
    this.newCountTarget.classList.remove("hidden");

    node.remove();
  }

  #handleAppend(_node) {
    if (!this.isAtTop) this.#trimTop();
    this.#rebuildDayDelimiters();
    this.#revealSeenDelimiter();
  }

  #onScroll(e) {
    const scrollTop = e.target.scrollTop;
    const atTop = scrollTop < 80;

    if (atTop !== this.isAtTop) {
      this.isAtTop = atTop;
      if (atTop) this.#flushPending();
    }

    this.jumpBarTarget.classList.toggle("hidden", atTop);
  }

  #flushPending() {
    [...this.pendingEvents]
      .reverse()
      .forEach((el) => this.listTarget.prepend(el));
    this.pendingEvents = [];
    this.newEventCount = 0;
    this.newCountTarget.classList.add("hidden");
    this.#trimBottom();

    this.#rebuildDayDelimiters();
    this.#revealSeenDelimiter();
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
    if (removedHeight > 0) this.element.scrollTop -= removedHeight;
  }

  #rebuildDayDelimiters() {
    this.listTarget
      .querySelectorAll(".day-delimiter")
      .forEach((el) => el.remove());

    const events = Array.from(
      this.listTarget.querySelectorAll(".event-preview-card"),
    );
    let lastDateKey = null;

    events.forEach((eventEl) => {
      const timeEl = eventEl.querySelector("time");
      if (!timeEl) return;

      const date = new Date(timeEl.getAttribute("datetime"));
      const dateKey = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;

      if (dateKey !== lastDateKey) {
        eventEl.before(this.#createDayDelimiter(date));
        lastDateKey = dateKey;
      }
    });
  }

  #createDayDelimiter(date) {
    const div = document.createElement("div");
    div.className = "day-delimiter";

    const span = document.createElement("span");
    span.className = "day-delimiter__label";

    const today = new Date();
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);

    if (this.#isSameDay(date, today)) span.textContent = "Today";
    else if (this.#isSameDay(date, yesterday)) span.textContent = "Yesterday";
    else {
      span.textContent = date.toLocaleDateString(navigator.language, {
        weekday: "long",
        month: "long",
        day: "numeric",
        year: "numeric",
      });
    }

    div.appendChild(span);
    return div;
  }

  #isSameDay(a, b) {
    return (
      a.getFullYear() === b.getFullYear() &&
      a.getMonth() === b.getMonth() &&
      a.getDate() === b.getDate()
    );
  }

  jumpToTop() {
    this.element?.scrollTo({ top: 0, behavior: "smooth" });
    this.isAtTop = true;
    this.jumpBarTarget.classList.add("hidden");
    this.#flushPending();
  }
}
