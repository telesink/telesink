import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.insertDelimiters();
    this.observer = new MutationObserver(() => this.insertDelimiters());
    this.observer.observe(this.element, { childList: true });
  }

  disconnect() {
    this.observer.disconnect();
  }

  insertDelimiters() {
    const events = Array.from(this.element.querySelectorAll(".event-preview"));
    this.element
      .querySelectorAll(".day-delimiter")
      .forEach((el) => el.remove());

    let lastDateKey = null;

    events.forEach((eventEl) => {
      const timeEl = eventEl.querySelector("time");
      if (!timeEl) return;

      const date = new Date(timeEl.getAttribute("datetime"));
      const dateKey = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;

      if (dateKey !== lastDateKey) {
        eventEl.before(this.createDelimiter(date));
        lastDateKey = dateKey;
      }
    });
  }

  createDelimiter(date) {
    const today = new Date();
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);

    const div = document.createElement("div");
    div.className = "day-delimiter";

    const span = document.createElement("span");
    span.className = "day-delimiter__label";

    if (this.isSameDay(date, today)) {
      span.textContent = "Today";
    } else if (this.isSameDay(date, yesterday)) {
      span.textContent = "Yesterday";
    } else {
      span.textContent = new Intl.DateTimeFormat(navigator.language, {
        weekday: "long",
        month: "long",
        day: "numeric",
        year: "numeric",
      }).format(date);
    }

    div.appendChild(span);
    return div;
  }

  isSameDay(a, b) {
    return (
      a.getFullYear() === b.getFullYear() &&
      a.getMonth() === b.getMonth() &&
      a.getDate() === b.getDate()
    );
  }
}
