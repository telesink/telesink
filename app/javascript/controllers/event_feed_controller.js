import { Controller } from "@hotwired/stimulus";

const MAX_ITEMS = 400;
const MAX_PENDING = 200;
const BOTTOM_THRESHOLD = 80;

export default class extends Controller {
  static targets = ["detail", "jumpBar", "list", "newCount", "scroll"];
  static values = {
    viewUrl: String,
  };

  connect() {
    this.pendingEvents = [];
    this.newEventCount = 0;
    this.isAtBottom = true;
    this.isFlushing = false;
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
      this.#scrollToBottom();
      this.#scheduleMarkViewed();
      this.#updateJumpBar();
    });
  }

  disconnect() {
    this.scrollTarget?.removeEventListener("scroll", this.scrollHandler);
    document.removeEventListener("visibilitychange", this.visibilityHandler);
    this.observer?.disconnect();
    clearTimeout(this._viewTimer);

    if (this.isAtBottom) this.#markViewed();
  }

  openDetail({ params }) {
    this.detailTargets.forEach((frame) => {
      if (frame.id !== params.detailFrame) frame.innerHTML = "";
    });
  }

  collapseDetail(event) {
    event.preventDefault();
    const frame = event.target.closest("turbo-frame");
    if (frame) frame.innerHTML = "";
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
