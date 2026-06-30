import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["teaser", "full", "toggle"];

  connect() {
    this.#syncState();
  }

  toggle() {
    this.#setExpanded(this.fullTarget.classList.contains("hidden"));
  }

  #setExpanded(expanded) {
    this.teaserTarget.classList.toggle("hidden", expanded);
    this.fullTarget.classList.toggle("hidden", !expanded);
    this.toggleTarget.textContent = expanded ? "show less" : "show more";
    this.#syncState();
  }

  #syncState() {
    const expanded = !this.fullTarget.classList.contains("hidden");

    this.toggleTarget.setAttribute("aria-expanded", String(expanded));
    this.teaserTarget.setAttribute("aria-hidden", String(expanded));
    this.fullTarget.setAttribute("aria-hidden", String(!expanded));
  }
}
