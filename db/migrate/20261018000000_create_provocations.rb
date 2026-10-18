class CreateProvocations < ActiveRecord::Migration[8.1]
  def change
    create_table :provocations do |t|
      t.string :key, null: false
      t.text :question, null: false
      t.string :goal_id, null: false
      t.integer :position, null: false
      t.timestamps
    end
    add_index :provocations, :key, unique: true

    create_table :provocation_answers do |t|
      t.references :submission, null: false, foreign_key: true
      t.references :provocation, null: false, foreign_key: true
      t.string :choice, null: false
      t.timestamps
    end
    add_index :provocation_answers, [ :submission_id, :provocation_id ], unique: true
    add_check_constraint :provocation_answers, "choice IN ('strong_no', 'no', 'yes', 'strong_yes')", name: "provocation_answer_choice"

    reversible do |dir|
      dir.up do
        execute <<~SQL
          INSERT INTO provocations (key, question, goal_id, position, created_at, updated_at) VALUES
          ('repairable-products-v1', 'Should companies be required to make their products repairable, even if that makes them more expensive to buy?', '12', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
          ('public-transport-v1', 'Should cities give more road space to public transport, even if that leaves less room for private cars?', '11', 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
          ('paid-training-v1', 'Should employers provide paid time for staff to learn new skills, even if that reduces the time spent on their usual work?', '8', 3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        SQL
      end
    end
  end
end
