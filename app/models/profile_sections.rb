class ProfileSections
  PERSONAL = {
    "basics" => [ "Basics", %w[name website location radius_km availability_status] ],
    "purpose" => [ "Purpose", %w[purpose] ],
    "experience" => [ "Experience", %w[experience sectors_past sectors_future sector_reason] ],
    "skills" => [ "Skills", %w[skills skills_summary] ],
    "about" => [ "About you", %w[education_topics satisfaction_feeling satisfaction_notes] ],
    "portfolio" => [ "Portfolio", %w[projects] ],
    "side_projects" => [ "Side projects", [] ],
    "priorities" => [ "Priorities", %w[target_ids exploring] ],
    "contact" => [ "Contact", %w[contact_action contact_destination] ]
  }.freeze
  EDITORIAL = {
    "identity" => [ "You, at a glance", %w[name website location radius_km skills_summary purpose contact_action contact_destination] ],
    "present" => [ "What you’re working on", %w[current_focus] ],
    "future" => [ "What comes next", %w[availability_status contribution collaboration_interest sectors_future sector_reason target_ids exploring] ],
    "past" => [ "What you bring", %w[experience sectors_past skills projects education_topics satisfaction_feeling satisfaction_notes] ]
  }.freeze
  COMPANY = {
    "basics" => [ "Basics", %w[name organisation_name website location] ],
    "offering" => [ "Purpose & impact", %w[mission purpose offering impact_metrics proud_of] ],
    "products" => [ "Products & services", %w[products] ],
    "goals" => [ "Goals & challenges", %w[challenge_kind challenge help_needed] ],
    "location" => [ "Sectors", %w[sectors_past] ],
    "priorities" => PERSONAL.fetch("priorities"),
    "contact" => PERSONAL.fetch("contact")
  }.freeze

  def self.for(profile)
    profile.organisation? ? COMPANY : PERSONAL.merge(EDITORIAL)
  end
end
