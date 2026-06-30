import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { content: String };

  disconnect() {
    clearTimeout(this.resetTimer);
  }

  async copy(event) {
    event.preventDefault();

    try {
      await this.#writeClipboard(this.contentValue);

      this.originalText ||= this.element.textContent;
      clearTimeout(this.resetTimer);
      this.element.textContent = "done";

      this.resetTimer = setTimeout(() => {
        this.element.textContent = this.originalText;
        this.resetTimer = null;
      }, 1500);
    } catch (err) {
      console.error("Copy failed:", err);
    }
  }

  async #writeClipboard(content) {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(content);
      return;
    }

    const textarea = document.createElement("textarea");
    textarea.value = content;
    textarea.readOnly = true;
    textarea.style.position = "fixed";
    textarea.style.top = "-9999px";
    document.body.append(textarea);
    textarea.select();

    let copied = false;

    try {
      copied = document.execCommand("copy");
    } finally {
      textarea.remove();
    }

    if (!copied) throw new Error("copy command failed");
  }
}
