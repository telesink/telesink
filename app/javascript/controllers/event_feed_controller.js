import { Controller } from "@hotwired/stimulus";

const MAX_ITEMS = 400;
const MAX_PENDING = 200;
const MAX_AUTOFILL_PAGES = 3;
const BOTTOM_THRESHOLD = 80;
const TOP_THRESHOLD = 120;

export default class extends Controller {
  static targets = [
    "detail",
    "jumpBar",
    "list",
    "newCount",
    "olderLoader",
    "scroll",
  ];
  static values = {
    seenCutoff: String,
    viewUrl: String,
  };

  connect() {
    this.pendingEvents = [];
    this.newEventCount = 0;
    this.isAtBottom = true;
    this.autofillPages = 0;
    this.canLoadOlder = false;
    this.seenCutoffTime = this.#parseSeenCutoff();
    this.isFlushing = false;
    this.isLoadingOlder = false;
    this._viewTimer = null;

    this.scrollHandler = this.#onScroll.bind(this);
    this.scrollTarget.addEventListener("scroll", this.scrollHandler, {
      passive: true,
    });

    this.visibilityHandler = this.#onVisibilityChange.bind(this);
    document.addEventListener("visibilitychange", this.visibilityHandler);

    this.observer = new MutationObserver((mutations) => {
      this.#handleMutations(mutations);
    });

    if (this.hasListTarget) {
      this.observer.observe(this.listTarget, { childList: true });
    }

    requestAnimationFrame(() => {
      this.#rebuildDayDelimiters();
      this.#rebuildUnreadDelimiter();
      this.#scrollToBottom();
      this.#scheduleMarkViewed();
      this.#updateJumpBar();
      setTimeout(() => {
        this.canLoadOlder = true;
        this.#ensureScrollable();
      }, 250);
    });
  }

  disconnect() {
    this.scrollTarget?.removeEventListener("scroll", this.scrollHandler);
    document.removeEventListener("visibilitychange", this.visibilityHandler);
    this.observer?.disconnect();
    clearTimeout(this._viewTimer);

    if (this.isAtBottom) this.#markViewed();
  }

  openDetail(event) {
    const { params } = event;
    const frame = document.getElementById(params.detailFrame);

    if (frame?.innerHTML.trim()) {
      event.preventDefault();
      frame.innerHTML = "";
      return;
    }

    this.detailTargets.forEach((frame) => {
      if (frame.id !== params.detailFrame) frame.innerHTML = "";
    });
  }

  jumpToBottom() {
    this.#flushPending();
    this.#scrollToBottom({ smooth: true });
    this.#scheduleMarkViewed();
  }

  #handleMutations(mutations) {
    let prependedHeight = 0;
    let shouldRebuildDelimiters = false;

    for (const mutation of mutations) {
      const insertedAtBottom = mutation.nextSibling === null;
      const insertedAtTop = !insertedAtBottom && mutation.previousSibling === null;

      for (const node of mutation.addedNodes) {
        if (node.nodeType !== Node.ELEMENT_NODE) continue;
        if (node.classList.contains("day-delimiter")) continue;
        if (node.classList.contains("events__older-loader")) continue;
        if (node.classList.contains("unread-delimiter")) continue;

        shouldRebuildDelimiters = true;

        if (insertedAtBottom) {
          this.#handleAppend(node);
        } else if (insertedAtTop) {
          prependedHeight += node.offsetHeight;
        }
      }
    }

    if (prependedHeight > 0) {
      this.scrollTarget.scrollTop += prependedHeight;
    }

    if (shouldRebuildDelimiters) {
      this.#rebuildDayDelimiters();
      this.#rebuildUnreadDelimiter();
      this.#ensureScrollable();
    }
  }

  #handleAppend(node) {
    if (this.isFlushing) return;

    if (this.isAtBottom) {
      this.#trimTop();
      this.#scrollToBottom();

      if (document.visibilityState === "visible") {
        this.#scheduleMarkViewed();
      }

      return;
    }

    if (this.pendingEvents.length >= MAX_PENDING) {
      this.pendingEvents.shift();
    }

    this.pendingEvents.push(node);
    this.newEventCount += 1;
    node.remove();
    this.#updateJumpBar();
  }

  #flushPending() {
    if (!this.pendingEvents.length) return;

    this.isFlushing = true;
    this.pendingEvents.forEach((node) => this.listTarget.append(node));
    this.isFlushing = false;

    this.pendingEvents = [];
    this.newEventCount = 0;
    this.#trimTop();
    this.#rebuildDayDelimiters();
    this.#rebuildUnreadDelimiter();
    this.#updateJumpBar();
  }

  #onScroll() {
    const wasAtBottom = this.isAtBottom;
    this.isAtBottom = this.#atBottom();

    if (!wasAtBottom && this.isAtBottom) {
      this.#flushPending();
      this.#scheduleMarkViewed();
    }

    this.#updateJumpBar();

    if (this.canLoadOlder) {
      this.#loadOlderIfNeeded();
    }
  }

  #onVisibilityChange() {
    if (document.visibilityState === "visible" && this.isAtBottom) {
      this.#scheduleMarkViewed();
    }
  }

  #atBottom() {
    const distance =
      this.scrollTarget.scrollHeight -
      this.scrollTarget.scrollTop -
      this.scrollTarget.clientHeight;

    return distance < BOTTOM_THRESHOLD;
  }

  #scrollToBottom({ smooth = false } = {}) {
    this.scrollTarget.scrollTo({
      top: this.scrollTarget.scrollHeight,
      behavior: smooth ? "smooth" : "auto",
    });
    this.isAtBottom = true;
    this.#updateJumpBar();
  }

  #ensureScrollable() {
    if (!this.canLoadOlder) return;
    if (this.#isScrollable()) return;
    if (this.autofillPages >= MAX_AUTOFILL_PAGES) return;

    this.autofillPages += 1;
    this.#loadOlderIfNeeded({ force: true });
  }

  #isScrollable() {
    return this.scrollTarget.scrollHeight > this.scrollTarget.clientHeight + 1;
  }

  #loadOlderIfNeeded({ force = false } = {}) {
    if (this.isLoadingOlder || !this.hasOlderLoaderTarget) return;
    if (!this.olderLoaderTarget.dataset.url) return;
    if (!force && this.scrollTarget.scrollTop > TOP_THRESHOLD) return;

    this.isLoadingOlder = true;
    this.olderLoaderTarget.textContent = "loading older events...";
    this.olderLoaderTarget.classList.add("events__older-loader--loading");

    fetch(this.olderLoaderTarget.dataset.url, {
      headers: { Accept: "text/vnd.turbo-stream.html" },
      credentials: "same-origin",
    })
      .then((response) => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return response.text();
      })
      .then((html) => window.Turbo.renderStreamMessage(html))
      .then(() => {
        if (force) requestAnimationFrame(() => this.#ensureScrollable());
      })
      .catch((e) => {
        this.olderLoaderTarget.textContent = "could not load older events";
        console.error("Failed to load older events", e);
      })
      .finally(() => {
        this.isLoadingOlder = false;
      });
  }

  #trimTop() {
    while (this.listTarget.children.length > MAX_ITEMS) {
      this.listTarget.firstElementChild?.remove();
    }
  }

  #updateJumpBar() {
    if (!this.hasJumpBarTarget || !this.hasNewCountTarget) return;

    const show = !this.isAtBottom && this.newEventCount > 0;
    this.jumpBarTarget.classList.toggle("hidden", !show);

    if (show) {
      this.newCountTarget.textContent = `${this.newEventCount} new event${this.newEventCount === 1 ? "" : "s"} ↓`;
    }
  }

  #scheduleMarkViewed() {
    clearTimeout(this._viewTimer);
    this._viewTimer = setTimeout(() => this.#markViewed(), 400);
  }

  #markViewed() {
    if (!this.hasViewUrlValue) return;

    const csrf =
      document.querySelector('meta[name="csrf-token"]')?.content || "";
    const formData = new FormData();
    formData.append("authenticity_token", csrf);

    fetch(this.viewUrlValue, {
      method: "POST",
      headers: { "X-CSRF-Token": csrf },
      credentials: "same-origin",
      keepalive: true,
      body: formData,
    }).catch((e) => console.error("Failed to mark sink as viewed", e));
  }

  #parseSeenCutoff() {
    if (!this.hasSeenCutoffValue) return null;

    const parsed = new Date(this.seenCutoffValue);
    if (isNaN(parsed.getTime())) return null;

    return parsed;
  }

  #rebuildDayDelimiters() {
    this.listTarget
      .querySelectorAll(".day-delimiter")
      .forEach((el) => el.remove());

    const events = Array.from(
      this.listTarget.querySelectorAll(".event-feed__item"),
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

  #rebuildUnreadDelimiter() {
    this.listTarget
      .querySelectorAll(".unread-delimiter")
      .forEach((el) => el.remove());

    if (!this.seenCutoffTime) return;

    const events = Array.from(
      this.listTarget.querySelectorAll(".event-feed__item"),
    );

    const firstUnread = events.find((eventEl) => {
      const timeEl = eventEl.querySelector("time");
      if (!timeEl) return false;

      const eventTime = new Date(timeEl.getAttribute("datetime"));
      if (isNaN(eventTime.getTime())) return false;

      return eventTime > this.seenCutoffTime;
    });

    if (!firstUnread) return;

    const div = document.createElement("div");
    div.className = "unread-delimiter";
    div.title = "unread events";
    firstUnread.before(div);
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
}
