import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["teaser", "full", "toggle"];

  toggle() {
    const isExpanded = this.fullTarget.classList.contains("hidden") === false;

    if (isExpanded) {
      this.teaserTarget.classList.remove("hidden");
      this.fullTarget.classList.add("hidden");
      this.toggleTarget.textContent = "show more";
    } else {
      this.teaserTarget.classList.add("hidden");
      this.fullTarget.classList.remove("hidden");
      this.toggleTarget.textContent = "show less";
    }
  }
}
