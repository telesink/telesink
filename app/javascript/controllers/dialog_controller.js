import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["dialog"];

  connect() {
    this.dialogTarget.showModal();
  }

  handleBackdrop(event) {
    if (event.target === this.dialogTarget) {
      this.close();
    }
  }

  handleCancel(event) {
    event.preventDefault();
    this.close();
  }

  close() {
    this.dialogTarget.close();
  }
}
