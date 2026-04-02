module ApplicationHelper
  def site_title
    s = content_for(:title) || "Telesink"

    if Rails.env.demo?
      s += " (demo)"
    end

    s
  end
  def button_to_copy_to_clipboard(content, &)
    tag.button(
      class: "btn btn--primary self-start",
      title: "Copy to clipboard",
      data: {
        controller: "copy-to-clipboard",
        action: "copy-to-clipboard#copy",
        copy_to_clipboard_content_value: content
      }, &)
  end
end
