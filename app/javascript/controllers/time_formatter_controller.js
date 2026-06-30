import { Controller } from "@hotwired/stimulus";

const MILLISECONDS_PER_DAY = 86_400_000;

export default class extends Controller {
  static values = {
    mode: String,
  };

  connect() {
    this.#update();
  }

  #update() {
    const datetime = this.element.getAttribute("datetime");
    if (!datetime) return;

    const date = new Date(datetime);
    if (isNaN(date.getTime())) return;

    this.element.textContent = this.#format(date);
  }

  #format(date) {
    if (this.modeValue === "clock") {
      return this.#formatClock(date);
    }

    if (this.modeValue === "datetime") {
      return this.#formatDateTime(date);
    }

    if (this.modeValue === "utc-datetime") {
      return this.#formatDateTime(date, { utc: true });
    }

    const now = new Date();

    if (date.toDateString() === now.toDateString()) {
      return this.#formatClock(date, { seconds: false });
    }

    const diffDays = Math.floor((now - date) / MILLISECONDS_PER_DAY);
    if (diffDays < 7) {
      return date.toLocaleDateString([], { weekday: "short" });
    }

    const options =
      date.getFullYear() === now.getFullYear()
        ? { month: "short", day: "numeric" }
        : { month: "short", day: "numeric", year: "numeric" };

    return date.toLocaleDateString([], options);
  }

  #formatClock(date, { seconds = true, utc = false } = {}) {
    const parts = [
      utc ? date.getUTCHours() : date.getHours(),
      utc ? date.getUTCMinutes() : date.getMinutes(),
    ];

    if (seconds) parts.push(utc ? date.getUTCSeconds() : date.getSeconds());

    return parts
      .map((part) => String(part).padStart(2, "0"))
      .join(":");
  }

  #formatDateTime(date, { utc = false } = {}) {
    const year = utc ? date.getUTCFullYear() : date.getFullYear();
    const month = utc ? date.getUTCMonth() + 1 : date.getMonth() + 1;
    const day = utc ? date.getUTCDate() : date.getDate();
    const clock = this.#formatClock(date, { utc });

    return [
      year,
      month,
      day,
    ]
      .map((part, index) => index === 0 ? String(part) : String(part).padStart(2, "0"))
      .join("-") + ` ${clock}`;
  }
}
