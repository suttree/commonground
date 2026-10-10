module ApplicationHelper
  def main_navigation_link(label, path, section:)
    active_section = case controller_path
    when "directories", "profiles", "challenges", "contact_requests", "collaborator_invitations"
      :discover
    when "sdgs", "quiz"
      :goals
    when "dashboards"
      :dashboard
    when "submissions"
      current_account ? :dashboard : :login
    when "sessions"
      :login
    when "pages"
      :about if action_name == "about"
    end
    current = current_page?(path) ? "page" : "location" if active_section == section
    link_to label, path, aria: { current: current }
  end

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
