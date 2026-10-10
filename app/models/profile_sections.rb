class ProfileSections
  PERSONAL = {
    "basics" => [ "Basics", %w[name website location radius_km] ],
    "purpose" => [ "Purpose", %w[purpose] ],
    "experience" => [ "Experience", %w[experience sectors_past sectors_future sector_reason] ],
    "skills" => [ "Skills", %w[skills skills_summary] ],
    "about" => [ "About you", %w[education_topics satisfaction_feeling satisfaction_notes] ],
    "portfolio" => [ "Portfolio", %w[projects] ],
    "priorities" => [ "Priorities", %w[target_ids exploring] ],
    "contact" => [ "Contact", %w[contact_action contact_destination] ]
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
    profile.organisation? ? COMPANY : PERSONAL
  end
end
