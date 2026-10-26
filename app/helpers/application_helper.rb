module ApplicationHelper
  def profile_photo_source(photo)
    return image_path("commonbound-woven-fabric.png") unless photo
    photo.submission_id ? profile_photo_path(photo) : draft_profile_photo_path(token: photo.draft_token)
  end

  def main_navigation_link(label, path, section:)
    active_section = case controller_path
    when %r{\Aadmin/}
      :admin
    when "directories", "profiles", "challenges", "contact_requests", "collaborator_invitations"
      :discover
    when "sdgs"
      :goals
    when "dashboards", "side_projects"
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

  # "Sarper's profile" for people (first name), "Acme's profile" for companies.
  def profile_heading(submission)
    name = submission.organisation? ? submission.display_name.to_s.strip : submission.display_name.to_s.split.first
    return "Your profile" if name.blank?
    "#{name}#{name.end_with?("s") ? "'" : "'s"} profile"
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
