class CreateChallenges < ActiveRecord::Migration[8.1]
  def change
    create_table :challenges do |t|
      t.references :submission, null: false, foreign_key: true
      t.string :title, null: false
      t.string :organisation_name
      t.string :industry
      t.string :location
      t.text :description
      t.text :objectives
      t.text :target
      t.json :help_options, null: false, default: []
      t.json :target_ids, null: false, default: []
      t.json :collaborator_ids, null: false, default: []
      t.string :status, null: false, default: "draft"
      t.string :project_role
      t.text :context
      t.text :approach
      t.text :results
      t.string :project_url
      t.datetime :published_at
      t.datetime :completed_at
      t.timestamps
    end
    add_index :challenges, :submission_id, unique: true, where: "status = 'active'", name: "one_active_challenge_per_profile"
    add_index :challenges, [ :status, :published_at ]
    add_reference :contact_requests, :challenge, foreign_key: true
  end
end
