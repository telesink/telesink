import { Controller } from "@hotwired/stimulus";

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

    const yesterday = new Date(now);
    yesterday.setDate(yesterday.getDate() - 1);
    if (date.toDateString() === yesterday.toDateString()) {
      return "Yesterday";
    }

    const options =
      date.getFullYear() === now.getFullYear()
        ? { month: "short", day: "numeric" }
        : { month: "short", day: "numeric", year: "numeric" };

    return date.toLocaleDateString([], options);
  }
}
