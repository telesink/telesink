import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    title: String,
    text: String,
    url: String,
  };

  connect() {
    this.element.hidden = !navigator.canShare;
  }

  async share() {
    try {
      await navigator.share(await this.#getShareData());
    } catch (error) {
      if (error.name === "AbortError") {
        return;
      }
      throw error;
    }
  }

  async #getShareData() {
    const data = { title: this.titleValue, text: this.textValue };

    if (this.urlValue) {
      data.url = this.urlValue;
    }

    return data;
  }
}
