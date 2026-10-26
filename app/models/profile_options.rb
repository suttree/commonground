module ProfileOptions
  SDG_DATA = JSON.parse(File.read(Rails.root.join("config/data/sdg_targets.json"))).freeze
  GOALS = SDG_DATA.fetch("goals").freeze
  TARGETS = GOALS.flat_map { |goal| goal.fetch("targets") }.index_by { |target| target.fetch("id") }.freeze
  SECTORS = [
    "Agriculture, food & drink", "Arts, culture & entertainment", "Construction & the built environment",
    "Education & research", "Energy & utilities", "Environment & conservation", "Finance & insurance",
    "Government & public services", "Healthcare & wellbeing", "Hospitality & tourism",
    "Legal & professional services", "Manufacturing & engineering", "Media & communications",
    "Nonprofits & community organisations", "Retail & consumer goods", "Social care",
    "Technology & digital services", "Transport & logistics", "Other"
  ].freeze
  FEELINGS = [ "Alive", "Satisfied", "At peace" ].freeze
  PROJECT_DETAILS = { "title" => "Project title", "role" => "My role", "organisation" => "Client / organisation (optional)", "time" => "When (optional)", "url" => "Project link (optional)", "caption" => "Image description / caption (optional)" }.freeze
  REPEATED_FIELDS = {
    "skills" => { "skill" => "Skill", "results" => "Results that verify this skill", "organisation" => "Company / organisation", "time" => "When" },
    "projects" => { "problem" => "Problem", "context" => "Context", "approach" => "My approach", "results" => "Results" },
    "products" => { "name" => "Product / service", "special" => "What makes it special", "impact" => "What impact does it strive to have?" }
  }.freeze
end
