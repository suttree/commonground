class SdgQuiz
  LABELS = JSON.parse(File.read(Rails.root.join("config/data/quiz_labels.json"))).freeze
  EXAMPLES = {
    "nika-van-olst-3e4265d5c4bf" => {
      "11.3" => "Bring neighbours into conversations about the places they share.",
      "12.6" => "Help businesses understand and communicate their sustainability work.",
      "17.17" => "Bring communities and organisations together around a shared project."
    }
  }.freeze

  def self.goals(ids)
    ProfileOptions::GOALS.select { |goal| ids.include?(goal.fetch("id")) }
  end

  def self.target_ids(ids)
    goals(ids).flat_map { |goal| goal.fetch("targets").pluck("id") }
  end
end
