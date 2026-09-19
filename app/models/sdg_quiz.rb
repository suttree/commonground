class SdgQuiz
  LABELS = SdgDirectory::LABELS
  QUESTIONS = JSON.parse(File.read(Rails.root.join("config/data/quiz_questions.json"))).freeze
  EXAMPLES = {
    "nika-van-olst-3e4265d5c4bf" => {
      "11.3" => "Bring neighbours into conversations about the places they share.",
      "12.6" => "Help businesses understand and communicate their sustainability work.",
      "17.17" => "Bring communities and organisations together around a shared project."
    }
  }.freeze

  def self.matches(answers)
    evidence = Hash.new { |hash, key| hash[key] = [] }
    QUESTIONS.each_with_index do |question, index|
      answer = answers[index.to_s]
      next unless answer.to_s.match?(/\A[0-3]\z/)
      option = question.fetch("options").fetch(answer.to_i)
      option.fetch("targets").each { |id| evidence[id] << option.fetch("label") }
    end
    evidence.sort_by { |_id, reasons| -reasons.size }.first(3).to_h
  end

  def self.goals(ids)
    ProfileOptions::GOALS.select { |goal| ids.include?(goal.fetch("id")) }
  end

  def self.target_ids(ids)
    goals(ids).flat_map { |goal| goal.fetch("targets").pluck("id") }
  end
end
