import { Controller } from "@hotwired/stimulus";

const MILLISECONDS_PER_DAY = 86_400_000;

export default class extends Controller {
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
    const now = new Date();

    if (date.toDateString() === now.toDateString()) {
      return date.toLocaleTimeString([], {
        hour: "2-digit",
        minute: "2-digit",
      });
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
}
