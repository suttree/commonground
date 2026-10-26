class SdgDirectory
  LABELS = JSON.parse(File.read(Rails.root.join("config/data/quiz_labels.json"))).freeze
  GUIDES = JSON.parse(File.read(Rails.root.join("config/data/sdg_guides.json"))).freeze

  def self.goal(id)
    ProfileOptions::GOALS.find { |goal| goal.fetch("id") == id }
  end

  def self.search(query, goal_id: nil)
    words = query.downcase.split
    ProfileOptions::GOALS.flat_map do |goal|
      next [] if goal_id.present? && goal.fetch("id") != goal_id
      goal.fetch("targets").filter_map do |target|
        label = LABELS.fetch(target.fetch("id"))
        searchable = [ target.fetch("id"), label, target.fetch("text"), goal.fetch("name") ].join(" ").downcase
        next unless words.all? { |word| searchable.include?(word) }
        { target: target, label: label, goal: goal }
      end
    end.sort_by { |entry| entry[:target].fetch("id") == query.strip ? 0 : 1 }
  end
end
