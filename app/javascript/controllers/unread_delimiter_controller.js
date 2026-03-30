import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { lastViewedAt: String };

  connect() {
    this.insertDelimiter();
    this.observer = new MutationObserver(() => this.insertDelimiter());
    this.observer.observe(this.element, { childList: true });
  }

  disconnect() {
    this.observer?.disconnect();
  }

  insertDelimiter() {
    this.element
      .querySelectorAll(".seen-delimiter")
      .forEach((el) => el.remove());

    if (!this.lastViewedAtValue) return;

    const lastViewed = new Date(this.lastViewedAtValue);
    const events = Array.from(this.element.querySelectorAll(".event-preview"));

    for (const eventEl of events) {
      const timeEl = eventEl.querySelector("time");
      if (!timeEl) continue;

      const eventTime = new Date(timeEl.getAttribute("datetime"));

      if (eventTime <= lastViewed) {
        eventEl.before(this.createDelimiter());
        return;
      }
    }
  }

  createDelimiter() {
    const div = document.createElement("div");
    div.className = "seen-delimiter";
    div.innerHTML = `
      <div class="seen-line"></div>
      <span class="seen-label">↓ seen ↓</span>
      <div class="seen-line"></div>
    `;
    return div;
  }
}
