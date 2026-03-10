import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { content: String };

  async copy(event) {
    event.preventDefault();

    try {
      await navigator.clipboard.writeText(this.contentValue);

      const originalText = this.element.textContent;
      this.element.textContent = "copied!";

      setTimeout(() => {
        this.element.textContent = originalText;
      }, 1500);
    } catch (err) {
      console.error("Copy failed:", err);
    }
  }
}
