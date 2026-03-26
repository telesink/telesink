import { Controller } from "@hotwired/stimulus";
import Sortable from "sortablejs";

export default class extends Controller {
  static values = { url: String };

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: 150,
      ghostClass: "dragging",
      handle: ".column__drag-handle",
      onEnd: this.#saveOrder.bind(this),
    });
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy();
      this.sortable = null;
    }
  }

  #saveOrder() {
    const columnIds = Array.from(this.element.querySelectorAll(".column")).map(
      (el) => parseInt(el.dataset.columnIdValue, 10),
    );

    const csrfToken = document
      .querySelector("meta[name='csrf-token']")
      ?.getAttribute("content");

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
      },
      body: JSON.stringify({
        column_order: {
          column_ids: columnIds,
        },
      }),
    }).catch(console.error);
  }
}
