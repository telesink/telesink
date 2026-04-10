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

  def web_share_button(url, title, text, &)
    tag.button(
      class: "btn btn--primary",
      title: "Share",
      data: {
        controller: "web-share", action: "web-share#share",
        web_share_url_value: url,
        web_share_text_value: text,
        web_share_title_value: title
      }, &)
  end
end
