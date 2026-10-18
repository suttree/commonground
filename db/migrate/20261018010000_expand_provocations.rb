class ExpandProvocations < ActiveRecord::Migration[8.1]
  def up
    JSON.parse(File.read(Rails.root.join("db/data/provocations_v1.json"))).each do |attributes|
      values = attributes.values_at("key", "question", "goal_id", "position").map { |value| connection.quote(value) }
      execute <<~SQL
        INSERT INTO provocations (key, question, goal_id, position, created_at, updated_at)
        VALUES (#{values.join(', ')}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT (key) DO NOTHING
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Keep the questions and any answers already recorded"
  end
end
