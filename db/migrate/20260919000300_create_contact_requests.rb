class CreateContactRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_requests do |t|
      t.references :submission, null: false, foreign_key: true
      t.string :intent, null: false
      t.string :name, null: false
      t.string :email, null: false
      t.text :message, null: false
      t.json :target_ids, default: [], null: false
      t.datetime :consented_at, null: false
      t.timestamps
    end
  end
end
