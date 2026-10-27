class ExpandProvocationDiscussions < ActiveRecord::Migration[8.1]
  def change
    add_column :provocations, :status, :string, null: false, default: "published"
    add_column :provocation_answers, :note, :text
    add_column :provocation_answers, :shared, :boolean, null: false, default: false
    add_column :provocation_answers, :allow_introductions, :boolean, null: false, default: false
    create_table :provocation_introductions do |t|
      t.references :requester, null: false, foreign_key: { to_table: :accounts }
      t.references :recipient, null: false, foreign_key: { to_table: :accounts }
      t.references :provocation_answer, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.timestamps
    end
    add_index :provocation_introductions, [ :requester_id, :recipient_id ], unique: true,
      name: "unique_provocation_introduction_pair"
  end
end
