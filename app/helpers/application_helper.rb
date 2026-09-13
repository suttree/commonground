module ApplicationHelper
  def field_options(record, attribute, hint: false)
    ids = []
    ids << "#{attribute}-hint" if hint
    ids << "#{attribute}-error" if record.errors[attribute].any?
    {
      aria: {
        describedby: ids.presence&.join(" "),
        invalid: record.errors[attribute].any? ? "true" : nil
      }
    }
  end
end
